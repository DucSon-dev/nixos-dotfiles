import QtQuick
import Quickshell
import Quickshell.Io

// Pure Headless Watcher for System OSD (Volume, Brightness, Lock Keys)
// 0% visual rendering. Emits clean reactive signals upon hardware property transitions.
QtObject {
    id: root

    // Reactive State
    property real volumeLevel: 1.0
    property bool isMuted: false
    property int brightnessPercent: 100
    property bool capsLockActive: false
    property bool numLockActive: false

    // Signals
    signal volumeChanged(real level, bool muted)
    signal brightnessChanged(int percent)
    signal lockKeyChanged(string keyName, bool active)

    // Internal trackers to avoid spurious emissions
    property real _lastVol: -1.0
    property int _lastMuted: -1
    property int _lastBright: -1
    property int _lastCaps: -1
    property int _lastNum: -1
    property bool _initialSyncDone: false

    // Ingestion function (tested directly by headless test harnesses)
    function parseProbeData(data) {
        if (!data || data.trim() === "") return;
        var parts = data.trim().split("|||");
        if (parts.length >= 3) {
            var c = parseInt(parts[0].trim()) || 0;
            var n = parseInt(parts[1].trim()) || 0;
            var vStr = parts[2].trim();
            var bStr = parts.length >= 4 ? parts[3].trim() : "";

            var capsOn = c > 0;
            var numOn = n > 0;

            // Parse volume string e.g. "Volume: 0.65" or "Volume: 0.65 [MUTED]"
            var vLevel = root.volumeLevel;
            var vMuted = root.isMuted;
            var match = vStr.match(/Volume:\s+([0-9.]+)(\s+\[MUTED\])?/);
            if (match) {
                vLevel = parseFloat(match[1]);
                vMuted = !!match[2];
            }

            // Parse brightness percentage e.g. from "input3::numlock,leds,0,0%,1" or "intel_backlight,backlight,500,50%,1000"
            var bPct = root.brightnessPercent;
            if (bStr !== "") {
                var bParts = bStr.split(",");
                if (bParts.length >= 4) {
                    var parsed = parseInt(bParts[3].replace("%", ""));
                    if (!isNaN(parsed)) bPct = parsed;
                }
            }

            if (!_initialSyncDone) {
                root.capsLockActive = capsOn;
                root.numLockActive = numOn;
                root.volumeLevel = vLevel;
                root.isMuted = vMuted;
                root.brightnessPercent = bPct;

                _lastCaps = c;
                _lastNum = n;
                _lastVol = vLevel;
                _lastMuted = vMuted ? 1 : 0;
                _lastBright = bPct;
                _initialSyncDone = true;
                return;
            }

            // Check Caps Lock change
            if (c !== _lastCaps) {
                _lastCaps = c;
                root.capsLockActive = capsOn;
                root.lockKeyChanged("CapsLock", capsOn);
            }

            // Check Num Lock change
            if (n !== _lastNum) {
                _lastNum = n;
                root.numLockActive = numOn;
                root.lockKeyChanged("NumLock", numOn);
            }

            // Check Volume / Mute change
            var mutedInt = vMuted ? 1 : 0;
            if (Math.abs(vLevel - _lastVol) > 0.005 || mutedInt !== _lastMuted) {
                _lastVol = vLevel;
                _lastMuted = mutedInt;
                root.volumeLevel = vLevel;
                root.isMuted = vMuted;
                root.volumeChanged(vLevel, vMuted);
            }

            // Check Brightness change
            if (bPct !== _lastBright) {
                _lastBright = bPct;
                root.brightnessPercent = bPct;
                root.brightnessChanged(bPct);
            }
        }
    }

    // Native hardware monitor process
    property Process monitorProcess: Process {
        command: [
            "sh", "-c",
            "caps=$(cat /sys/class/leds/input*::capslock/brightness 2>/dev/null | head -n1 || echo 0); num=$(cat /sys/class/leds/input*::numlock/brightness 2>/dev/null | head -n1 || echo 0); vol=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null || echo \"Volume: 1.00\"); br=$(brightnessctl -m 2>/dev/null | head -n1 || echo \"\"); echo \"$caps|||$num|||$vol|||$br\""
        ]
        stdout: SplitParser {
            onRead: data => root.parseProbeData(data)
        }
    }

    // Periodic poller (250ms cadence)
    property Timer pollTimer: Timer {
        interval: 250
        running: true
        repeat: true
        onTriggered: {
            if (!monitorProcess.running) {
                monitorProcess.running = true;
            }
        }
    }

    Component.onCompleted: {
        monitorProcess.running = true;
    }
}
