import QtQuick
import "../core" as Core

// Headless Automated Test Harness for MprisBridge.qml
QtObject {
    id: testRunner

    property Core.StateMachine fsm: Core.StateMachine {
        autoHideInterval: 50
    }

    property Core.MprisBridge bridge: Core.MprisBridge {
        stateMachine: testRunner.fsm
    }

    property int testStep: 0
    property var dispatchedCommands: []

    // Monitor dispatched IPC commands
    property var _ipcConn: Connections {
        target: testRunner.bridge
        function onIpcDispatched(cmd) {
            testRunner.dispatchedCommands.push(cmd);
        }
    }

    function assert(condition, message) {
        if (!condition) {
            console.error("FAIL: " + message);
            Qt.exit(1);
        }
    }

    // Step sequencer driven by interval ticks
    property Timer runnerTimer: Timer {
        interval: 15
        repeat: true
        running: true
        onTriggered: {
            testRunner.testStep++;

            switch (testRunner.testStep) {
            case 1:
                console.log("[TEST 1] Initial state and reactive property assertions");
                assert(bridge.activePlayer === "", "ActivePlayer must be empty string initially");
                assert(bridge.title === "", "Title must be empty string initially");
                assert(bridge.artist === "", "Artist must be empty string initially");
                assert(bridge.album === "", "Album must be empty string initially");
                assert(bridge.artUrl === "", "ArtUrl must be empty string initially");
                assert(bridge.playbackStatus === "Stopped", "PlaybackStatus must be 'Stopped'");
                assert(bridge.positionSec === 0.0, "Position must be 0.0");
                assert(bridge.lengthSec === 0.0, "Length must be 0.0");
                assert(!bridge.canGoNext && !bridge.canGoPrevious, "Navigation flags must be false");
                assert(!bridge.canLoop && !bridge.canShuffle, "Capability guards must be false initially");
                assert(!fsm.hasMedia && !fsm.isPlaying, "StateMachine must reflect no media");
                break;

            case 2:
                console.log("[TEST 2] Ingest normal track metadata with activePlayer tracking & Amberol bus name");
                var normalLine = "io.bassi.Amberol|||Subdivisions|||Rush|||Signals|||https://images.example.com/signals.jpg|||Playing|||14000000|||173000000|||true|||true|||None|||false";
                bridge.parseMetadata(normalLine);

                assert(bridge.activePlayer === "io.bassi.Amberol", "ActivePlayer mismatch: " + bridge.activePlayer);
                assert(bridge.title === "Subdivisions", "Title mismatch: " + bridge.title);
                assert(bridge.artist === "Rush", "Artist mismatch: " + bridge.artist);
                assert(bridge.album === "Signals", "Album mismatch: " + bridge.album);
                assert(bridge.artUrl === "https://images.example.com/signals.jpg", "ArtUrl mismatch");
                assert(bridge.playbackStatus === "Playing", "Status must be Playing");
                // Unit conversion assertion: 14000000 us -> 14.0s, 173000000 us -> 173.0s
                assert(Math.abs(bridge.positionSec - 14.0) < 0.001, "Position must be 14.0s (14,000,000 us)");
                assert(Math.abs(bridge.lengthSec - 173.0) < 0.001, "Length must be 173.0s (173,000,000 us)");
                assert(bridge.canGoNext === true, "canGoNext must be true");
                assert(bridge.canGoPrevious === true, "canGoPrevious must be true");
                assert(bridge.canLoop === true, "canLoop must be true for io.bassi.Amberol");
                assert(bridge.canShuffle === true, "canShuffle must be true for io.bassi.Amberol");

                // Assert StateMachine synchronization
                assert(fsm.hasMedia === true, "StateMachine.hasMedia must be true");
                assert(fsm.isPlaying === true, "StateMachine.isPlaying must be true");
                break;

            case 3:
                console.log("[TEST 3] Ingest long title sequence & verify Brave capability guards");
                var longTitle = "A".repeat(120);
                assert(longTitle.length === 120, "String must be 120 chars");

                var longLine = "brave.instance11841|||" + longTitle + "|||Experimental Ensemble|||Extensive Symphony|||https://example.com/art.png|||Playing|||50000000|||600000000|||true|||true|||None|||false";
                bridge.parseMetadata(longLine);

                assert(bridge.activePlayer === "brave.instance11841", "ActivePlayer must update to brave instance");
                assert(bridge.title === longTitle, "Bridge must preserve full 120 character title without truncation");
                assert(bridge.title.length === 120, "Title length must be exactly 120");
                // Brave capability invariant: canLoop & canShuffle must be false
                assert(bridge.canLoop === false, "canLoop must be false for Brave");
                assert(bridge.canShuffle === false, "canShuffle must be false for Brave");
                break;

            case 4:
                console.log("[TEST 4] Seek position update and targeted IPC seek trigger (io.bassi.Amberol)");
                bridge.lastPreemptionTime = 0;
                var seekLine = "io.bassi.Amberol|||Subdivisions|||Rush|||Signals|||https://example.com/art.png|||Playing|||14000000|||173000000|||true|||true|||None|||false";
                bridge.parseMetadata(seekLine);
                assert(bridge.activePlayer === "io.bassi.Amberol", "Active player must be io.bassi.Amberol");
                assert(Math.abs(bridge.positionSec - 14.0) < 0.001, "Position must update to 14.0s");

                // Execute seek method: MUST target --player=io.bassi.Amberol with formatted 86.50
                bridge.seek(86.5);
                assert(Math.abs(bridge.positionSec - 86.5) < 0.001, "Local seek position must update immediately");
                assert(testRunner.dispatchedCommands.length > 0, "Seek IPC command must be dispatched");
                var lastCmd = testRunner.dispatchedCommands[testRunner.dispatchedCommands.length - 1];
                assert(lastCmd[0] === "playerctl" && lastCmd[1] === "--player=io.bassi.Amberol" && lastCmd[2] === "position" && lastCmd[3] === "86.50", "Targeted Seek IPC payload mismatch: " + JSON.stringify(lastCmd));
                break;

            case 5:
                console.log("[TEST 5] Targeted Non-blocking IPC control methods for io.bassi.Amberol");
                var initialCmdCount = testRunner.dispatchedCommands.length;
                bridge.playPause();
                var playCmd = testRunner.dispatchedCommands[testRunner.dispatchedCommands.length - 1];
                assert(playCmd[0] === "playerctl" && playCmd[1] === "--player=io.bassi.Amberol" && playCmd[2] === "play-pause", "playPause targeting failed");

                bridge.next();
                var nextCmd = testRunner.dispatchedCommands[testRunner.dispatchedCommands.length - 1];
                assert(nextCmd[0] === "playerctl" && nextCmd[1] === "--player=io.bassi.Amberol" && nextCmd[2] === "next", "next targeting failed");

                bridge.previous();
                var prevCmd = testRunner.dispatchedCommands[testRunner.dispatchedCommands.length - 1];
                assert(prevCmd[0] === "playerctl" && prevCmd[1] === "--player=io.bassi.Amberol" && prevCmd[2] === "previous", "previous targeting failed");

                bridge.toggleShuffle();
                assert(bridge.shuffleStatus === true, "toggleShuffle must toggle local state to true");
                var shufCmd = testRunner.dispatchedCommands[testRunner.dispatchedCommands.length - 1];
                assert(shufCmd[0] === "playerctl" && shufCmd[1] === "--player=io.bassi.Amberol" && shufCmd[2] === "shuffle" && shufCmd[3] === "On", "shuffle targeting must dispatch explicit On: " + JSON.stringify(shufCmd));

                bridge.toggleShuffle();
                assert(bridge.shuffleStatus === false, "toggleShuffle must toggle local state to false");
                var shufOffCmd = testRunner.dispatchedCommands[testRunner.dispatchedCommands.length - 1];
                assert(shufOffCmd[0] === "playerctl" && shufOffCmd[1] === "--player=io.bassi.Amberol" && shufOffCmd[2] === "shuffle" && shufOffCmd[3] === "Off", "shuffle targeting must dispatch explicit Off: " + JSON.stringify(shufOffCmd));

                bridge.cycleLoop();
                assert(bridge.loopStatus === "Playlist", "cycleLoop must cycle from None to Playlist");
                var loopCmd = testRunner.dispatchedCommands[testRunner.dispatchedCommands.length - 1];
                assert(loopCmd[0] === "playerctl" && loopCmd[1] === "--player=io.bassi.Amberol" && loopCmd[2] === "loop" && loopCmd[3] === "Playlist", "loop targeting failed");

                assert(testRunner.dispatchedCommands.length === initialCmdCount + 6, "All 6 IPC commands must be dispatched");
                break;

            case 6:
                console.log("[TEST 6] Track Transition Invalidation (Track A 142s -> Track B reset to 0.0s)");
                // Setup Track A with active position 142s and length 300s
                bridge.parseMetadata("io.bassi.Amberol|||Track A|||Artist A|||Album A|||http://artA|||Playing|||142000000|||300000000|||true|||true|||None|||false");
                assert(bridge.title === "Track A", "Track A setup");
                assert(Math.abs(bridge.positionSec - 142.0) < 0.001, "Track A position 142s");
                assert(Math.abs(bridge.lengthSec - 300.0) < 0.001, "Track A length 300s");

                // Ingest Track B transition packet without position yet or initial packet
                bridge.parseMetadata("io.bassi.Amberol|||Track B|||Artist B|||Album B|||http://artB|||Playing|||0|||192000000|||true|||true|||None|||false");
                assert(bridge.title === "Track B", "Track B transition detected");
                assert(Math.abs(bridge.positionSec - 0.0) < 0.001, "Track transition must invalidate and reset positionSec to 0.0s immediately, found: " + bridge.positionSec);
                assert(Math.abs(bridge.lengthSec - 192.0) < 0.001, "Track B length must update to 192.0s");
                break;

            case 7:
                console.log("[TEST 7] Multi-Player Session Switching (Amberol -> Brave)");
                bridge.lastPreemptionTime = 0;
                // Ingest Brave session metadata
                var braveLine = "brave|||Brave Track|||Brave Artist|||Brave Album|||http://art|||Playing|||30000000|||180000000|||true|||true|||None|||false";
                bridge.parseMetadata(braveLine);
                assert(bridge.activePlayer === "brave", "Session switch to brave failed");
                assert(bridge.canLoop === false && bridge.canShuffle === false, "Brave capabilities must be false");

                bridge.playPause();
                var bravePlayCmd = testRunner.dispatchedCommands[testRunner.dispatchedCommands.length - 1];
                assert(bravePlayCmd[0] === "playerctl" && bravePlayCmd[1] === "--player=brave" && bravePlayCmd[2] === "play-pause", "Brave targeted IPC failed: " + JSON.stringify(bravePlayCmd));

                // Switch back to Amberol session
                bridge.lastPreemptionTime = 0;
                var amberolLine = "io.bassi.Amberol|||Amberol Track|||Amberol Artist|||Amberol Album|||http://art|||Playing|||10000000|||200000000|||true|||true|||None|||false";
                bridge.parseMetadata(amberolLine);
                assert(bridge.activePlayer === "io.bassi.Amberol", "Session switch back to io.bassi.Amberol failed");
                assert(bridge.canLoop === true && bridge.canShuffle === true, "Amberol capabilities must be true");

                bridge.seek(75.0);
                var amberolSeekCmd = testRunner.dispatchedCommands[testRunner.dispatchedCommands.length - 1];
                assert(amberolSeekCmd[0] === "playerctl" && amberolSeekCmd[1] === "--player=io.bassi.Amberol" && amberolSeekCmd[2] === "position" && amberolSeekCmd[3] === "75.00", "Amberol targeted seek failed");
                break;

            case 8:
                console.log("[TEST 8] Player termination / SIGKILL wipe within 150ms");
                assert(bridge.title !== "", "Pre-condition: must have title");
                assert(bridge.playbackStatus === "Playing", "Pre-condition: must be playing");

                var tStart = Date.now();
                bridge.handlePlayerTermination();
                var tElapsed = Date.now() - tStart;

                console.log("Cleanup duration: " + tElapsed + "ms (Budget: <= 150ms)");
                assert(tElapsed <= 150, "Player termination wipe must complete within 150ms");

                assert(bridge.activePlayer === "", "ActivePlayer must wipe to empty string");
                assert(bridge.title === "", "Title must wipe to empty string");
                assert(bridge.artist === "", "Artist must wipe to empty string");
                assert(bridge.album === "", "Album must wipe to empty string");
                assert(bridge.artUrl === "", "ArtUrl must wipe to empty string");
                assert(bridge.playbackStatus === "Stopped", "PlaybackStatus must be 'Stopped'");
                assert(bridge.positionSec === 0.0, "Position must reset to 0");
                assert(bridge.lengthSec === 0.0, "Length must reset to 0");
                assert(!bridge.canGoNext && !bridge.canGoPrevious, "Navigation flags must reset");
                assert(!fsm.hasMedia, "StateMachine.hasMedia must reset to false");
                assert(!fsm.isPlaying, "StateMachine.isPlaying must reset to false");
                assert(fsm.currentState === fsm.stateIdle, "StateMachine must return to stateIdle");
                break;

            case 9:
                console.log("[TEST 9] Direct StateMachine.requestCleanup signal wipe");
                bridge.parseMetadata("amberol|||Temp Title|||Temp Artist|||Album||||||Playing|||1000000|||2000000|||false|||false|||None|||false");
                assert(bridge.activePlayer === "amberol", "Setup activePlayer failed");
                assert(bridge.title === "Temp Title", "Setup failed");

                fsm.requestCleanup();
                assert(bridge.activePlayer === "", "Direct requestCleanup must purge activePlayer");
                assert(bridge.title === "", "Direct requestCleanup must purge title");
                assert(bridge.playbackStatus === "Stopped", "Direct requestCleanup must reset status");
                break;

            case 10:
                console.log("[METRICS HARNESS] Mutual Exclusivity & Pause-Visibility Metrics");

                // [METRIC 1] Normal Playback
                bridge.parseMetadata("amberol|||Song 1|||Artist 1|||Album 1|||http://art|||Playing|||10000000|||200000000|||true|||true|||None|||false");
                fsm.isExpanded = false;
                var cVis1 = bridge.hasMedia && !fsm.isExpanded;
                var fVis1 = bridge.hasMedia && fsm.isExpanded;
                console.log("[METRIC 1] Normal Playback: hasMedia=" + bridge.hasMedia + " isPlaying=" + bridge.isPlaying + " isExpanded=" + fsm.isExpanded + " -> Capsule.visible=" + cVis1 + " Flyout.visible=" + fVis1);
                assert(bridge.hasMedia && bridge.isPlaying && !fsm.isExpanded, "Metric 1 state");
                assert(cVis1 === true && fVis1 === false, "Metric 1 visibility");

                // [METRIC 2] Click Pause (MUST NOT DISAPPEAR)
                bridge.playbackStatus = "Paused";
                fsm.isPlaying = false;
                var cVis2 = bridge.hasMedia && !fsm.isExpanded;
                var fVis2 = bridge.hasMedia && fsm.isExpanded;
                console.log("[METRIC 2] Click Pause: hasMedia=" + bridge.hasMedia + " isPlaying=" + bridge.isPlaying + " isExpanded=" + fsm.isExpanded + " -> Capsule.visible=" + cVis2 + " (MUST NOT DISAPPEAR) Flyout.visible=" + fVis2);
                assert(bridge.hasMedia && !bridge.isPlaying && !fsm.isExpanded, "Metric 2 state");
                assert(cVis2 === true && fVis2 === false, "Metric 2 visibility (Capsule must remain visible while paused)");

                // [METRIC 3] Expand Large Flyout (MUST DISAPPEAR)
                fsm.isExpanded = true;
                var cVis3 = bridge.hasMedia && !fsm.isExpanded;
                var fVis3 = bridge.hasMedia && fsm.isExpanded;
                console.log("[METRIC 3] Expand Large Flyout: hasMedia=" + bridge.hasMedia + " isPlaying=" + bridge.isPlaying + " isExpanded=" + fsm.isExpanded + " -> Capsule.visible=" + cVis3 + " (MUST DISAPPEAR) Flyout.visible=" + fVis3);
                assert(bridge.hasMedia && fsm.isExpanded, "Metric 3 state");
                assert(cVis3 === false && fVis3 === true, "Metric 3 visibility (Capsule must disappear when Flyout is expanded)");

                // [METRIC 4] Stop / Kill Player
                bridge.purge();
                fsm.dismiss();
                var cVis4 = bridge.hasMedia && !fsm.isExpanded;
                var fVis4 = bridge.hasMedia && fsm.isExpanded;
                console.log("[METRIC 4] Stop / Kill Player: hasMedia=" + bridge.hasMedia + " isPlaying=" + bridge.isPlaying + " isExpanded=" + fsm.isExpanded + " -> Capsule.visible=" + cVis4 + " Flyout.visible=" + fVis4);
                assert(!bridge.hasMedia && !bridge.isPlaying, "Metric 4 state");
                assert(cVis4 === false && fVis4 === false, "Metric 4 visibility (Both must disappear when stopped/killed)");
                break;

            case 11:
                console.log("=========================================");
                console.log("ALL MPRIS BRIDGE & MULTI-PLAYER TESTS PASSED");
                console.log("=========================================");
                running = false;
                Qt.exit(0);
                break;
            }
        }
    }
}
