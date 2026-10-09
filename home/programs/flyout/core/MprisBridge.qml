import QtQuick
import Quickshell
import Quickshell.Io

// Reactive MPRIS v2 D-Bus data bridge for FluentFlyout
// Headless QtObject (0% UI). Extracts metadata, tracks active player session,
// provides targeted IPC controls, and purges state upon StateMachine.requestCleanup.
// Implements Active Session Arbitration & Affinity Lock (reverse-engineered from Windows GSMTC).
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

    // Multi-player session registry map: { [playerName]: { title, artist, album, artUrl, playbackStatus, positionSec, lengthSec, canGoNext, canGoPrevious, loopStatus, shuffleStatus } }
    property var playerSessions: ({})
    property real lastPreemptionTime: 0
    property string preemptionFormerPlayer: ""

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

    // --- Ingestion, Session Registry & Arbitration ---
    function parseMetadata(line) {
        if (!line || line.trim() === "") {
            handlePlayerTermination();
            return;
        }

        var parts = line.trim().split("|||");
        if (parts.length >= 6) {
            var incomingPlayer = parts[0].trim();
            var incomingTitle = parts[1].trim();
            var incomingArtist = parts[2].trim();
            var incomingAlbum = parts.length > 3 ? parts[3].trim() : "";
            var incomingArtUrl = parts.length > 4 ? parts[4].trim() : "";
            var incomingStatus = parts.length > 5 ? parts[5].trim() : "Stopped";

            var incomingPosSec = 0.0;
            var incomingLenSec = 0.0;
            if (parts.length >= 8) {
                var posUs = parseFloat(parts[6].trim()) || 0;
                var lenUs = parseFloat(parts[7].trim()) || 0;
                var rawPosSec = posUs > 0 ? (posUs / 1000000.0) : 0.0;
                incomingLenSec = lenUs > 0 ? (lenUs / 1000000.0) : 0.0;
                incomingPosSec = incomingLenSec > 0 ? Math.min(rawPosSec, incomingLenSec) : rawPosSec;
            }

            var incomingCanNext = parts.length >= 10 ? (parts[8].trim() === "true") : false;
            var incomingCanPrev = parts.length >= 10 ? (parts[9].trim() === "true") : false;
            var incomingLoop = parts.length >= 12 ? (parts[10].trim() || "None") : "None";
            var incomingShuffle = parts.length >= 12 ? (parts[11].trim() === "On" || parts[11].trim() === "true") : false;

            // Update session cache in registry
            var session = {
                playerName: incomingPlayer,
                title: incomingTitle,
                artist: incomingArtist,
                album: incomingAlbum,
                artUrl: incomingArtUrl,
                playbackStatus: incomingStatus,
                positionSec: incomingPosSec,
                lengthSec: incomingLenSec,
                canGoNext: incomingCanNext,
                canGoPrevious: incomingCanPrev,
                loopStatus: incomingLoop,
                shuffleStatus: incomingShuffle
            };

            var sessions = Object.assign({}, playerSessions);
            if (incomingStatus === "Stopped" && incomingTitle === "") {
                delete sessions[incomingPlayer];
            } else {
                sessions[incomingPlayer] = session;
            }
            playerSessions = sessions;

            // Dynamic Audio Focus Preemption Arbitration Policy (macOS/Android Media Priority Model):
            // 1. New Stream Preemption:
            //    When a secondary player transitions to Playing (incomingStatus === "Playing" and incomingPlayer !== root.activePlayer):
            //    - If root.activePlayer !== "" and root.playbackStatus === "Playing":
            //      Immediately dispatch targeted pause signal to former player via IPC:
            //      dispatchIpc(["playerctl", "--player=" + root.activePlayer, "pause"])
            //    - Cache previous player's updated state in playerSessions.
            //    - Transition root.activePlayer to incomingPlayer and apply session metadata immediately.
            // 2. Debounce & Re-assertion Guard:
            //    If current activePlayer is Playing, but incoming update is from a secondary player that is NOT Playing,
            //    ignore the secondary update (do not let delayed Paused frames from former player steal back focus).
            // 3. State & Termination Maintenance:
            //    - If current active player transitions to Paused/Stopped/Exit, immediately check playerSessions for
            //      any other player that is currently Playing and transfer focus seamlessly.
            var isCurrentPlaying = (root.activePlayer !== "" && root.playbackStatus === "Playing");
            var isSamePlayer = (root.activePlayer === incomingPlayer);
            var isIncomingPlaying = (incomingStatus === "Playing");

            if (!isSamePlayer) {
                if (isIncomingPlaying) {
                    // Mutual D-Bus Debounce Guard:
                    // If we just preempted former player less than 250ms ago, ignore echo frames
                    var now = Date.now();
                    if (now - lastPreemptionTime < 250 && incomingPlayer === preemptionFormerPlayer) {
                        return;
                    }

                    // Preemption trigger: new player starts playing.
                    if (isCurrentPlaying) {
                        var formerPlayer = root.activePlayer;
                        lastPreemptionTime = now;
                        preemptionFormerPlayer = formerPlayer;

                        if (playerSessions[formerPlayer]) {
                            var formerSession = Object.assign({}, playerSessions[formerPlayer]);
                            formerSession.playbackStatus = "Paused";
                            sessions[formerPlayer] = formerSession;
                            playerSessions = sessions;
                        }
                        dispatchIpcToPlayer(formerPlayer, ["playerctl", "pause"]);
                    }
                    // Immediate preemption transfer
                    applySession(session);
                    return;
                } else {
                    // Secondary player is NOT playing. If current activePlayer is Playing, ignore it.
                    if (isCurrentPlaying) {
                        return;
                    }
                    // Current player is not playing; if there is another Playing player in cache, prefer it.
                    var cachedPlaying = getFirstPlayingSessionExcept(incomingPlayer);
                    if (cachedPlaying) {
                        applySession(cachedPlaying);
                        return;
                    }
                }
            } else {
                // Incoming update from current active player
                if (incomingStatus === "Stopped" && incomingTitle === "") {
                    delete sessions[incomingPlayer];
                    playerSessions = sessions;
                    fallbackToActivePlayer();
                    return;
                }

                // If active player transitioned away from Playing, check for any other Playing session
                if (!isIncomingPlaying) {
                    var otherPlaying = getFirstPlayingSessionExcept(incomingPlayer);
                    if (otherPlaying) {
                        applySession(otherPlaying);
                        return;
                    }
                }
            }

            // Apply session update
            applySession(session);
        }
    }

    function applySession(session) {
        var isTrackTransition = (root.title !== "" && session.title !== "" && root.title !== session.title) ||
                                (root.activePlayer !== "" && session.playerName !== "" && root.activePlayer !== session.playerName);

        if (isTrackTransition) {
            positionSec = 0.0;
            if (snapshotProcess && snapshotProcess.running) {
                snapshotProcess.running = false;
            }
            if (snapshotProcess) {
                snapshotProcess.running = true;
            }
        }

        activePlayer = session.playerName;
        title = session.title;
        artist = session.artist;
        album = session.album;
        artUrl = session.artUrl;
        playbackStatus = session.playbackStatus;
        positionSec = isTrackTransition && session.positionSec === 0.0 ? 0.0 : session.positionSec;
        lengthSec = session.lengthSec;
        canGoNext = session.canGoNext;
        canGoPrevious = session.canGoPrevious;
        loopStatus = session.loopStatus;
        shuffleStatus = session.shuffleStatus;

        if (stateMachine) {
            stateMachine.hasMedia = root.hasMedia;
            stateMachine.isPlaying = root.isPlaying;
        }
    }

    // Find first playing session from registry excluding an optional player name
    function getFirstPlayingSessionExcept(excludedPlayer) {
        var keys = Object.keys(playerSessions);
        for (var i = 0; i < keys.length; i++) {
            var k = keys[i];
            if (k === excludedPlayer) continue;
            var s = playerSessions[k];
            if (s && s.playbackStatus === "Playing" && s.title !== "") {
                return s;
            }
        }
        return null;
    }

    // Fall back cleanly to any remaining active player in registry
    function fallbackToActivePlayer() {
        var keys = Object.keys(playerSessions);
        // Look for any playing player first
        for (var i = 0; i < keys.length; i++) {
            var s = playerSessions[keys[i]];
            if (s && s.playbackStatus === "Playing") {
                applySession(s);
                return;
            }
        }
        // Then look for any paused player
        for (var j = 0; j < keys.length; j++) {
            var s2 = playerSessions[keys[j]];
            if (s2 && s2.playbackStatus === "Paused" && s2.title !== "") {
                applySession(s2);
                return;
            }
        }
        // Otherwise purge
        purge();
    }

    // Purge mechanism: wipe all properties to empty strings and status to "Stopped"
    function purge() {
        playerSessions = ({});
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
        // Player termination or process exit wipes state
        purge();
        if (stateMachine) {
            stateMachine.onPlayerExited();
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

    // Direct player targeted dispatcher: avoids overriding with root.activePlayer
    function dispatchIpcToPlayer(playerName, args) {
        var finalArgs = ["playerctl"];
        if (playerName && playerName !== "") {
            finalArgs.push("--player=" + playerName);
        }
        for (var i = 1; i < args.length; i++) {
            finalArgs.push(args[i]);
        }
        root.ipcDispatched(finalArgs);
        Quickshell.execDetached(finalArgs);
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
