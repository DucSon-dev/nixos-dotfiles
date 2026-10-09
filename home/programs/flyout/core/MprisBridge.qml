import QtQuick
import Quickshell
import Quickshell.Io

// Reactive MPRIS v2 D-Bus data bridge for FluentFlyout
// Headless QtObject (0% UI). Extracts metadata, tracks active player session,
// provides targeted IPC controls, and purges state upon StateMachine.requestCleanup.
QtObject {
    id: root

    // --- Reactive Properties ---
    property string activePlayer: ""
    property string title: ""
    property string artist: ""
    property string album: ""
    property string artUrl: ""
    property string playbackStatus: "Stopped"
    property real positionSec: 0.0
    property real lengthSec: 0.0
    property bool canGoNext: false
    property bool canGoPrevious: false
    property string loopStatus: "None"
    property bool shuffleStatus: false

    // Capability guards: Brave / Chromium lack MPRIS loop and shuffle support
    readonly property bool canLoop: activePlayer !== "" && !activePlayer.toLowerCase().includes("brave") && !activePlayer.toLowerCase().includes("chromium")
    readonly property bool canShuffle: activePlayer !== "" && !activePlayer.toLowerCase().includes("brave") && !activePlayer.toLowerCase().includes("chromium")

    // Derived reactive helper properties
    readonly property bool isPlaying: playbackStatus === "Playing"
    readonly property bool hasMedia: title !== "" && playbackStatus !== "Stopped"

    // Optional reference to StateMachine instance
    property QtObject stateMachine: null

    // Format specification for playerctl metadata stream with explicit playerName routing
    readonly property string metadataFormat: "{{playerName}}|||{{xesam:title}}|||{{xesam:artist}}|||{{xesam:album}}|||{{mpris:artUrl}}|||{{status}}|||{{position}}|||{{mpris:length}}|||{{canGoNext}}|||{{canGoPrevious}}|||{{loop}}|||{{shuffle}}"

    // Signals
    signal ipcDispatched(var command)

    // Synchronize bindings whenever stateMachine reference is updated
    onStateMachineChanged: {
        if (stateMachine) {
            stateMachine.hasMedia = root.hasMedia;
            stateMachine.isPlaying = root.isPlaying;
        }
    }

    // Connect to StateMachine's requestCleanup to purge metadata immediately
    property var _cleanupConn: Connections {
        target: root.stateMachine
        function onRequestCleanup() {
            root.purge();
        }
    }

    // --- Ingestion & Parsing ---
    function parseMetadata(line) {
        if (!line || line.trim() === "") {
            handlePlayerTermination();
            return;
        }

        var parts = line.trim().split("|||");
        if (parts.length >= 6) {
            var newPlayer = parts[0].trim();
            var newTitle = parts[1].trim();

            // Track transition invalidation: when track title changes on an active player,
            // immediately reset positionSec to avoid leaking stale timestamps from previous track.
            var isTrackTransition = (root.title !== "" && newTitle !== "" && root.title !== newTitle) ||
                                    (root.activePlayer !== "" && newPlayer !== "" && root.activePlayer !== newPlayer);

            if (isTrackTransition) {
                positionSec = 0.0;
                if (snapshotProcess && snapshotProcess.running) {
                    snapshotProcess.running = false;
                }
                if (snapshotProcess) {
                    snapshotProcess.running = true;
                }
            }

            activePlayer = newPlayer;
            title = newTitle;
            artist = parts[2].trim();
            album = parts.length > 3 ? parts[3].trim() : "";
            artUrl = parts.length > 4 ? parts[4].trim() : "";
            playbackStatus = parts.length > 5 ? parts[5].trim() : "Stopped";

            if (parts.length >= 8) {
                var posUs = parseFloat(parts[6].trim()) || 0;
                var lenUs = parseFloat(parts[7].trim()) || 0;
                var rawPosSec = posUs > 0 ? (posUs / 1000000.0) : 0.0;
                lengthSec = lenUs > 0 ? (lenUs / 1000000.0) : 0.0;
                // Clamp position: positionSec can never exceed lengthSec when lengthSec > 0
                positionSec = lengthSec > 0 ? Math.min(rawPosSec, lengthSec) : rawPosSec;
            }
            if (parts.length >= 10) {
                canGoNext = parts[8].trim() === "true";
                canGoPrevious = parts[9].trim() === "true";
            }
            if (parts.length >= 12) {
                loopStatus = parts[10].trim() || "None";
                shuffleStatus = parts[11].trim() === "On" || parts[11].trim() === "true";
            }

            if (stateMachine) {
                stateMachine.hasMedia = root.hasMedia;
                stateMachine.isPlaying = root.isPlaying;
            }
        }
    }

    // Purge mechanism: wipe all properties to empty strings and status to "Stopped"
    function purge() {
        activePlayer = "";
        title = "";
        artist = "";
        album = "";
        artUrl = "";
        playbackStatus = "Stopped";
        positionSec = 0.0;
        lengthSec = 0.0;
        canGoNext = false;
        canGoPrevious = false;
        loopStatus = "None";
        shuffleStatus = false;

        if (stateMachine) {
            stateMachine.hasMedia = false;
            stateMachine.isPlaying = false;
        }
    }

    // Handle player termination or SIGKILL
    function handlePlayerTermination() {
        if (stateMachine) {
            stateMachine.onPlayerExited();
        } else {
            purge();
        }
    }

    // --- Targeted Non-Blocking IPC Controls ---

    function playPause() {
        dispatchIpc(["playerctl", "play-pause"]);
    }

    function next() {
        dispatchIpc(["playerctl", "next"]);
    }

    function previous() {
        dispatchIpc(["playerctl", "previous"]);
    }

    function seek(targetSec) {
        var sec = Math.max(0, Math.min(targetSec, lengthSec));
        positionSec = sec;
        dispatchIpc(["playerctl", "position", sec.toFixed(2)]);
    }

    function toggleShuffle() {
        shuffleStatus = !shuffleStatus;
        var nextShuffle = shuffleStatus ? "On" : "Off";
        dispatchIpc(["playerctl", "shuffle", nextShuffle]);
    }

    function cycleLoop() {
        var nextLoop = "Playlist";
        if (loopStatus === "Playlist") nextLoop = "Track";
        else if (loopStatus === "Track") nextLoop = "None";
        loopStatus = nextLoop;
        dispatchIpc(["playerctl", "loop", nextLoop]);
    }

    // Explicit session routing dispatcher: ensures all commands target activePlayer
    function dispatchIpc(args) {
        var finalArgs = ["playerctl"];
        if (root.activePlayer !== "") {
            finalArgs.push("--player=" + root.activePlayer);
        }
        for (var i = 1; i < args.length; i++) {
            finalArgs.push(args[i]);
        }
        root.ipcDispatched(finalArgs);
        Quickshell.execDetached(finalArgs);
    }

    // --- Declarative Native Process Engine ---
    // Snapshot query: immediately queries active player metadata on startup
    property Process snapshotProcess: Process {
        command: ["playerctl", "metadata", "--format", root.metadataFormat]
        stdout: SplitParser {
            onRead: data => root.parseMetadata(data)
        }
    }

    // Event watcher: follows playerctl metadata updates via D-Bus PropertiesChanged
    property Process watcherProcess: Process {
        command: ["playerctl", "--follow", "metadata", "--format", root.metadataFormat]
        stdout: SplitParser {
            onRead: data => root.parseMetadata(data)
        }
        onExited: () => root.handlePlayerTermination()
    }

    Component.onCompleted: {
        snapshotProcess.running = true;
        watcherProcess.running = true;
    }
}
