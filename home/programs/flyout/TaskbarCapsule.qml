import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Modules.Bar.Extras
import qs.Services.Media
import qs.Services.UI
import qs.Widgets
import qs.Widgets.AudioSpectrum

Item {
    id: root

    property ShellScreen screen
    property string widgetId: ""
    property string section: ""
    property int sectionWidgetIndex: -1
    property int sectionWidgetsCount: 0

    readonly property string screenName: screen ? screen.name : ""
    property var widgetMetadata: BarWidgetRegistry.widgetMetadata[widgetId] ?? {}
    property var widgetSettings: {
        if (section && sectionWidgetIndex >= 0 && screenName) {
            var widgets = Settings.getBarWidgetsForScreen(screenName)[section];
            if (widgets && sectionWidgetIndex < widgets.length) {
                return widgets[sectionWidgetIndex];
            }
        }
        return {};
    }

    readonly property real capsuleHeight: Style.getCapsuleHeightForScreen(screenName)

    readonly property bool hasPlayer: MediaService.currentPlayer !== null
    readonly property bool isPlaying: MediaService.isPlaying
    readonly property string currentTitle: MediaService.trackTitle || "No media playing"
    readonly property string currentArtist: MediaService.trackArtist || ""
    readonly property string artUrl: MediaService.trackCoverUrl || ""
    readonly property bool canGoNext: MediaService.canGoNext
    readonly property bool canGoPrevious: MediaService.canGoPrevious

    // Spectrum registration for native audio visualizer
    readonly property string spectrumId: "bar:mediamini:spectrum"
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

    implicitWidth: mainCapsule.implicitWidth
    implicitHeight: capsuleHeight
    visible: hasPlayer

    Capsule {
        id: mainCapsule
        anchors.fill: parent
        Layout.alignment: Qt.AlignVCenter

        RowLayout {
            id: contentRow
            anchors.centerIn: parent
            spacing: 6

            // Static Cover Artwork
            Rectangle {
                width: 18
                height: 18
                radius: 3
                color: Qt.rgba(24 / 255, 24 / 255, 27 / 255, 0.85)
                border.color: Qt.rgba(1.0, 1.0, 1.0, 0.18)
                border.width: 1
                clip: true
                Layout.alignment: Qt.AlignVCenter

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
                    font.pixelSize: 10
                    visible: root.artUrl === ""
                }
            }

            // Marquee Container (Title & Artist)
            Item {
                id: textContainer
                implicitWidth: 95
                implicitHeight: 14
                clip: true
                Layout.alignment: Qt.AlignVCenter

                readonly property string fullLabel: root.currentArtist !== ""
                    ? (root.currentTitle + " • " + root.currentArtist)
                    : root.currentTitle

                Text {
                    id: primaryLabel
                    y: (parent.height - contentHeight) / 2
                    text: textContainer.fullLabel
                    font.family: "Geist"
                    font.pixelSize: 10
                    font.weight: Font.Medium
                    color: "#fafafa"

                    NumberAnimation on x {
                        id: marqueeAnim
                        running: primaryLabel.implicitWidth > textContainer.implicitWidth && root.isPlaying
                        loops: Animation.Infinite
                        from: 0
                        to: -(primaryLabel.implicitWidth + 18)
                        duration: Math.max(3000, primaryLabel.implicitWidth * 35)
                    }
                }

                Text {
                    id: secondaryLabel
                    y: (parent.height - contentHeight) / 2
                    x: primaryLabel.x + primaryLabel.implicitWidth + 18
                    text: textContainer.fullLabel
                    font.family: "Geist"
                    font.pixelSize: 10
                    font.weight: Font.Medium
                    color: "#fafafa"
                    visible: marqueeAnim.running
                }
            }

            // Navigation Controls
            RowLayout {
                spacing: 2
                Layout.alignment: Qt.AlignVCenter

                // Previous Button
                Rectangle {
                    width: 16
                    height: 16
                    radius: 8
                    opacity: root.canGoPrevious ? 1.0 : 0.28
                    color: (root.canGoPrevious && prevArea.containsMouse) ? Qt.rgba(255, 255, 255, 0.15) : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: "󰒮"
                        font.pixelSize: 9
                        color: root.canGoPrevious ? (prevArea.containsMouse ? "#fafafa" : "#d4d4d8") : "#71717a"
                    }

                    MouseArea {
                        id: prevArea
                        anchors.fill: parent
                        hoverEnabled: root.canGoPrevious
                        cursorShape: root.canGoPrevious ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: MediaService.previous()
                    }
                }

                // Play / Pause Toggle Button
                Rectangle {
                    width: 16
                    height: 16
                    radius: 8
                    color: playArea.containsMouse ? Qt.rgba(255, 255, 255, 0.20) : Qt.rgba(255, 255, 255, 0.08)

                    Text {
                        anchors.centerIn: parent
                        text: root.isPlaying ? "󰏤" : "󰐊"
                        font.pixelSize: 9
                        color: "#fafafa"
                    }

                    MouseArea {
                        id: playArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: MediaService.playPause()
                    }
                }

                // Next Button
                Rectangle {
                    width: 16
                    height: 16
                    radius: 8
                    opacity: root.canGoNext ? 1.0 : 0.28
                    color: (root.canGoNext && nextArea.containsMouse) ? Qt.rgba(255, 255, 255, 0.15) : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: "󰒭"
                        font.pixelSize: 9
                        color: root.canGoNext ? (nextArea.containsMouse ? "#fafafa" : "#d4d4d8") : "#71717a"
                    }

                    MouseArea {
                        id: nextArea
                        anchors.fill: parent
                        hoverEnabled: root.canGoNext
                        cursorShape: root.canGoNext ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: MediaService.next()
                    }
                }
            }

            // Waveform Audio Spectrum
            AudioSpectrum {
                implicitWidth: 38
                implicitHeight: 14
                barCount: 8
                barSpacing: 2
                barRadius: 1
                barColor: Qt.rgba(250 / 255, 250 / 255, 250 / 255, 0.85)
                active: root.isPlaying
                Layout.alignment: Qt.AlignVCenter
            }
        }
    }
}
