import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

FloatingWindow {
    id: settingsWindow

    title: "Fluent Flyout Settings"
    implicitWidth: 480
    implicitHeight: 540
    color: "transparent"

    // Configuration state
    property bool mediaFlyoutEnabled: true
    property bool autoPopupEnabled: true
    property bool osdEnabled: true
    property bool capsuleAutoHide: true

    property real timeoutMs: 3500
    property real surfaceOpacity: 0.75
    property real capsuleWidth: 260
    property string statusText: ""

    // Load initial settings from config.json
    Process {
        id: loadProcess
        command: ["sh", "-c", "cat ~/.config/fluent-flyout/config.json 2>/dev/null || cat /etc/nixos/home/programs/flyout/config.json 2>/dev/null || echo '{}'"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var parsed = JSON.parse(this.text);
                    if (parsed.modules) {
                        if (parsed.modules.mediaFlyout) {
                            settingsWindow.mediaFlyoutEnabled = parsed.modules.mediaFlyout.enabled !== undefined ? parsed.modules.mediaFlyout.enabled : true;
                            settingsWindow.timeoutMs = parsed.modules.mediaFlyout.autoHideTimeoutMs !== undefined ? parsed.modules.mediaFlyout.autoHideTimeoutMs : 3500;
                            settingsWindow.autoPopupEnabled = parsed.modules.mediaFlyout.autoPopupOnTrackChange !== undefined ? parsed.modules.mediaFlyout.autoPopupOnTrackChange : true;
                        }
                        if (parsed.modules.osdEngine) {
                            settingsWindow.osdEnabled = parsed.modules.osdEngine.enabled !== undefined ? parsed.modules.osdEngine.enabled : true;
                        }
                        if (parsed.modules.taskbarCapsule) {
                            settingsWindow.capsuleWidth = parsed.modules.taskbarCapsule.maxCapsuleWidth !== undefined ? parsed.modules.taskbarCapsule.maxCapsuleWidth : 260;
                            settingsWindow.capsuleAutoHide = parsed.modules.taskbarCapsule.hideWhenEmpty !== undefined ? parsed.modules.taskbarCapsule.hideWhenEmpty : true;
                        }
                    }
                    if (parsed.theme) {
                        settingsWindow.surfaceOpacity = parsed.theme.surfaceOpacity !== undefined ? parsed.theme.surfaceOpacity : 0.75;
                    }
                } catch (e) {
                    console.log("Failed to parse config: " + e);
                }
            }
        }
    }

    // Save settings directly to ~/.config/fluent-flyout/config.json
    function saveSettings() {
        var cfg = {
            "$schema": "https://json-schema.org/draft/2020-12/schema",
            "version": "1.0.0",
            "theme": {
                "variant": "dark-zinc",
                "surfaceColor": "#09090b",
                "surfaceOpacity": Math.round(settingsWindow.surfaceOpacity * 100) / 100,
                "blurRadius": 32,
                "borderColor": "rgba(255, 255, 255, 0.12)",
                "borderWidth": 1,
                "cornerRadius": 16,
                "accentColor": "#fafafa"
            },
            "modules": {
                "taskbarCapsule": {
                    "enabled": true,
                    "hideWhenEmpty": settingsWindow.capsuleAutoHide,
                    "maxCapsuleWidth": Math.round(settingsWindow.capsuleWidth),
                    "compactHeight": 32
                },
                "mediaFlyout": {
                    "enabled": settingsWindow.mediaFlyoutEnabled,
                    "autoPopupOnTrackChange": settingsWindow.autoPopupEnabled,
                    "autoHideTimeoutMs": Math.round(settingsWindow.timeoutMs),
                    "popupWidth": 380,
                    "popupHeight": 170
                },
                "osdEngine": {
                    "enabled": settingsWindow.osdEnabled,
                    "timeoutMs": 2000,
                    "showLockKeys": true,
                    "showVolume": true,
                    "showBacklight": true
                }
            }
        };

        var jsonStr = JSON.stringify(cfg, null, 2);
        saveProcess.execScript = "mkdir -p ~/.config/fluent-flyout && cat << 'EOF' > ~/.config/fluent-flyout/config.json\n" + jsonStr + "\nEOF\n";
        saveProcess.running = true;
    }

    Process {
        id: saveProcess
        property string execScript: ""
        command: ["sh", "-c", execScript]
        onExited: {
            settingsWindow.statusText = "Settings successfully synchronized.";
            clearStatusTimer.restart();
        }
    }

    Timer {
        id: clearStatusTimer
        interval: 3000
        repeat: false
        onTriggered: settingsWindow.statusText = ""
    }

    Component.onCompleted: {
        loadProcess.running = true;
    }

    // Main Card Frame (shadcn Dark Zinc #09090b @ 0.92, 16px corner radius, specular border)
    Rectangle {
        anchors.fill: parent
        radius: 16
        color: Qt.rgba(9 / 255, 9 / 255, 11 / 255, 0.92)
        border.color: Qt.rgba(1.0, 1.0, 1.0, 0.12)
        border.width: 1
        clip: true

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 14

            // Header Section
            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Rectangle {
                    width: 36
                    height: 36
                    radius: 10
                    color: Qt.rgba(56 / 255, 189 / 255, 248 / 255, 0.18)
                    border.color: Qt.rgba(56 / 255, 189 / 255, 248 / 255, 0.40)
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "󰒓"
                        font.pixelSize: 18
                        color: "#38bdf8"
                    }
                }

                ColumnLayout {
                    spacing: 2
                    Text {
                        text: "Fluent Flyout Manager"
                        font.family: "Geist"
                        font.pixelSize: 16
                        font.weight: Font.Bold
                        color: "#fafafa"
                    }
                    Text {
                        text: "Native Wayland Flyouts Configuration Suite"
                        font.family: "Geist"
                        font.pixelSize: 11
                        color: "#a1a1aa"
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Qt.rgba(1.0, 1.0, 1.0, 0.08)
            }

            // Toggles Group
            Text {
                text: "MODULES & BEHAVIOR"
                font.family: "Geist"
                font.pixelSize: 10
                font.weight: Font.Bold
                color: "#71717a"
            }

            // Toggle 1: Media Flyout
            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: "Enable Media Flyout"
                    font.family: "Geist"
                    font.pixelSize: 13
                    color: "#fafafa"
                    Layout.fillWidth: true
                }
                Switch {
                    checked: settingsWindow.mediaFlyoutEnabled
                    onToggled: settingsWindow.mediaFlyoutEnabled = checked
                }
            }

            // Toggle 2: Auto-Popup on Track Change
            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: "Auto-Popup on Track Transition"
                    font.family: "Geist"
                    font.pixelSize: 13
                    color: "#fafafa"
                    Layout.fillWidth: true
                }
                Switch {
                    checked: settingsWindow.autoPopupEnabled
                    onToggled: settingsWindow.autoPopupEnabled = checked
                }
            }

            // Toggle 3: Lock-Keys OSD
            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: "Lock-Keys & System OSD"
                    font.family: "Geist"
                    font.pixelSize: 13
                    color: "#fafafa"
                    Layout.fillWidth: true
                }
                Switch {
                    checked: settingsWindow.osdEnabled
                    onToggled: settingsWindow.osdEnabled = checked
                }
            }

            // Toggle 4: Taskbar Capsule Auto-Hide
            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: "Auto-Hide Capsule when Idle"
                    font.family: "Geist"
                    font.pixelSize: 13
                    color: "#fafafa"
                    Layout.fillWidth: true
                }
                Switch {
                    checked: settingsWindow.capsuleAutoHide
                    onToggled: settingsWindow.capsuleAutoHide = checked
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Qt.rgba(1.0, 1.0, 1.0, 0.08)
            }

            // Sliders Group
            Text {
                text: "GEOMETRY & TIMINGS"
                font.family: "Geist"
                font.pixelSize: 10
                font.weight: Font.Bold
                color: "#71717a"
            }

            // Slider 1: Dismiss Timeout
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: "Flyout Dismiss Timeout"
                        font.family: "Geist"
                        font.pixelSize: 12
                        color: "#fafafa"
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: Math.round(settingsWindow.timeoutMs) + " ms"
                        font.family: "GeistMono Nerd Font"
                        font.pixelSize: 11
                        color: "#38bdf8"
                    }
                }
                Slider {
                    Layout.fillWidth: true
                    from: 1500
                    to: 8000
                    stepSize: 250
                    value: settingsWindow.timeoutMs
                    onMoved: settingsWindow.timeoutMs = value
                }
            }

            // Slider 2: Surface Opacity
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: "Liquid Glass Opacity"
                        font.family: "Geist"
                        font.pixelSize: 12
                        color: "#fafafa"
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: Math.round(settingsWindow.surfaceOpacity * 100) + " %"
                        font.family: "GeistMono Nerd Font"
                        font.pixelSize: 11
                        color: "#38bdf8"
                    }
                }
                Slider {
                    Layout.fillWidth: true
                    from: 0.50
                    to: 0.95
                    stepSize: 0.05
                    value: settingsWindow.surfaceOpacity
                    onMoved: settingsWindow.surfaceOpacity = value
                }
            }

            // Slider 3: Capsule Max Width
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: "Taskbar Capsule Width"
                        font.family: "Geist"
                        font.pixelSize: 12
                        color: "#fafafa"
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: Math.round(settingsWindow.capsuleWidth) + " px"
                        font.family: "GeistMono Nerd Font"
                        font.pixelSize: 11
                        color: "#38bdf8"
                    }
                }
                Slider {
                    Layout.fillWidth: true
                    from: 180
                    to: 360
                    stepSize: 10
                    value: settingsWindow.capsuleWidth
                    onMoved: settingsWindow.capsuleWidth = value
                }
            }

            Item { Layout.fillHeight: true }

            // Footer Actions & Status
            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Text {
                    text: settingsWindow.statusText
                    font.family: "Geist"
                    font.pixelSize: 11
                    color: "#4ade80"
                    visible: settingsWindow.statusText !== ""
                    Layout.fillWidth: true
                }

                Item { Layout.fillWidth: true; visible: settingsWindow.statusText === "" }

                // Save Button
                Rectangle {
                    width: 120
                    height: 32
                    radius: 8
                    color: saveMouse.containsMouse ? Qt.rgba(56 / 255, 189 / 255, 248 / 255, 0.9) : "#38bdf8"

                    Text {
                        anchors.centerIn: parent
                        text: "Save & Apply"
                        font.family: "Geist"
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                        color: "#09090b"
                    }

                    MouseArea {
                        id: saveMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: settingsWindow.saveSettings()
                    }
                }
            }
        }
    }
}
