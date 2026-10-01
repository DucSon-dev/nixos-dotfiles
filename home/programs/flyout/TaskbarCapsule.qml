import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import qs.Commons
import qs.Services.Media
import qs.Widgets.AudioSpectrum

Rectangle {
    id: root

    // Standard capsule height
    implicitHeight: Math.max(30, Math.min(34, Style.getCapsuleHeightForScreen ? Style.getCapsuleHeightForScreen("") : 32))
    implicitWidth: contentRow.implicitWidth + 24
    radius: 9999

    // shadcn Dark Zinc #09090b + Specular liquid glass rim
    color: Qt.rgba(9 / 255, 9 / 255, 11 / 255, 0.78)
    border.color: Qt.rgba(1.0, 1.0, 1.0, 0.12)
    border.width: 1

    readonly property bool hasPlayer: MediaService.currentPlayer !== null
    readonly property bool isPlaying: MediaService.isPlaying
    readonly property string currentTitle: MediaService.trackTitle || "No media playing"
    readonly property string currentArtist: MediaService.trackArtist || ""
    readonly property string artUrl: MediaService.trackCoverUrl || ""

    // Spectrum service integration
    readonly property string spectrumId: "taskbar:capsule:spectrum"
    Component.onCompleted: {
        if (typeof SpectrumService !== "undefined") {
            SpectrumService.registerComponent(root.spectrumId);
        }
    }
    Component.onDestruction: {
        if (typeof SpectrumService !== "undefined") {
            SpectrumService.unregisterComponent(root.spectrumId);
        }
    }

    RowLayout {
        id: contentRow
        anchors.centerIn: parent
        spacing: 8

        // Cover Art / Spinning Vinyl Disc
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
                source: root.artUrl
                fillMode: Image.PreserveAspectCrop
                visible: root.artUrl !== ""
            }

            Text {
                anchors.centerIn: parent
                text: "󰎆"
                color: root.isPlaying ? "#fafafa" : "#71717a"
                font.pixelSize: 11
                visible: root.artUrl === ""
            }

            RotationAnimator {
                target: artWrapper
                from: 0
                to: 360
                duration: 6000
                loops: Animation.Infinite
                running: root.isPlaying
            }
        }

        // Title & Artist Layout (Marquee Container)
        Item {
            id: textContainer
            implicitWidth: 105
            implicitHeight: 20
            clip: true

            readonly property string fullLabel: root.currentArtist !== ""
                ? (root.currentTitle + " • " + root.currentArtist)
                : root.currentTitle

            Text {
                id: labelPrimary
                y: (parent.height - contentHeight) / 2
                text: textContainer.fullLabel
                font.family: "Geist"
                font.pixelSize: 11
                font.weight: Font.Medium
                color: "#fafafa"

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

        // Mini Playback Controls: Previous, Play/Pause, Next
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
                    onClicked: MediaService.previous()
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
                    onClicked: MediaService.playPause()
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
                    onClicked: MediaService.next()
                }
            }
        }

        // Audio Spectrum Waveform Visualizer
        AudioSpectrum {
            id: barSpectrum
            implicitWidth: 46
            implicitHeight: 16
            barCount: 10
            barSpacing: 2
            barRadius: 2
            barColor: Qt.rgba(250 / 255, 250 / 255, 250 / 255, 0.85)
            active: root.isPlaying
            visible: true
        }
    }
}
