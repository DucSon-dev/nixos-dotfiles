import QtQuick
import "../core" as Core

// Headless Automated Test Harness for OsdBridge.qml
QtObject {
    id: testRunner

    property Core.OsdBridge bridge: Core.OsdBridge {}

    property int testStep: 0
    property var receivedVolume: []
    property var receivedBrightness: []
    property var receivedLockKeys: []

    property var _conn: Connections {
        target: testRunner.bridge
        function onVolumeChanged(level, muted) {
            testRunner.receivedVolume.push({ level: level, muted: muted });
        }
        function onBrightnessChanged(percent) {
            testRunner.receivedBrightness.push(percent);
        }
        function onLockKeyChanged(keyName, active) {
            testRunner.receivedLockKeys.push({ key: keyName, active: active });
        }
    }

    function assert(condition, message) {
        if (!condition) {
            console.error("FAIL: " + message);
            Qt.exit(1);
        }
    }

    property Timer runnerTimer: Timer {
        interval: 15
        repeat: true
        running: true
        onTriggered: {
            testRunner.testStep++;

            switch (testRunner.testStep) {
            case 1:
                console.log("[TEST 1] Initial OSD sync from probe data");
                // caps=0, num=0, vol=0.50, bright=40%
                bridge.parseProbeData("0|||0|||Volume: 0.50|||intel_backlight,backlight,400,40%,1000");
                assert(bridge.capsLockActive === false, "Caps lock initial sync");
                assert(bridge.numLockActive === false, "Num lock initial sync");
                assert(Math.abs(bridge.volumeLevel - 0.50) < 0.001, "Volume level initial sync");
                assert(bridge.isMuted === false, "Mute initial sync");
                assert(bridge.brightnessPercent === 40, "Brightness initial sync");
                // Initial sync should NOT emit spurious change signals
                assert(testRunner.receivedVolume.length === 0, "Initial sync must not emit volumeChanged");
                assert(testRunner.receivedBrightness.length === 0, "Initial sync must not emit brightnessChanged");
                assert(testRunner.receivedLockKeys.length === 0, "Initial sync must not emit lockKeyChanged");
                break;

            case 2:
                console.log("[TEST 2] Volume step and Mute detection");
                bridge.parseProbeData("0|||0|||Volume: 0.75|||intel_backlight,backlight,400,40%,1000");
                assert(testRunner.receivedVolume.length === 1, "volumeChanged emitted");
                assert(Math.abs(testRunner.receivedVolume[0].level - 0.75) < 0.001, "Volume level 0.75");
                assert(testRunner.receivedVolume[0].muted === false, "Volume unmuted");

                bridge.parseProbeData("0|||0|||Volume: 0.75 [MUTED]|||intel_backlight,backlight,400,40%,1000");
                assert(testRunner.receivedVolume.length === 2, "Mute toggle emitted");
                assert(testRunner.receivedVolume[1].muted === true, "Muted state detected");
                break;

            case 3:
                console.log("[TEST 3] Brightness percentage step");
                bridge.parseProbeData("0|||0|||Volume: 0.75 [MUTED]|||intel_backlight,backlight,850,85%,1000");
                assert(testRunner.receivedBrightness.length === 1, "brightnessChanged emitted");
                assert(testRunner.receivedBrightness[0] === 85, "Brightness 85% received");
                assert(bridge.brightnessPercent === 85, "Bridge property updated");
                break;

            case 4:
                console.log("[TEST 4] Caps Lock and Num Lock transitions");
                // Toggle CapsLock On
                bridge.parseProbeData("1|||0|||Volume: 0.75 [MUTED]|||intel_backlight,backlight,850,85%,1000");
                assert(testRunner.receivedLockKeys.length === 1, "lockKeyChanged emitted for Caps");
                assert(testRunner.receivedLockKeys[0].key === "CapsLock" && testRunner.receivedLockKeys[0].active === true, "CapsLock On detected");

                // Toggle NumLock On
                bridge.parseProbeData("1|||1|||Volume: 0.75 [MUTED]|||intel_backlight,backlight,850,85%,1000");
                assert(testRunner.receivedLockKeys.length === 2, "lockKeyChanged emitted for Num");
                assert(testRunner.receivedLockKeys[1].key === "NumLock" && testRunner.receivedLockKeys[1].active === true, "NumLock On detected");

                // Toggle CapsLock Off
                bridge.parseProbeData("0|||1|||Volume: 0.75 [MUTED]|||intel_backlight,backlight,850,85%,1000");
                assert(testRunner.receivedLockKeys.length === 3, "lockKeyChanged emitted for Caps Off");
                assert(testRunner.receivedLockKeys[2].key === "CapsLock" && testRunner.receivedLockKeys[2].active === false, "CapsLock Off detected");
                break;

            case 5:
                console.log("=========================================");
                console.log("ALL SYSTEM OSD TESTS PASSED");
                console.log("=========================================");
                running = false;
                Qt.exit(0);
                break;
            }
        }
    }
}
