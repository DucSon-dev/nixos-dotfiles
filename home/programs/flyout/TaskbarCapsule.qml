import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

Variants {
    id: root
    model: Quickshell.screens

    // Shared MPRIS media properties across all screen instances
    property string trackTitle: "No Media"
    property string trackArtist: ""
    property string artUrl: ""
    property string playbackStatus: "Stopped"
    property string playerName: ""

    readonly property bool isPlaying: playbackStatus === "Playing"
    readonly property bool hasMedia: trackTitle !== "" && trackTitle !== "No Media"

    // Signal to notify parent or external listeners to toggle flyout
    signal toggleFlyoutRequested()

    // Shared polling process to extract MPRIS media metadata
    Process {
        id: metadataProcess
        command: ["playerctl", "metadata", "--format", "{{xesam:title}}|||{{xesam:artist}}|||{{mpris:artUrl}}|||{{status}}|||{{playerName}}"]
        stdout: SplitParser {
            onRead: data => {
                var line = data.trim();
                if (line !== "") {
                    var parts = line.split("|||");
                    if (parts.length >= 4) {
                        var parsedTitle = parts[0].trim();
                        root.trackTitle = parsedTitle !== "" ? parsedTitle : "No Media";
                        root.trackArtist = parts[1].trim();
                        root.artUrl = parts[2].trim();
                        root.playbackStatus = parts[3].trim();
                        if (parts.length >= 5) {
                            root.playerName = parts[4].trim();
                        }
                    }
                } else {
                    root.trackTitle = "No Media";
                    root.trackArtist = "";
                    root.artUrl = "";
                    root.playbackStatus = "Stopped";
                }
            }
        }
    }

    // Periodic synchronization timer
    Timer {
        id: syncTimer
        interval: 1200
        running: true
        repeat: true
        onTriggered: {
            if (!metadataProcess.running) {
                metadataProcess.running = true;
            }
        }
    }

    Component.onCompleted: {
        metadataProcess.running = true;
    }

    // Per-Screen Dynamic Floating Media Island Delegate
    delegate: Component {
        PanelWindow {
            id: capsuleWindow
            screen: modelData

            // Layer-Shell configuration: Top layer floating island
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            exclusionMode: ExclusionMode.Ignore

            anchors {
                top: true
                right: true
            }

            margins {
                top: 42
                right: 16
            }

            color: "transparent"

            // Target Micro-Geometry Tokens: Height 32px, Radius 16px
            implicitHeight: 32
            implicitWidth: capsuleBackground.implicitWidth

            // Auto-Visibility: Visible only when media is actively playing
            opacity: (root.hasMedia && root.isPlaying) ? 1.0 : 0.0
            visible: opacity > 0.0

            Behavior on opacity {
                NumberAnimation {
                    duration: 200
                    easing.type: Easing.OutCubic
                }
            }

            // Liquid Glass Floating Island Body (#09090b @ 0.85 opacity, 16px radius)
            Rectangle {
                id: capsuleBackground
                anchors.fill: parent
                implicitHeight: 32
                implicitWidth: contentLayout.implicitWidth + 20
                radius: 16
                color: Qt.rgba(9 / 255, 9 / 255, 11 / 255, 0.85)
                border.color: Qt.rgba(1.0, 1.0, 1.0, 0.12)
                border.width: 1
                clip: true

                // Click action dispatches toggle trigger to /tmp/fluent_flyout_trigger
                MouseArea {
                    id: capsuleClickArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.toggleFlyoutRequested();
                        Quickshell.execDetached(["sh", "-c", "echo $(($(cat /tmp/fluent_flyout_trigger 2>/dev/null || echo 0)+1)) > /tmp/fluent_flyout_trigger"]);
                    }
                }

                RowLayout {
                    id: contentLayout
                    anchors.centerIn: parent
                    spacing: 6

                    // Album Artwork Thumbnail (22x22px, 4px border radius)
                    Rectangle {
                        width: 22
                        height: 22
                        radius: 4
                        color: Qt.rgba(24 / 255, 24 / 255, 27 / 255, 0.85)
                        border.color: Qt.rgba(1.0, 1.0, 1.0, 0.15)
                        border.width: 1
                        clip: true
                        Layout.alignment: Qt.AlignVCenter

                        Image {
                            anchors.fill: parent
                            source: root.artUrl
                            fillMode: Image.PreserveAspectCrop
                            visible: root.artUrl !== ""
                            smooth: true
                        }

                        Text {
                            anchors.centerIn: parent
                            text: "󰎆"
                            color: root.isPlaying ? "#38bdf8" : "#71717a"
                            font.pixelSize: 11
                            visible: root.artUrl === ""
                        }
                    }

                    // Two-Line Stacked Typography (Title 10px bold, Artist 9px muted)
                    ColumnLayout {
                        spacing: 0
                        Layout.alignment: Qt.AlignVCenter
                        Layout.maximumWidth: 100

                        // Line 1: Track Title (Geist Bold 10px, truncated)
                        Text {
                            Layout.fillWidth: true
                            Layout.maximumWidth: 100
                            text: root.trackTitle
                            font.family: "Geist"
                            font.pixelSize: 10
                            font.weight: Font.Bold
                            color: "#fafafa"
                            elide: Text.ElideRight
                            maximumLineCount: 1
                        }

                        // Line 2: Artist Name (Geist Regular 9px, #a1a1aa)
                        Text {
                            Layout.fillWidth: true
                            Layout.maximumWidth: 100
                            text: root.trackArtist !== "" ? root.trackArtist : root.playerName
                            font.family: "Geist"
                            font.pixelSize: 9
                            color: "#a1a1aa"
                            elide: Text.ElideRight
                            maximumLineCount: 1
                            visible: root.trackArtist !== "" || root.playerName !== ""
                        }
                    }

                    // Inline Playback Controls (Previous, Play/Pause, Next)
                    RowLayout {
                        id: controlsRow
                        spacing: 2
                        Layout.alignment: Qt.AlignVCenter

                        // Previous Button (20x20px, icon 10px)
                        Rectangle {
                            width: 20
                            height: 20
                            radius: 10
                            color: prevMouse.containsMouse ? Qt.rgba(1.0, 1.0, 1.0, 0.18) : "transparent"

                            Text {
                                anchors.centerIn: parent
                                text: "󰒮"
                                font.pixelSize: 10
                                color: "#fafafa"
                            }

                            MouseArea {
                                id: prevMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    Quickshell.execDetached(["playerctl", "previous"]);
                                    metadataProcess.running = true;
                                }
                            }
                        }

                        // Play / Pause Toggle Button (20x20px, icon 10px)
                        Rectangle {
                            width: 20
                            height: 20
                            radius: 10
                            color: playMouse.containsMouse ? Qt.rgba(56 / 255, 189 / 255, 248 / 255, 0.35) : Qt.rgba(1.0, 1.0, 1.0, 0.12)
                            border.color: root.isPlaying ? Qt.rgba(56 / 255, 189 / 255, 248 / 255, 0.5) : "transparent"
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                text: root.isPlaying ? "󰏤" : "󰐊"
                                font.pixelSize: 10
                                color: root.isPlaying ? "#38bdf8" : "#fafafa"
                            }

                            MouseArea {
                                id: playMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    Quickshell.execDetached(["playerctl", "play-pause"]);
                                    metadataProcess.running = true;
                                }
                            }
                        }

                        // Next Button (20x20px, icon 10px)
                        Rectangle {
                            width: 20
                            height: 20
                            radius: 10
                            color: nextMouse.containsMouse ? Qt.rgba(1.0, 1.0, 1.0, 0.18) : "transparent"

                            Text {
                                anchors.centerIn: parent
                                text: "󰒭"
                                font.pixelSize: 10
                                color: "#fafafa"
                            }

                            MouseArea {
                                id: nextMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    Quickshell.execDetached(["playerctl", "next"]);
                                    metadataProcess.running = true;
                                }
                            }
                        }
                    }

                    // 4-Bar Dynamic Audio Wave Spectrum Visualizer
                    Row {
                        id: visualizerRow
                        spacing: 2
                        Layout.alignment: Qt.AlignVCenter
                        visible: root.isPlaying

                        Repeater {
                            model: 4

                            Rectangle {
                                id: waveBar
                                width: 2
                                radius: 1
                                color: "#38bdf8"
                                anchors.verticalCenter: parent.verticalCenter

                                property real phase: index * 0.7
                                property real baseHeight: 3
                                property real maxHeight: 12

                                height: root.isPlaying ? baseHeight : 2

                                SequentialAnimation on height {
                                    id: pulseAnim
                                    running: root.isPlaying
                                    loops: Animation.Infinite

                                    NumberAnimation {
                                        to: waveBar.maxHeight - (index % 2 === 0 ? 0 : 3)
                                        duration: 280 + index * 80
                                        easing.type: Easing.InOutSine
                                    }
                                    NumberAnimation {
                                        to: waveBar.baseHeight + (index % 3 === 0 ? 2 : 0)
                                        duration: 320 + index * 60
                                        easing.type: Easing.InOutSine
                                    }
                                }

                                Behavior on height {
                                    enabled: !root.isPlaying
                                    NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
