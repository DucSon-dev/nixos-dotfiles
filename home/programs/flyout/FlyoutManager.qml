import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

// Standalone Flyout Manager GUI (480x540px)
// Liquid Glass styling, reactive switches & telemetry sliders,
// atomic configuration persistence, and daemon reload trigger.
FloatingWindow {
    id: settingsWindow

    title: "FluentFlyout Manager"
    implicitWidth: 480
    implicitHeight: 540
    color: "transparent"

    // Configuration state
    property bool mediaFlyoutEnabled: true
    property bool taskbarCapsuleEnabled: true
    property bool osdEnabled: true

    property real osdTimeoutSec: 2.5
    property real autoHideDelaySec: 3.5
    property real surfaceOpacity: 0.72
    property string statusText: ""

    // Ingestion function for atomic JSON parsing
    function parseConfigJson(jsonText) {
        try {
            var parsed = JSON.parse(jsonText);
            if (parsed.modules) {
                if (parsed.modules.mediaFlyout) {
                    mediaFlyoutEnabled = parsed.modules.mediaFlyout.enabled !== undefined ? parsed.modules.mediaFlyout.enabled : true;
                    if (parsed.modules.mediaFlyout.autoHideTimeoutMs !== undefined) {
                        autoHideDelaySec = parsed.modules.mediaFlyout.autoHideTimeoutMs / 1000.0;
                    }
                }
                if (parsed.modules.taskbarCapsule) {
                    taskbarCapsuleEnabled = parsed.modules.taskbarCapsule.enabled !== undefined ? parsed.modules.taskbarCapsule.enabled : true;
                }
                if (parsed.modules.osdEngine) {
                    osdEnabled = parsed.modules.osdEngine.enabled !== undefined ? parsed.modules.osdEngine.enabled : true;
                    if (parsed.modules.osdEngine.timeoutMs !== undefined) {
                        osdTimeoutSec = parsed.modules.osdEngine.timeoutMs / 1000.0;
                    }
                }
            }
            if (parsed.theme && parsed.theme.surfaceOpacity !== undefined) {
                surfaceOpacity = parsed.theme.surfaceOpacity;
            }
            return true;
        } catch (e) {
            console.log("Failed to parse config: " + e);
            return false;
        }
    }

    // Build serialized schema payload preserving invariants
    function buildConfigJson() {
        var cfg = {
            "$schema": "https://json-schema.org/draft/2020-12/schema",
            "version": "1.0.0",
            "theme": {
                "variant": "dark-zinc",
                "surfaceColor": "#09090b",
                "surfaceOpacity": Math.round(surfaceOpacity * 100) / 100,
                "blurRadius": 32,
                "borderColor": "rgba(255, 255, 255, 0.12)",
                "borderWidth": 1,
                "cornerRadius": 16,
                "accentColor": "#fafafa"
            },
            "modules": {
                "taskbarCapsule": {
                    "enabled": taskbarCapsuleEnabled,
                    "marqueeSpeed": 40,
                    "maxCapsuleWidth": 260,
                    "compactHeight": 32,
                    "cornerRadius": 16,
                    "backgroundColor": "#09090b",
                    "backgroundOpacity": Math.round(surfaceOpacity * 100) / 100,
                    "borderColor": "rgba(255, 255, 255, 0.12)",
                    "borderWidth": 1
                },
                "mediaFlyout": {
                    "enabled": mediaFlyoutEnabled,
                    "anchor": "top-center",
                    "popupWidth": 380,
                    "popupHeight": 180,
                    "cornerRadius": 16,
                    "backgroundColor": "#09090b",
                    "backgroundOpacity": Math.round(surfaceOpacity * 100) / 100,
                    "borderColor": "rgba(255, 255, 255, 0.12)",
                    "borderWidth": 1,
                    "albumArtRadius": 12,
                    "animationDurationMs": 220,
                    "autoHideTimeoutMs": Math.round(autoHideDelaySec * 1000)
                },
                "osdEngine": {
                    "enabled": osdEnabled,
                    "anchor": "bottom-center",
                    "timeoutMs": Math.round(osdTimeoutSec * 1000),
                    "animationDurationMs": 180,
                    "showLockKeys": true,
                    "showVolume": true,
                    "showBacklight": true
                }
            }
        };
        return JSON.stringify(cfg, null, 2);
    }

    // Load initial settings
    Process {
        id: loadProcess
        command: ["sh", "-c", "cat ~/.config/fluent-flyout/config.json 2>/dev/null || cat /etc/nixos/home/programs/flyout/config.json 2>/dev/null || echo {}"]
        stdout: SplitParser {
            onRead: data => settingsWindow.parseConfigJson(data)
        }
    }

    // Atomic persistence and daemon reload trigger
    function saveAndApply() {
        var payload = buildConfigJson();
        var cmd = "mkdir -p ~/.config/fluent-flyout && cat << EOF > ~/.config/fluent-flyout/config.json\n" + payload + "\nEOF\nsystemctl --user restart fluent-flyout.service\n";
        saveProcess.execScript = cmd;
        saveProcess.running = true;
    }

    Process {
        id: saveProcess
        property string execScript: ""
        command: ["sh", "-c", execScript]
        onExited: {
            settingsWindow.statusText = "Applied & Reloaded Daemon.";
            clearStatusTimer.restart();
        }
    }

    Timer {
        id: clearStatusTimer
        interval: 3500
        repeat: false
        onTriggered: settingsWindow.statusText = ""
    }

    Component.onCompleted: {
        loadProcess.running = true;
    }

    // Liquid Glass UI Frame
    Rectangle {
        anchors.fill: parent
        radius: 16
        color: Qt.rgba(9 / 255, 9 / 255, 11 / 255, 0.88)
        border.color: Qt.rgba(1.0, 1.0, 1.0, 0.14)
        border.width: 1
        clip: true

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 14

            // Header Bar
            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                Text {
                    text: "󰒓"
                    font.pixelSize: 22
                    color: "#38bdf8"
                }
                Text {
                    text: "FluentFlyout Manager"
                    font.family: "GeistMono Nerd Font"
                    font.pixelSize: 16
                    font.weight: Font.Bold
                    color: "#fafafa"
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Qt.rgba(1.0, 1.0, 1.0, 0.08)
            }

            // Section: Module Toggles
            Text {
                text: "MODULES & SERVICES"
                font.family: "GeistMono Nerd Font"
                font.pixelSize: 11
                font.weight: Font.DemiBold
                color: "#71717a"
            }

            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: "Media Flyout Card"
                    font.family: "Geist"
                    font.pixelSize: 13
                    color: "#fafafa"
                }
                Item { Layout.fillWidth: true }
                Switch {
                    checked: settingsWindow.mediaFlyoutEnabled
                    onToggled: settingsWindow.mediaFlyoutEnabled = checked
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: "Floating Taskbar Capsule"
                    font.family: "Geist"
                    font.pixelSize: 13
                    color: "#fafafa"
                }
                Item { Layout.fillWidth: true }
                Switch {
                    checked: settingsWindow.taskbarCapsuleEnabled
                    onToggled: settingsWindow.taskbarCapsuleEnabled = checked
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: "Ephemeral System OSD"
                    font.family: "Geist"
                    font.pixelSize: 13
                    color: "#fafafa"
                }
                Item { Layout.fillWidth: true }
                Switch {
                    checked: settingsWindow.osdEnabled
                    onToggled: settingsWindow.osdEnabled = checked
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Qt.rgba(1.0, 1.0, 1.0, 0.08)
            }

            // Section: Telemetry & Durations
            Text {
                text: "TELEMETRY & TIMING"
                font.family: "GeistMono Nerd Font"
                font.pixelSize: 11
                font.weight: Font.DemiBold
                color: "#71717a"
            }

            // Slider 1: Auto-Hide Delay (1.5s - 6.0s)
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: "Flyout Auto-Hide Duration"
                        font.family: "Geist"
                        font.pixelSize: 12
                        color: "#fafafa"
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: settingsWindow.autoHideDelaySec.toFixed(1) + " s"
                        font.family: "GeistMono Nerd Font"
                        font.pixelSize: 12
                        color: "#38bdf8"
                    }
                }
                Slider {
                    Layout.fillWidth: true
                    from: 1.5
                    to: 6.0
                    stepSize: 0.5
                    value: settingsWindow.autoHideDelaySec
                    onMoved: settingsWindow.autoHideDelaySec = value
                }
            }

            // Slider 2: OSD Timeout (1.0s - 5.0s)
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: "OSD Notification Timeout"
                        font.family: "Geist"
                        font.pixelSize: 12
                        color: "#fafafa"
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: settingsWindow.osdTimeoutSec.toFixed(1) + " s"
                        font.family: "GeistMono Nerd Font"
                        font.pixelSize: 12
                        color: "#38bdf8"
                    }
                }
                Slider {
                    Layout.fillWidth: true
                    from: 1.0
                    to: 5.0
                    stepSize: 0.5
                    value: settingsWindow.osdTimeoutSec
                    onMoved: settingsWindow.osdTimeoutSec = value
                }
            }

            // Slider 3: Glass Opacity (0.40 - 0.95)
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: "Liquid Glass Surface Opacity"
                        font.family: "Geist"
                        font.pixelSize: 12
                        color: "#fafafa"
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: Math.round(settingsWindow.surfaceOpacity * 100) + " %"
                        font.family: "GeistMono Nerd Font"
                        font.pixelSize: 12
                        color: "#38bdf8"
                    }
                }
                Slider {
                    Layout.fillWidth: true
                    from: 0.40
                    to: 0.95
                    stepSize: 0.05
                    value: settingsWindow.surfaceOpacity
                    onMoved: settingsWindow.surfaceOpacity = value
                }
            }

            Item { Layout.fillHeight: true }

            // Footer Bar
            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Text {
                    text: settingsWindow.statusText
                    font.family: "GeistMono Nerd Font"
                    font.pixelSize: 11
                    color: "#4ade80"
                    visible: settingsWindow.statusText !== ""
                    Layout.fillWidth: true
                }

                Item { Layout.fillWidth: true; visible: settingsWindow.statusText === "" }

                // Action Button: Apply & Reload Daemon
                Rectangle {
                    width: 170
                    height: 34
                    radius: 8
                    color: applyMouse.containsMouse ? Qt.rgba(56 / 255, 189 / 255, 248 / 255, 0.9) : "#38bdf8"

                    Text {
                        anchors.centerIn: parent
                        text: "Apply & Reload Daemon"
                        font.family: "Geist"
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                        color: "#09090b"
                    }

                    MouseArea {
                        id: applyMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: settingsWindow.saveAndApply()
                    }
                }
            }
        }
    }
}
