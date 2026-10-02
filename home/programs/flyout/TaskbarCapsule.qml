import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Item {
    id: root

    // Component dimensions
    implicitHeight: 32
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

    // Liquid Glass Capsule Container (shadcn Dark Zinc #09090b @ 0.72 opacity, 16px radius, 1px border)
    Rectangle {
        id: capsuleBackground
        anchors.fill: parent
        implicitHeight: 32
        implicitWidth: contentLayout.implicitWidth + 24
        radius: 16
        color: Qt.rgba(9 / 255, 9 / 255, 11 / 255, 0.72)
        border.color: Qt.rgba(1.0, 1.0, 1.0, 0.12)
        border.width: 1
        clip: true

        // Click action on capsule body toggles the Media Flyout card via IPC socket & trigger file
        MouseArea {
            id: capsuleClickArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                root.toggleFlyoutRequested();
                Quickshell.execDetached(["sh", "-c", "echo toggle | nc -U /tmp/fluent_flyout.sock 2>/dev/null || touch /tmp/fluent_flyout_trigger"]);
            }
        }

        RowLayout {
            id: contentLayout
            anchors.centerIn: parent
            spacing: 8

            // Album Artwork / Music Icon Thumbnail
            Rectangle {
                width: 20
                height: 20
                radius: 6
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

            // Text Marquee Section (Track Title and Artist)
            Item {
                id: marqueeContainer
                implicitWidth: 120
                implicitHeight: 16
                clip: true
                Layout.alignment: Qt.AlignVCenter

                readonly property string displayString: root.trackArtist !== ""
                    ? (root.trackTitle + " • " + root.trackArtist)
                    : root.trackTitle

                Text {
                    id: primaryLabel
                    y: (parent.height - contentHeight) / 2
                    text: marqueeContainer.displayString
                    font.family: "Geist"
                    font.pixelSize: 11
                    font.weight: Font.Medium
                    color: "#fafafa"

                    NumberAnimation on x {
                        id: scrollAnim
                        running: primaryLabel.implicitWidth > marqueeContainer.implicitWidth && root.isPlaying
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
                    text: marqueeContainer.displayString
                    font.family: "Geist"
                    font.pixelSize: 11
                    font.weight: Font.Medium
                    color: "#fafafa"
                    visible: scrollAnim.running
                }
            }

            // Interactive Controls (Previous, Play/Pause toggle, Next)
            RowLayout {
                id: controlsRow
                spacing: 4
                Layout.alignment: Qt.AlignVCenter

                // Previous Button
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

                // Play / Pause Toggle Button
                Rectangle {
                    width: 22
                    height: 22
                    radius: 11
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

                // Next Button
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
        }
    }
}
