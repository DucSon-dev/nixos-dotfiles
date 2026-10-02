import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

PanelWindow {
    id: osdWindow

    // Layer-shell configuration: Ephemeral Overlay surface at bottom-center
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore

    anchors {
        bottom: true
    }

    margins {
        bottom: 72
    }

    implicitWidth: 200
    implicitHeight: 56
    color: "transparent"

    property bool osdVisible: false
    visible: card.opacity > 0.0

    // OSD state
    property string osdIcon: "󰌾"
    property string osdTitle: "Caps Lock On"
    property real osdProgress: -1.0 // If >= 0, show progress bar instead of fixed indicator
    property bool isMuted: false

    // Internal trackers to detect changes
    property int lastCaps: -1
    property int lastNum: -1
    property string lastVol: ""
    property string lastBright: ""
    property bool initialSyncDone: false

    function triggerOsd(icon, title, progress) {
        osdIcon = icon;
        osdTitle = title;
        osdProgress = progress !== undefined ? progress : -1.0;
        osdVisible = true;
        osdTimer.restart();
    }

    // Auto-hide timer: 2000ms
    Timer {
        id: osdTimer
        interval: 2000
        repeat: false
        onTriggered: osdWindow.osdVisible = false
    }

    // Polling process to detect LockKeys, Volume, and Brightness changes
    Process {
        id: monitorProcess
        command: ["sh", "-c", "caps=$(cat /sys/class/leds/input*::capslock/brightness 2>/dev/null | head -n1 || echo 0); num=$(cat /sys/class/leds/input*::numlock/brightness 2>/dev/null | head -n1 || echo 0); vol=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null || echo 'Volume: 1.00'); br=$(brightnessctl -m 2>/dev/null | head -n1 || echo ''); echo \"$caps|||$num|||$vol|||$br\""]
        stdout: SplitParser {
            onRead: data => {
                var line = data.trim();
                if (line === "") return;
                var parts = line.split("|||");
                if (parts.length >= 3) {
                    var c = parseInt(parts[0].trim()) || 0;
                    var n = parseInt(parts[1].trim()) || 0;
                    var v = parts[2].trim();
                    var b = parts.length >= 4 ? parts[3].trim() : "";

                    if (!osdWindow.initialSyncDone) {
                        osdWindow.lastCaps = c;
                        osdWindow.lastNum = n;
                        osdWindow.lastVol = v;
                        osdWindow.lastBright = b;
                        osdWindow.initialSyncDone = true;
                        return;
                    }

                    // Check Caps Lock transition
                    if (c !== osdWindow.lastCaps) {
                        osdWindow.lastCaps = c;
                        var capsOn = c > 0;
                        osdWindow.triggerOsd(capsOn ? "󰌾" : "󰌿", capsOn ? "Caps Lock On" : "Caps Lock Off", -1.0);
                        return;
                    }

                    // Check Num Lock transition
                    if (n !== osdWindow.lastNum) {
                        osdWindow.lastNum = n;
                        var numOn = n > 0;
                        osdWindow.triggerOsd(numOn ? "󰎠" : "󰎡", numOn ? "Num Lock On" : "Num Lock Off", -1.0);
                        return;
                    }

                    // Check Volume transition
                    if (v !== osdWindow.lastVol && v !== "") {
                        osdWindow.lastVol = v;
                        var match = v.match(/Volume:\s+([0-9.]+)(\s+\[MUTED\])?/);
                        if (match) {
                            var val = parseFloat(match[1]);
                            var muted = !!match[2];
                            var pct = Math.round(val * 100);
                            var vIcon = muted ? "󰝟" : (val > 0.5 ? "󰕾" : (val > 0 ? "󰖀" : "󰕿"));
                            osdWindow.triggerOsd(vIcon, muted ? "Muted" : ("Volume: " + pct + "%"), muted ? 0.0 : Math.min(1.0, val));
                            return;
                        }
                    }

                    // Check Brightness transition
                    if (b !== osdWindow.lastBright && b !== "") {
                        osdWindow.lastBright = b;
                        var bParts = b.split(",");
                        if (bParts.length >= 4) {
                            var bPct = parseInt(bParts[3].replace("%", "")) || 0;
                            var bVal = bPct / 100.0;
                            osdWindow.triggerOsd(bVal > 0.5 ? "󰃠" : "󰃟", "Brightness: " + bPct + "%", bVal);
                            return;
                        }
                    }
                }
            }
        }
    }

    Timer {
        interval: 250
        running: true
        repeat: true
        onTriggered: {
            if (!monitorProcess.running) monitorProcess.running = true;
        }
    }

    Component.onCompleted: {
        monitorProcess.running = true;
    }

    // Fluent Glass Blur Card (200px x 56px, corner radius 16px, background #09090b @ 0.75, specular border)
    Rectangle {
        id: card
        anchors.fill: parent
        radius: 16
        color: Qt.rgba(9 / 255, 9 / 255, 11 / 255, 0.75)
        border.color: Qt.rgba(1.0, 1.0, 1.0, 0.12)
        border.width: 1
        clip: true

        opacity: osdWindow.osdVisible ? 1.0 : 0.0

        Behavior on opacity {
            NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 4

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 8

                Text {
                    text: osdWindow.osdIcon
                    font.pixelSize: 18
                    color: "#38bdf8"
                    Layout.alignment: Qt.AlignVCenter
                }

                Text {
                    text: osdWindow.osdTitle
                    font.family: "Geist"
                    font.pixelSize: 12
                    font.weight: Font.Medium
                    color: "#fafafa"
                    Layout.alignment: Qt.AlignVCenter
                }
            }

            // Bottom Accent Indicator / Progress Slider
            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                width: osdWindow.osdProgress >= 0 ? 140 : 60
                height: 3
                radius: 2
                color: Qt.rgba(1.0, 1.0, 1.0, 0.15)
                clip: true

                Rectangle {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: osdWindow.osdProgress >= 0 ? Math.min(parent.width, Math.max(0, parent.width * osdWindow.osdProgress)) : parent.width
                    radius: 2
                    color: "#38bdf8"
                }
            }
        }
    }
}
