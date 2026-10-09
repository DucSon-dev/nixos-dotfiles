import QtQuick
import Quickshell
import "core" as Core

Scope {
    id: probeScope

    Core.StateMachine {
        id: stateMachine
    }

    Core.MprisBridge {
        id: mprisBridge
        stateMachine: stateMachine
    }

    Timer {
        interval: 80
        repeat: true
        running: true
        property int count: 0
        onTriggered: {
            count++;
            console.log("PROBE_LIVE: player='" + mprisBridge.activePlayer + "' title='" + mprisBridge.title + "' status='" + mprisBridge.playbackStatus + "' hasMedia=" + mprisBridge.hasMedia + " isPlaying=" + mprisBridge.isPlaying);
            if (mprisBridge.activePlayer !== "" && mprisBridge.title !== "") {
                console.log("PROBE_LIVE_SUCCESS: player='" + mprisBridge.activePlayer + "' title='" + mprisBridge.title + "' isPlaying=" + mprisBridge.isPlaying);
                Qt.quit();
            }
            if (count >= 15) {
                console.error("PROBE_LIVE_TIMEOUT");
                Qt.quit();
            }
        }
    }
}
