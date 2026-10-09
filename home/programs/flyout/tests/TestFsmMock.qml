import QtQuick
import "../core" as Core

// Headless verification harness simulating track change and manual toggle events against StateMachine
QtObject {
    id: runner

    property Core.StateMachine fsm: Core.StateMachine {
        autoHideInterval: 40
    }

    property int step: 0
    property int stateChangeCount: 0

    property var _conn: Connections {
        target: runner.fsm
        function onStateChanged(oldS, newS) {
            runner.stateChangeCount++;
        }
    }

    function assert(cond, msg) {
        if (!cond) {
            console.error("FAIL: " + msg);
            Qt.exit(1);
        }
    }

    property Timer clock: Timer {
        interval: 10
        repeat: true
        running: true
        onTriggered: {
            runner.step++;
            switch (runner.step) {
            case 1:
                console.log("[MOCK TEST 1] Baseline state: IDLE");
                assert(fsm.currentState === fsm.stateIdle, "Must start IDLE");
                assert(!fsm.isExpanded, "Must not be expanded initially");
                break;

            case 2:
                console.log("[MOCK TEST 2] Track change event triggers AUTO_POPPED");
                fsm.hasMedia = true;
                fsm.isPlaying = true;
                var popped = fsm.autoPop();
                assert(popped === true, "autoPop() must succeed on track change");
                assert(fsm.currentState === fsm.stateAutoPopped, "State must be AUTO_POPPED (1)");
                assert(fsm.isExpanded === true, "isExpanded must be true in AUTO_POPPED");
                assert(fsm._autoHideTimer.running === true, "Timer must run in AUTO_POPPED");
                break;

            case 3:
                console.log("[MOCK TEST 3] Rapid second track change re-arms timer without locking");
                var rePopped = fsm.autoPop();
                assert(fsm.currentState === fsm.stateAutoPopped, "Must maintain AUTO_POPPED");
                assert(fsm._autoHideTimer.running === true, "Timer must stay re-armed");
                break;

            case 8:
                console.log("[MOCK TEST 4] Auto-hide timer expires back to IDLE");
                assert(fsm.currentState === fsm.stateIdle, "State must return to IDLE after timeout");
                assert(fsm.isExpanded === false, "isExpanded must revert to false");
                break;

            case 9:
                console.log("[MOCK TEST 5] Taskbar click triggers MANUALLY_PINNED");
                fsm.togglePin();
                assert(fsm.currentState === fsm.statePinned, "State must transition to statePinned (2)");
                assert(fsm.isExpanded === true, "isExpanded must be true in PINNED");
                assert(fsm._autoHideTimer.running === false, "Timer must be suspended when PINNED");
                break;

            case 10:
                console.log("[MOCK TEST 6] Track change while PINNED does NOT auto-dismiss or alter PINNED state");
                var blockedPop = fsm.autoPop();
                assert(blockedPop === false, "autoPop must be ignored when PINNED");
                assert(fsm.currentState === fsm.statePinned, "State must remain PINNED");
                break;

            case 11:
                console.log("[MOCK TEST 7] Second taskbar click toggles PINNED back to IDLE");
                fsm.togglePin();
                assert(fsm.currentState === fsm.stateIdle, "togglePin must toggle back to IDLE");
                assert(fsm.isExpanded === false, "isExpanded must revert to false");
                break;

            case 12:
                console.log("=========================================");
                console.log("SLICE 1 FSM MOCK VERIFICATION SUITE PASSED");
                console.log("=========================================");
                running = false;
                Qt.exit(0);
                break;
            }
        }
    }
}
