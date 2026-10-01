import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

PanelWindow {
    id: capsuleWindow

    // Anchors positioning: Top Right aligned with floating bar margins
    anchors {
        top: true
        right: true
    }

    margins {
        top: 8
        right: 490 // Positioned before the tray items
    }

    // Wayland Layer Shell configuration
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "noctalia-flyout-capsule"
    
    color: "transparent"
    implicitHeight: 34
    implicitWidth: capsulePill.implicitWidth

    Rectangle {
        id: capsulePill
        implicitHeight: 32
        implicitWidth: contentRow.implicitWidth + 24
        radius: 9999

        // shadcn Dark Zinc #09090b + Specular liquid glass rim
        color: Qt.rgba(9 / 255, 9 / 255, 11 / 255, 0.88)
        border.color: Qt.rgba(1.0, 1.0, 1.0, 0.12)
        border.width: 1

        property string songTitle: "No media playing"
        property string songArtist: ""
        property string playbackStatus: "Stopped"
        property string artUrl: ""
        readonly property bool isPlaying: playbackStatus === "Playing"

        // MPRIS continuous stream poller
        Process {
            id: mprisWatcher
            command: [
                "playerctl", "--follow", "metadata",
                "--format", "{{status}}:::{{xesam:title}}:::{{xesam:artist}}:::{{mpris:artUrl}}"
            ]
            running: true

            stdout: SplitParser {
                onRead: data => {
                    let line = data.trim();
                    if (!line) return;
                    let parts = line.split(":::");
                    if (parts.length >= 3) {
                        capsulePill.playbackStatus = parts[0] ? parts[0] : "Stopped";
                        capsulePill.songTitle = parts[1] ? parts[1] : "Unknown Title";
                        capsulePill.songArtist = parts[2] ? parts[2] : "";
                        capsulePill.artUrl = (parts.length >= 4 && parts[3]) ? parts[3] : "";
                    }
                }
            }
        }

        RowLayout {
            id: contentRow
            anchors.centerIn: parent
            spacing: 8

            // Cover Art / Spinning Disc
            Rectangle {
                id: artWrapper
                width: 22
                height: 22
                radius: 11
                color: Qt.rgba(24 / 255, 24 / 255, 27 / 255, 0.85)
                border.color: Qt.rgba(1.0, 1.0, 1.0, 0.18)
                border.width: 1
                clip: true

                Image {
                    anchors.fill: parent
                    source: capsulePill.artUrl
                    fillMode: Image.PreserveAspectCrop
                    visible: capsulePill.artUrl !== ""
                }

                Text {
                    anchors.centerIn: parent
                    text: "󰎆"
                    color: capsulePill.isPlaying ? "#fafafa" : "#71717a"
                    font.pixelSize: 11
                    visible: capsulePill.artUrl === ""
                }

                RotationAnimator {
                    target: artWrapper
                    from: 0
                    to: 360
                    duration: 6000
                    loops: Animation.Infinite
                    running: capsulePill.isPlaying
                }
            }

            // Marquee Text: Title & Artist
            Item {
                id: textContainer
                implicitWidth: 105
                implicitHeight: 18
                clip: true

                readonly property string fullLabel: capsulePill.songArtist !== ""
                    ? (capsulePill.songTitle + " • " + capsulePill.songArtist)
                    : capsulePill.songTitle

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
                        running: primaryLabel.implicitWidth > textContainer.implicitWidth && capsulePill.isPlaying
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
                        text: capsulePill.isPlaying ? "󰏤" : "󰐊"
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
                anchors.verticalCenter: parent.verticalCenter

                Repeater {
                    model: [10, 16, 8, 14, 18, 12, 16, 9]
                    Rectangle {
                        id: barItem
                        width: 2
                        height: capsulePill.isPlaying ? modelData : 4
                        radius: 1
                        color: Qt.rgba(250 / 255, 250 / 255, 250 / 255, 0.85)
                        anchors.verticalCenter: parent.verticalCenter

                        SequentialAnimation on height {
                            running: capsulePill.isPlaying
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
