import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

PanelWindow {
    id: flyoutWindow

    // Window configuration
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore

    anchors {
        top: true
        right: true
    }

    margins {
        top: 52
        right: 180
    }

    implicitWidth: 320
    implicitHeight: 102
    color: "transparent"
    visible: false

    // Player state management via playerctl for global synchronization
    property string trackTitle: ""
    property string trackArtist: ""
    property string artUrl: ""
    property string playbackStatus: "Stopped"
    property real positionVal: 0
    property real lengthVal: 1
    property bool canGoNext: true
    property bool canGoPrev: true
    property string playerName: "Media"

    // Auto-hide timer
    Timer {
        id: autoHideTimer
        interval: 3500
        repeat: false
        onTriggered: flyoutWindow.visible = false
    }

    function triggerAutoFlyout() {
        flyoutWindow.visible = true;
        autoHideTimer.restart();
    }

    // Polling MPRIS status
    Process {
        id: statusProcess
        command: ["playerctl", "metadata", "--format", "{{xesam:title}}|||{{xesam:artist}}|||{{mpris:artUrl}}|||{{status}}|||{{playerName}}"]
        stdout: SplitParser {
            split: "\n"
            onRead: data => {
                if (data.trim() !== "") {
                    var parts = data.split("|||");
                    if (parts.length >= 5) {
                        var newTitle = parts[0].trim();
                        if (newTitle !== "" && newTitle !== flyoutWindow.trackTitle && flyoutWindow.trackTitle !== "") {
                            flyoutWindow.triggerAutoFlyout();
                        }
                        flyoutWindow.trackTitle = newTitle;
                        flyoutWindow.trackArtist = parts[1].trim();
                        flyoutWindow.artUrl = parts[2].trim();
                        flyoutWindow.playbackStatus = parts[3].trim();
                        flyoutWindow.playerName = parts[4].trim();
                    }
                }
            }
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: statusProcess.running = true
    }

    // IPC File Watcher for Click on Bar Capsule
    FileWatch {
        path: "/tmp/flyout_trigger"
        onFileChanged: {
            flyoutWindow.visible = !flyoutWindow.visible;
            if (flyoutWindow.visible) autoHideTimer.restart();
        }
    }

    // Card Surface
    Rectangle {
        anchors.fill: parent
        radius: 12
        color: Qt.rgba(24 / 255, 27 / 255, 32 / 255, 0.94) // Dark Zinc Fluent base
        border.color: Qt.rgba(255, 255, 255, 0.14)
        border.width: 1

        RowLayout {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 12

            // Album Artwork (64x64)
            Rectangle {
                width: 64
                height: 64
                radius: 8
                color: Qt.rgba(15 / 255, 15 / 255, 17 / 255, 0.9)
                border.color: Qt.rgba(255, 255, 255, 0.12)
                border.width: 1
                clip: true
                Layout.alignment: Qt.AlignVCenter

                Image {
                    anchors.fill: parent
                    source: flyoutWindow.artUrl
                    fillMode: Image.PreserveAspectCrop
                    visible: flyoutWindow.artUrl !== ""
                }

                Text {
                    anchors.centerIn: parent
                    text: "󰎆"
                    color: "#a1a1aa"
                    font.pixelSize: 22
                    visible: flyoutWindow.artUrl === ""
                }
            }

            // Right Column: Metadata + Controls
            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 3

                // Title
                Text {
                    Layout.fillWidth: true
                    text: flyoutWindow.trackTitle !== "" ? flyoutWindow.trackTitle : "No Media"
                    font.family: "Geist"
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                    color: "#fafafa"
                    elide: Text.ElideRight
                }

                // Artist
                Text {
                    Layout.fillWidth: true
                    text: flyoutWindow.trackArtist !== "" ? flyoutWindow.trackArtist : "Unknown Artist"
                    font.family: "Geist"
                    font.pixelSize: 10
                    color: "#a1a1aa"
                    elide: Text.ElideRight
                }

                // Mini Control Row
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    Layout.topMargin: 2

                    // Previous
                    Text {
                        text: "󰒮"
                        font.pixelSize: 13
                        color: "#d4d4d8"
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Quickshell.execDetached(["playerctl", "previous"])
                        }
                    }

                    // Play/Pause Accent Squircle
                    Rectangle {
                        width: 24
                        height: 24
                        radius: 6
                        color: "#38bdf8" // Accent Sky Blue

                        Text {
                            anchors.centerIn: parent
                            text: flyoutWindow.playbackStatus === "Playing" ? "󰏤" : "󰐊"
                            font.pixelSize: 12
                            color: "#09090b"
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Quickshell.execDetached(["playerctl", "play-pause"])
                        }
                    }

                    // Next
                    Text {
                        text: "󰒭"
                        font.pixelSize: 13
                        color: "#d4d4d8"
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Quickshell.execDetached(["playerctl", "next"])
                        }
                    }

                    Item { Layout.fillWidth: true }

                    // Source app indicator
                    RowLayout {
                        spacing: 4
                        Text {
                            text: "󰎆"
                            font.pixelSize: 10
                            color: "#38bdf8"
                        }
                        Text {
                            text: flyoutWindow.playerName
                            font.family: "Geist"
                            font.pixelSize: 9
                            color: "#71717a"
                        }
                    }
                }
            }
        }
    }
}
