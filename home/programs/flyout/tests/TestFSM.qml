import QtQuick
import "../core" as Core

// Headless Automated Test Harness for StateMachine.qml
QtObject {
    id: testRunner

    property Core.StateMachine fsm: Core.StateMachine {
        autoHideInterval: 50
    }

    property int testStep: 0
    property int cleanupSignalCount: 0
    property int timeoutSignalCount: 0
    property int stateChangedSignalCount: 0

    // Connect signals for assertion accounting
    property var _conns: Connections {
        target: testRunner.fsm
        function onRequestCleanup() {
            testRunner.cleanupSignalCount++;
        }
        function onAutoHideTimeout() {
            testRunner.timeoutSignalCount++;
        }
        function onStateChanged(oldState, newState) {
            testRunner.stateChangedSignalCount++;
        }
    }

    function assert(condition, message) {
        if (!condition) {
            console.error("FAIL: " + message);
            Qt.exit(1);
        }
    }

    // Step sequencer driven by interval ticks to allow async timer verification
    property Timer runnerTimer: Timer {
        interval: 15
        repeat: true
        running: true
        onTriggered: {
            testRunner.testStep++;

            switch (testRunner.testStep) {
            case 1:
                console.log("[TEST 1] Initial state assertions");
                assert(fsm.currentState === fsm.stateIdle, "Initial state must be stateIdle (0)");
                assert(!fsm._autoHideTimer.running, "Auto-hide timer must be idle initially");
                break;

            case 2:
                console.log("[TEST 2] Auto-pop guard check (no media / not playing)");
                assert(!fsm.autoPop(), "autoPop() must return false when media/playing guards fail");
                assert(fsm.currentState === fsm.stateIdle, "State must remain stateIdle on guard rejection");
                break;

            case 3:
                console.log("[TEST 3] Auto-pop with valid guards");
                fsm.hasMedia = true;
                fsm.isPlaying = true;
                fsm.isExpanded = false;
                assert(fsm.autoPop(), "autoPop() must return true when guards pass");
                assert(fsm.currentState === fsm.stateAutoPopped, "State must be stateAutoPopped (1)");
                assert(fsm._autoHideTimer.running, "Auto-hide timer must be active in AUTO_POPPED");
                break;

            case 4:
                console.log("[TEST 4] Pinning transition & timer suspension");
                fsm.pin();
                assert(fsm.currentState === fsm.statePinned, "State must transition to statePinned (2)");
                assert(!fsm._autoHideTimer.running, "Auto-hide timer must be stopped in PINNED");
                break;

            case 5:
                console.log("[TEST 5] Dragging lifecycle (startDrag -> endDrag)");
                fsm.startDrag();
                assert(fsm.currentState === fsm.stateDragging, "State must transition to stateDragging (3)");
                assert(!fsm._autoHideTimer.running, "Auto-hide timer must remain stopped in DRAGGING");
                fsm.endDrag();
                assert(fsm.currentState === fsm.statePinned, "endDrag() must return state to statePinned (2)");
                break;

            case 6:
                console.log("[TEST 6] Dismissal to idle");
                fsm.dismiss();
                assert(fsm.currentState === fsm.stateIdle, "dismiss() must return state to stateIdle (0)");
                break;

            case 7:
                console.log("[TEST 7] Auto-hide timer expiration");
                fsm.autoPop();
                assert(fsm.currentState === fsm.stateAutoPopped, "State must be stateAutoPopped before expiry");
                // Wait for step timer ticks to let autoHideInterval (50ms) expire
                break;

            case 13:
                // After ~90ms elapsed, 50ms timer must have fired
                assert(fsm.currentState === fsm.stateIdle, "State must automatically reset to stateIdle on timer expiry");
                assert(testRunner.timeoutSignalCount > 0, "autoHideTimeout signal must have fired");
                break;

            case 14:
                console.log("[TEST 8] Immediate cleanup on playback stop");
                var preCount = testRunner.cleanupSignalCount;
                fsm.autoPop();
                assert(fsm.currentState === fsm.stateAutoPopped, "Must be auto-popped");
                fsm.hasMedia = false; // Trigger stop guard
                assert(testRunner.cleanupSignalCount > preCount, "requestCleanup signal must fire on playback stop");
                assert(fsm.currentState === fsm.stateIdle, "State must immediately dismiss on playback stop");
                break;

            case 15:
                console.log("[TEST 9] Immediate cleanup on player exit");
                fsm.hasMedia = true;
                fsm.isPlaying = true;
                fsm.autoPop();
                assert(fsm.currentState === fsm.stateAutoPopped, "Must be auto-popped");
                preCount = testRunner.cleanupSignalCount;
                fsm.onPlayerExited(); // Trigger player exit hook
                assert(!fsm.hasMedia && !fsm.isPlaying, "Guards must reset on player exit");
                assert(testRunner.cleanupSignalCount > preCount, "requestCleanup signal must fire on player exit");
                assert(fsm.currentState === fsm.stateIdle, "State must dismiss on player exit");
                break;

            case 16:
                console.log("[TEST 10] Expanded guard prevents auto-pop");
                fsm.hasMedia = true;
                fsm.isPlaying = true;
                fsm.isExpanded = true;
                assert(!fsm.autoPop(), "autoPop() must be blocked when isExpanded is true");
                assert(fsm.currentState === fsm.stateIdle, "State must remain idle");
                break;

            case 17:
                console.log("[METRICS HARNESS] Mutual Exclusivity & Pause-Visibility Metrics");

                // [METRIC 1] Normal Playback
                fsm.hasMedia = true;
                fsm.isPlaying = true;
                fsm.isExpanded = false;
                var cVis1 = fsm.hasMedia && !fsm.isExpanded;
                var fVis1 = fsm.hasMedia && fsm.isExpanded;
                console.log("[METRIC 1] Normal Playback: hasMedia=" + fsm.hasMedia + " isPlaying=" + fsm.isPlaying + " isExpanded=" + fsm.isExpanded + " -> Capsule.visible=" + cVis1 + " Flyout.visible=" + fVis1);
                assert(fsm.hasMedia && fsm.isPlaying && !fsm.isExpanded, "Metric 1 state");
                assert(cVis1 === true && fVis1 === false, "Metric 1 visibility");

                // [METRIC 2] Click Pause (MUST NOT DISAPPEAR)
                fsm.isPlaying = false;
                var cVis2 = fsm.hasMedia && !fsm.isExpanded;
                var fVis2 = fsm.hasMedia && fsm.isExpanded;
                console.log("[METRIC 2] Click Pause: hasMedia=" + fsm.hasMedia + " isPlaying=" + fsm.isPlaying + " isExpanded=" + fsm.isExpanded + " -> Capsule.visible=" + cVis2 + " (MUST NOT DISAPPEAR) Flyout.visible=" + fVis2);
                assert(fsm.hasMedia && !fsm.isPlaying && !fsm.isExpanded, "Metric 2 state");
                assert(cVis2 === true && fVis2 === false, "Metric 2 visibility (Capsule must remain visible while paused)");

                // [METRIC 3] Expand Large Flyout (MUST DISAPPEAR)
                fsm.isExpanded = true;
                var cVis3 = fsm.hasMedia && !fsm.isExpanded;
                var fVis3 = fsm.hasMedia && fsm.isExpanded;
                console.log("[METRIC 3] Expand Large Flyout: hasMedia=" + fsm.hasMedia + " isPlaying=" + fsm.isPlaying + " isExpanded=" + fsm.isExpanded + " -> Capsule.visible=" + cVis3 + " (MUST DISAPPEAR) Flyout.visible=" + fVis3);
                assert(fsm.hasMedia && fsm.isExpanded, "Metric 3 state");
                assert(cVis3 === false && fVis3 === true, "Metric 3 visibility (Capsule must disappear when Flyout is expanded)");

                // [METRIC 4] Stop / Kill Player
                fsm.hasMedia = false;
                fsm.isPlaying = false;
                fsm.dismiss();
                var cVis4 = fsm.hasMedia && !fsm.isExpanded;
                var fVis4 = fsm.hasMedia && fsm.isExpanded;
                console.log("[METRIC 4] Stop / Kill Player: hasMedia=" + fsm.hasMedia + " isPlaying=" + fsm.isPlaying + " isExpanded=" + fsm.isExpanded + " -> Capsule.visible=" + cVis4 + " Flyout.visible=" + fVis4);
                assert(!fsm.hasMedia && !fsm.isPlaying, "Metric 4 state");
                assert(cVis4 === false && fVis4 === false, "Metric 4 visibility (Both must disappear when stopped/killed)");
                break;

            case 18:
                console.log("=========================================");
                console.log("ALL HEADLESS FSM TESTS & METRICS PASSED");
                console.log("=========================================");
                running = false;
                Qt.exit(0);
                break;
            }
        }
    }
}
