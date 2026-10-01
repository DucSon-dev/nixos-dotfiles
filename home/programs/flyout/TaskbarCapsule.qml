import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io

Rectangle {
    id: root

    // Capsule sizing standards
    implicitHeight: 32
    implicitWidth: Math.min(260, contentRow.implicitWidth + 24)
    radius: 9999

    // shadcn Dark Zinc #09090b + Apple Liquid Glass specular border
    color: Qt.rgba(9 / 255, 9 / 255, 11 / 255, 0.72)
    border.color: Qt.rgba(1.0, 1.0, 1.0, 0.12)
    border.width: 1

    // Internal state properties
    property string songTitle: "No media playing"
    property string songArtist: ""
    property string playbackStatus: "Stopped"
    property bool isPlaying: playbackStatus === "Playing"

    // Continuous metadata poller via playerctl stream
    Process {
        id: mprisWatcher
        command: [
            "playerctl", "--follow", "metadata",
            "--format", "{{status}}:::{{xesam:title}}:::{{xesam:artist}}"
        ]
        running: true

        stdout: SplitParser {
            onRead: data => {
                let line = data.trim();
                if (!line) return;
                let parts = line.split(":::");
                if (parts.length >= 3) {
                    root.playbackStatus = parts[0] ? parts[0] : "Stopped";
                    root.songTitle = parts[1] ? parts[1] : "Unknown Title";
                    root.songArtist = parts[2] ? parts[2] : "";
                }
            }
        }
    }

    RowLayout {
        id: contentRow
        anchors.centerIn: parent
        spacing: 8

        // Spinning Disc / Vinyl Record Icon
        Rectangle {
            id: discIconWrapper
            width: 20
            height: 20
            radius: 10
            color: Qt.rgba(24 / 255, 24 / 255, 27 / 255, 0.85)
            border.color: Qt.rgba(1.0, 1.0, 1.0, 0.18)
            border.width: 1

            Text {
                id: discSymbol
                anchors.centerIn: parent
                text: "󰎆"
                color: root.isPlaying ? "#fafafa" : "#71717a"
                font.pixelSize: 11
            }

            RotationAnimator {
                target: discIconWrapper
                from: 0
                to: 360
                duration: 6000
                loops: Animation.Infinite
                running: root.isPlaying
            }
        }

        // Marquee Text Container
        Item {
            id: textContainer
            implicitWidth: 110
            implicitHeight: 18
            clip: true

            readonly property string fullLabel: root.songArtist !== "" 
                ? (root.songTitle + " • " + root.songArtist) 
                : root.songTitle

            Text {
                id: labelPrimary
                y: (parent.height - contentHeight) / 2
                text: textContainer.fullLabel
                font.family: "Geist"
                font.pixelSize: 11
                font.weight: Font.Medium
                color: "#fafafa"

                // Marquee Animation Loop
                NumberAnimation on x {
                    id: marqueeAnim
                    running: labelPrimary.implicitWidth > textContainer.implicitWidth && root.isPlaying
                    loops: Animation.Infinite
                    from: 0
                    to: -(labelPrimary.implicitWidth + 24)
                    duration: Math.max(3000, labelPrimary.implicitWidth * 35)
                }
            }

            Text {
                id: labelSecondary
                y: (parent.height - contentHeight) / 2
                x: labelPrimary.x + labelPrimary.implicitWidth + 24
                text: textContainer.fullLabel
                font.family: "Geist"
                font.pixelSize: 11
                font.weight: Font.Medium
                color: "#fafafa"
                visible: marqueeAnim.running
            }
        }

        // Mini Media Controls
        RowLayout {
            spacing: 2

            // Previous Button
            Rectangle {
                width: 20
                height: 20
                radius: 10
                color: prevMouse.containsMouse ? Qt.rgba(255, 255, 255, 0.15) : "transparent"

                Text {
                    anchors.centerIn: parent
                    text: "󰒮"
                    font.pixelSize: 10
                    color: prevMouse.containsMouse ? "#fafafa" : "#a1a1aa"
                }

                MouseArea {
                    id: prevMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Quickshell.execDetached(["playerctl", "previous"])
                }
            }

            // Play / Pause Toggle Button
            Rectangle {
                width: 20
                height: 20
                radius: 10
                color: playMouse.containsMouse ? Qt.rgba(255, 255, 255, 0.20) : Qt.rgba(255, 255, 255, 0.08)

                Text {
                    anchors.centerIn: parent
                    text: root.isPlaying ? "󰏤" : "󰐊"
                    font.pixelSize: 11
                    color: "#fafafa"
                }

                MouseArea {
                    id: playMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Quickshell.execDetached(["playerctl", "play-pause"])
                }
            }

            // Next Button
            Rectangle {
                width: 20
                height: 20
                radius: 10
                color: nextMouse.containsMouse ? Qt.rgba(255, 255, 255, 0.15) : "transparent"

                Text {
                    anchors.centerIn: parent
                    text: "󰒭"
                    font.pixelSize: 10
                    color: nextMouse.containsMouse ? "#fafafa" : "#a1a1aa"
                }

                MouseArea {
                    id: nextMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Quickshell.execDetached(["playerctl", "next"])
                }
            }
        }
    }
}
