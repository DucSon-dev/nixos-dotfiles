import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

Scope {
    id: rootScope

    // Shared Reactive State
    property string songTitle: "No media playing"
    property string songArtist: ""
    property string playbackStatus: "Stopped"
    property string artUrl: ""
    property string playerName: "Media"
    readonly property bool isPlaying: playbackStatus === "Playing"
    property bool popupVisible: false

    // Auto-hide timer when track changes
    Timer {
        id: autoHideTimer
        interval: 4000
        repeat: false
        onTriggered: rootScope.popupVisible = false
    }

    // MPRIS continuous stream poller
    Process {
        id: mprisWatcher
        command: [
            "playerctl", "--follow", "metadata",
            "--format", "{{status}}:::{{xesam:title}}:::{{xesam:artist}}:::{{mpris:artUrl}}:::{{playerName}}"
        ]
        running: true

        stdout: SplitParser {
            onRead: data => {
                let line = data.trim();
                if (!line) return;
                let parts = line.split(":::");
                if (parts.length >= 3) {
                    let oldTitle = rootScope.songTitle;
                    rootScope.playbackStatus = parts[0] ? parts[0] : "Stopped";
                    rootScope.songTitle = parts[1] ? parts[1] : "Unknown Title";
                    rootScope.songArtist = parts[2] ? parts[2] : "";
                    rootScope.artUrl = (parts.length >= 4 && parts[3]) ? parts[3] : "";
                    rootScope.playerName = (parts.length >= 5 && parts[4]) ? parts[4] : "Media Player";

                    // Auto-pop on song change if song actually changed
                    if (oldTitle !== rootScope.songTitle && rootScope.songTitle !== "No media playing") {
                        rootScope.popupVisible = true;
                        autoHideTimer.restart();
                    }
                }
            }
        }
    }

    // ==========================================
    // 1. Taskbar Capsule Widget (Windows 11 Pill)
    // ==========================================
    PanelWindow {
        id: capsuleWindow

        anchors {
            top: true
            right: true
        }

        margins {
            top: 10
            right: 320 // Aligned flush before the right tray items
        }

        // Overlay on top of the bar, ignore compositor exclusion zone
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "noctalia-flyout-capsule"
        exclusionMode: ExclusionMode.Ignore

        color: "transparent"
        implicitHeight: 32
        implicitWidth: capsulePill.implicitWidth

        Rectangle {
            id: capsulePill
            implicitHeight: 30
            implicitWidth: contentRow.implicitWidth + 20
            radius: 9999

            // shadcn Dark Zinc #09090b + Specular liquid glass rim
            color: Qt.rgba(9 / 255, 9 / 255, 11 / 255, 0.88)
            border.color: Qt.rgba(1.0, 1.0, 1.0, 0.12)
            border.width: 1

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    rootScope.popupVisible = !rootScope.popupVisible;
                    if (rootScope.popupVisible) autoHideTimer.restart();
                }
            }

            RowLayout {
                id: contentRow
                anchors.centerIn: parent
                spacing: 8

                // Static Cover Art (No rotation)
                Rectangle {
                    width: 22
                    height: 22
                    radius: 4
                    color: Qt.rgba(24 / 255, 24 / 255, 27 / 255, 0.85)
                    border.color: Qt.rgba(1.0, 1.0, 1.0, 0.18)
                    border.width: 1
                    clip: true
                    Layout.alignment: Qt.AlignVCenter

                    Image {
                        anchors.fill: parent
                        source: rootScope.artUrl
                        fillMode: Image.PreserveAspectCrop
                        visible: rootScope.artUrl !== ""
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "󰎆"
                        color: rootScope.isPlaying ? "#fafafa" : "#71717a"
                        font.pixelSize: 11
                        visible: rootScope.artUrl === ""
                    }
                }

                // Marquee Text: Title & Artist
                Item {
                    id: textContainer
                    implicitWidth: 105
                    implicitHeight: 18
                    clip: true
                    Layout.alignment: Qt.AlignVCenter

                    readonly property string fullLabel: rootScope.songArtist !== ""
                        ? (rootScope.songTitle + " • " + rootScope.songArtist)
                        : rootScope.songTitle

                    Text {
                        id: primaryLabel
                        y: (parent.height - contentHeight) / 2
                        text: textContainer.fullLabel
                        font.family: "Geist"
                        font.pixelSize: 11
                        font.weight: Font.Medium
                        color: "#fafafa"

                        NumberAnimation on x {
                            id: marqueeAnim
                            running: primaryLabel.implicitWidth > textContainer.implicitWidth && rootScope.isPlaying
                            loops: Animation.Infinite
                            from: 0
                            to: -(primaryLabel.implicitWidth + 24)
                            duration: Math.max(3000, primaryLabel.implicitWidth * 35)
                        }
                    }

                    Text {
                        id: secondaryLabel
                        y: (parent.height - contentHeight) / 2
                        x: primaryLabel.x + primaryLabel.implicitWidth + 24
                        text: textContainer.fullLabel
                        font.family: "Geist"
                        font.pixelSize: 11
                        font.weight: Font.Medium
                        color: "#fafafa"
                        visible: marqueeAnim.running
                    }
                }

                // Mini Playback Controls: Previous, Play/Pause, Next
                RowLayout {
                    spacing: 2
                    Layout.alignment: Qt.AlignVCenter

                    Rectangle {
                        width: 20
                        height: 20
                        radius: 10
                        color: prevArea.containsMouse ? Qt.rgba(255, 255, 255, 0.15) : "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: "󰒮"
                            font.pixelSize: 10
                            color: prevArea.containsMouse ? "#fafafa" : "#a1a1aa"
                        }

                        MouseArea {
                            id: prevArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Quickshell.execDetached(["playerctl", "previous"])
                        }
                    }

                    Rectangle {
                        width: 20
                        height: 20
                        radius: 10
                        color: playArea.containsMouse ? Qt.rgba(255, 255, 255, 0.20) : Qt.rgba(255, 255, 255, 0.08)

                        Text {
                            anchors.centerIn: parent
                            text: rootScope.isPlaying ? "󰏤" : "󰐊"
                            font.pixelSize: 11
                            color: "#fafafa"
                        }

                        MouseArea {
                            id: playArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Quickshell.execDetached(["playerctl", "play-pause"])
                        }
                    }

                    Rectangle {
                        width: 20
                        height: 20
                        radius: 10
                        color: nextArea.containsMouse ? Qt.rgba(255, 255, 255, 0.15) : "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: "󰒭"
                            font.pixelSize: 10
                            color: nextArea.containsMouse ? "#fafafa" : "#a1a1aa"
                        }

                        MouseArea {
                            id: nextArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Quickshell.execDetached(["playerctl", "next"])
                        }
                    }
                }

                // Audio Waveform Visualizer Bars
                Row {
                    id: waveformRow
                    spacing: 2
                    Layout.alignment: Qt.AlignVCenter

                    Repeater {
                        model: [10, 16, 8, 14, 18, 12, 16, 9]
                        Rectangle {
                            width: 2
                            height: rootScope.isPlaying ? modelData : 4
                            radius: 1
                            color: Qt.rgba(250 / 255, 250 / 255, 250 / 255, 0.85)
                            anchors.verticalCenter: parent.verticalCenter

                            SequentialAnimation on height {
                                running: rootScope.isPlaying
                                loops: Animation.Infinite
                                NumberAnimation {
                                    from: 4
                                    to: modelData
                                    duration: 250 + (index * 60)
                                    easing.type: Easing.InOutQuad
                                }
                                NumberAnimation {
                                    from: modelData
                                    to: 4
                                    duration: 250 + (index * 60)
                                    easing.type: Easing.InOutQuad
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // ==========================================
    // 2. Rectangular Popup Card (Image 1 Style)
    // ==========================================
    PanelWindow {
        id: cardWindow
        visible: rootScope.popupVisible

        anchors {
            top: true
            right: true
        }

        margins {
            top: 48 // Floats directly below the taskbar
            right: 300
        }

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "noctalia-flyout-card"
        exclusionMode: ExclusionMode.Ignore

        color: "transparent"
        implicitWidth: 320
        implicitHeight: 110

        Rectangle {
            anchors.fill: parent
            radius: 14
            color: Qt.rgba(18 / 255, 18 / 255, 22 / 255, 0.94)
            border.color: Qt.rgba(1.0, 1.0, 1.0, 0.14)
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 14

                // Large Square Album Art
                Rectangle {
                    width: 78
                    height: 78
                    radius: 8
                    color: Qt.rgba(28 / 255, 28 / 255, 32 / 255, 0.8)
                    border.color: Qt.rgba(1.0, 1.0, 1.0, 0.12)
                    border.width: 1
                    clip: true
                    Layout.alignment: Qt.AlignVCenter

                    Image {
                        anchors.fill: parent
                        source: rootScope.artUrl
                        fillMode: Image.PreserveAspectCrop
                        visible: rootScope.artUrl !== ""
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "󰎆"
                        font.pixelSize: 28
                        color: "#71717a"
                        visible: rootScope.artUrl === ""
                    }
                }

                // Info & Controls Column
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 4

                    Text {
                        text: rootScope.songTitle
                        font.family: "Geist"
                        font.pixelSize: 13
                        font.weight: Font.Bold
                        color: "#ffffff"
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                    Text {
                        text: rootScope.songArtist !== "" ? rootScope.songArtist : "Unknown Artist"
                        font.family: "Geist"
                        font.pixelSize: 11
                        font.weight: Font.Medium
                        color: "#a1a1aa"
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                    Item { implicitHeight: 4 }

                    // Card Control Buttons
                    RowLayout {
                        spacing: 12

                        // Prev Button
                        Text {
                            text: "󰒮"
                            font.pixelSize: 14
                            color: cardPrevArea.containsMouse ? "#ffffff" : "#a1a1aa"
                            MouseArea {
                                id: cardPrevArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    Quickshell.execDetached(["playerctl", "previous"]);
                                    autoHideTimer.restart();
                                }
                            }
                        }

                        // Prominent Rounded Play/Pause Button
                        Rectangle {
                            width: 32
                            height: 26
                            radius: 6
                            color: rootScope.isPlaying ? "#38bdf8" : Qt.rgba(255, 255, 255, 0.15)

                            Text {
                                anchors.centerIn: parent
                                text: rootScope.isPlaying ? "󰏤" : "󰐊"
                                font.pixelSize: 13
                                color: rootScope.isPlaying ? "#09090b" : "#ffffff"
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    Quickshell.execDetached(["playerctl", "play-pause"]);
                                    autoHideTimer.restart();
                                }
                            }
                        }

                        // Next Button
                        Text {
                            text: "󰒭"
                            font.pixelSize: 14
                            color: cardNextArea.containsMouse ? "#ffffff" : "#a1a1aa"
                            MouseArea {
                                id: cardNextArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    Quickshell.execDetached(["playerctl", "next"]);
                                    autoHideTimer.restart();
                                }
                            }
                        }

                        // Player Source Label
                        RowLayout {
                            spacing: 4
                            Layout.leftMargin: 10

                            Text {
                                text: "󰈹"
                                font.pixelSize: 12
                                color: "#38bdf8"
                            }

                            Text {
                                text: rootScope.playerName
                                font.family: "Geist"
                                font.pixelSize: 10
                                color: "#71717a"
                            }
                        }
                    }
                }
            }
        }
    }
}
