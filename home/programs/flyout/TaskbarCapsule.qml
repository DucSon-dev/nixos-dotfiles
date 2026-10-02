import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

PanelWindow {
    id: root

    // Layer-Shell surface configuration anchored to Top-Right
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore

    anchors {
        top: true
        right: true
    }

    margins {
        top: 4
        right: 280
    }

    color: "transparent"

    // Micro-Geometry Tokens: Exactly 26px height
    implicitHeight: 26
    implicitWidth: visible ? capsuleBackground.implicitWidth : 0

    // Capsule intelligence: auto-hide when no media players are active
    property bool hideWhenEmpty: true
    visible: hideWhenEmpty ? hasMedia : true

    // Media properties
    property string trackTitle: "No Media"
    property string trackArtist: ""
    property string artUrl: ""
    property string playbackStatus: "Stopped"
    property string playerName: ""

    readonly property bool isPlaying: playbackStatus === "Playing"
    readonly property bool hasMedia: trackTitle !== "" && trackTitle !== "No Media"

    // Signal to notify parent or external listeners to toggle flyout
    signal toggleFlyoutRequested()

    // Polling process to extract MPRIS media metadata
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

    // Liquid Glass Capsule Container (Height 26px, Radius 13px pill squircle, Dark Zinc #09090b @ 0.75)
    Rectangle {
        id: capsuleBackground
        anchors.fill: parent
        implicitHeight: 26
        implicitWidth: contentLayout.implicitWidth + 16
        radius: 13
        color: Qt.rgba(9 / 255, 9 / 255, 11 / 255, 0.75)
        border.color: Qt.rgba(1.0, 1.0, 1.0, 0.12)
        border.width: 1
        clip: true

        // Non-blocking monotonic counter trigger IPC
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
            spacing: 5

            // Album Artwork Thumbnail (18x18px, 3px border radius per spec)
            Rectangle {
                width: 18
                height: 18
                radius: 3
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
                    font.pixelSize: 9
                    visible: root.artUrl === ""
                }
            }

            // Two-Line Stacked Typography (Title 10px bold, Artist 9px muted, max width 95px)
            ColumnLayout {
                spacing: 0
                Layout.alignment: Qt.AlignVCenter
                Layout.maximumWidth: 95

                // Line 1: Track Title (Geist Bold 10px, truncated)
                Text {
                    Layout.fillWidth: true
                    Layout.maximumWidth: 95
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
                    Layout.maximumWidth: 95
                    text: root.trackArtist !== "" ? root.trackArtist : root.playerName
                    font.family: "Geist"
                    font.pixelSize: 9
                    color: "#a1a1aa"
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    visible: root.trackArtist !== "" || root.playerName !== ""
                }
            }

            // Inline Playback Controls (Buttons 16x16px, Icons 8px)
            RowLayout {
                id: controlsRow
                spacing: 2
                Layout.alignment: Qt.AlignVCenter

                // Previous Button (16x16px, icon 8px)
                Rectangle {
                    width: 16
                    height: 16
                    radius: 8
                    color: prevMouse.containsMouse ? Qt.rgba(1.0, 1.0, 1.0, 0.18) : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: "󰒮"
                        font.pixelSize: 8
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

                // Play / Pause Toggle Button (16x16px, icon 8px)
                Rectangle {
                    width: 16
                    height: 16
                    radius: 8
                    color: playMouse.containsMouse ? Qt.rgba(56 / 255, 189 / 255, 248 / 255, 0.35) : Qt.rgba(1.0, 1.0, 1.0, 0.12)
                    border.color: root.isPlaying ? Qt.rgba(56 / 255, 189 / 255, 248 / 255, 0.5) : "transparent"
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: root.isPlaying ? "󰏤" : "󰐊"
                        font.pixelSize: 8
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

                // Next Button (16x16px, icon 8px)
                Rectangle {
                    width: 16
                    height: 16
                    radius: 8
                    color: nextMouse.containsMouse ? Qt.rgba(1.0, 1.0, 1.0, 0.18) : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: "󰒭"
                        font.pixelSize: 8
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

            // Dynamic Audio Wave Spectrum Visualizer (4 bars, width 2px, max 10px, min 3px)
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
                        property real maxHeight: 10

                        height: root.isPlaying ? baseHeight : 2

                        SequentialAnimation on height {
                            id: pulseAnim
                            running: root.isPlaying
                            loops: Animation.Infinite

                            NumberAnimation {
                                to: waveBar.maxHeight - (index % 2 === 0 ? 0 : 2)
                                duration: 280 + index * 80
                                easing.type: Easing.InOutSine
                            }
                            NumberAnimation {
                                to: waveBar.baseHeight + (index % 3 === 0 ? 1 : 0)
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
