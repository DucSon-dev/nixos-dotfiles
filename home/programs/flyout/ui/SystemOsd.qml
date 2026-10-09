import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

// Ephemeral System OSD Presentation Surface (Volume, Brightness, Lock Keys)
// 2.0s auto-hide timer, Liquid Glass Dark Zinc card, 16px radius, specular border.
PanelWindow {
    id: osdWindow

    // Injected Headless Bridge Dependency
    property QtObject bridge: null

    // Layer-Shell configuration: Ephemeral Overlay surface at bottom-center
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore

    // Configurable anchor placement (default: bottom-center overlay)
    property string anchorPosition: "bottom-center"
    readonly property bool isTopAnchor: anchorPosition.indexOf("top") !== -1

    anchors {
        top: isTopAnchor
        bottom: !isTopAnchor
    }

    margins {
        top: isTopAnchor ? 64 : 0
        bottom: !isTopAnchor ? 72 : 0
    }

    implicitWidth: 200
    implicitHeight: 56
    color: "transparent"

    property bool osdVisible: false
    visible: card.opacity > 0.0

    // OSD Visual State
    property string osdIcon: "󰌾"
    property string osdTitle: "Caps Lock On"
    property real osdProgress: -1.0 // If >= 0, show visual gauge; else show accent pill

    function triggerOsd(icon, title, progress) {
        osdIcon = icon;
        osdTitle = title;
        osdProgress = progress !== undefined ? progress : -1.0;
        osdVisible = true;
        dismissTimer.restart();
    }

    // Auto-hide countdown timer: 2000ms
    Timer {
        id: dismissTimer
        interval: 2000
        repeat: false
        onTriggered: osdWindow.osdVisible = false
    }

    // Bind reactive signals from bridge
    Connections {
        target: osdWindow.bridge
        function onLockKeyChanged(keyName, active) {
            if (keyName === "CapsLock") {
                osdWindow.triggerOsd(active ? "󰌾" : "󰌿", active ? "Caps Lock On" : "Caps Lock Off", -1.0);
            } else if (keyName === "NumLock") {
                osdWindow.triggerOsd(active ? "󰎠" : "󰎡", active ? "Num Lock On" : "Num Lock Off", -1.0);
            }
        }

        function onVolumeChanged(level, muted) {
            var pct = Math.round(level * 100);
            var icon = muted ? "󰝟" : (level > 0.5 ? "󰕾" : (level > 0 ? "󰖀" : "󰕿"));
            var title = muted ? "Muted" : ("Volume: " + pct + "%");
            var progress = muted ? 0.0 : Math.min(1.0, Math.max(0.0, level));
            osdWindow.triggerOsd(icon, title, progress);
        }

        function onBrightnessChanged(percent) {
            var val = percent / 100.0;
            var icon = val > 0.5 ? "󰃠" : "󰃟";
            osdWindow.triggerOsd(icon, "Brightness: " + percent + "%", Math.min(1.0, Math.max(0.0, val)));
        }
    }

    // Liquid Glass Card Container
    Rectangle {
        id: card
        anchors.fill: parent
        radius: 16
        color: Qt.rgba(9 / 255, 9 / 255, 11 / 255, 0.72)
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
                    font.family: "GeistMono Nerd Font"
                    font.pixelSize: 12
                    font.weight: Font.Medium
                    color: "#fafafa"
                    Layout.alignment: Qt.AlignVCenter
                }
            }

            // Bottom Accent Indicator / Progress Gauge
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
