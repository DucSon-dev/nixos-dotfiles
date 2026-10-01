import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

Scope {
    id: root

    property string trackTitle: ""
    property string trackArtist: ""
    property string artUrl: ""
    property string playbackStatus: "Stopped"
    property string playerName: ""
    readonly property bool isPlaying: playbackStatus === "Playing"
    readonly property bool hasMedia: trackTitle !== ""

    Timer {
        id: autoFlyoutTimer
        interval: 3500
        repeat: false
        onTriggered: flyoutWindow.visible = false
    }

    function showFlyoutTemporarily() {
        flyoutWindow.visible = true;
        autoFlyoutTimer.restart();
    }

    Process {
        id: mprisProcess
        command: ["playerctl", "metadata", "--format", "{{xesam:title}}|||{{xesam:artist}}|||{{mpris:artUrl}}|||{{status}}|||{{playerName}}"]
        stdout: SplitParser {
            separator: "\n"
            onRead: data => {
                if (data.trim() !== "") {
                    var parts = data.split("|||");
                    if (parts.length >= 5) {
                        var newTitle = parts[0].trim();
                        if (newTitle !== "" && newTitle !== root.trackTitle && root.trackTitle !== "") {
                            root.showFlyoutTemporarily();
                        }
                        root.trackTitle = newTitle;
                        root.trackArtist = parts[1].trim();
                        root.artUrl = parts[2].trim();
                        root.playbackStatus = parts[3].trim();
                        root.playerName = parts[4].trim();
                    }
                } else {
                    root.trackTitle = "";
                    root.trackArtist = "";
                    root.artUrl = "";
                    root.playbackStatus = "Stopped";
                }
            }
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: mprisProcess.running = true
    }

    PanelWindow {
        id: capsuleWindow
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Ignore

        anchors {
            top: true
            right: true
        }

        margins {
            top: 10
            right: 420
        }

        implicitWidth: capsuleFrame.implicitWidth
        implicitHeight: 28
        color: "transparent"
        visible: root.hasMedia

        Rectangle {
            id: capsuleFrame
            implicitWidth: contentRow.implicitWidth + 16
            implicitHeight: 28
            radius: 14
            color: Qt.rgba(24 / 255, 24 / 255, 27 / 255, 0.88)
            border.color: Qt.rgba(255, 255, 255, 0.16)
            border.width: 1

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    flyoutWindow.visible = !flyoutWindow.visible;
                    if (flyoutWindow.visible) autoFlyoutTimer.restart();
                }
            }

            RowLayout {
                id: contentRow
                anchors.centerIn: parent
                spacing: 8

                Rectangle {
                    width: 18
                    height: 18
                    radius: 4
                    color: Qt.rgba(9 / 255, 9 / 255, 11 / 255, 0.9)
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

                Item {
                    id: textWrap
                    implicitWidth: 100
                    implicitHeight: 14
                    clip: true
                    Layout.alignment: Qt.AlignVCenter

                    readonly property string fullText: root.trackArtist !== "" ? (root.trackTitle + " • " + root.trackArtist) : root.trackTitle

                    Text {
                        id: label1
                        y: (parent.height - contentHeight) / 2
                        text: textWrap.fullText
                        font.family: "Geist"
                        font.pixelSize: 10
                        font.weight: Font.Medium
                        color: "#fafafa"

                        NumberAnimation on x {
                            running: label1.implicitWidth > textWrap.implicitWidth && root.isPlaying
                            loops: Animation.Infinite
                            from: 0
                            to: -(label1.implicitWidth + 16)
                            duration: Math.max(3000, label1.implicitWidth * 35)
                        }
                    }
                }

                Row {
                    spacing: 2
                    Layout.alignment: Qt.AlignVCenter

                    Repeater {
                        model: [7, 12, 5, 14, 9, 13, 6, 11]
                        Rectangle {
                            width: 2
                            height: root.isPlaying ? Math.max(3, modelData * (0.4 + 0.6 * Math.random())) : 3
                            radius: 1
                            color: "#38bdf8"
                            Behavior on height { NumberAnimation { duration: 180 } }
                        }
                    }
                }
            }
        }
    }

    PanelWindow {
        id: flyoutWindow
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Ignore

        anchors {
            top: true
            right: true
        }

        margins {
            top: 50
            right: 320
        }

        implicitWidth: 320
        implicitHeight: 96
        color: "transparent"
        visible: false

        Rectangle {
            anchors.fill: parent
            radius: 12
            color: Qt.rgba(24 / 255, 27 / 255, 32 / 255, 0.94)
            border.color: Qt.rgba(255, 255, 255, 0.16)
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 12

                Rectangle {
                    width: 64
                    height: 64
                    radius: 8
                    color: Qt.rgba(15 / 255, 15 / 255, 17 / 255, 0.9)
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
                        color: "#a1a1aa"
                        font.pixelSize: 22
                        visible: root.artUrl === ""
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 3

                    Text {
                        Layout.fillWidth: true
                        text: root.trackTitle !== "" ? root.trackTitle : "No Media"
                        font.family: "Geist"
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                        color: "#fafafa"
                        elide: Text.ElideRight
                    }

                    Text {
                        Layout.fillWidth: true
                        text: root.trackArtist !== "" ? root.trackArtist : "Unknown Artist"
                        font.family: "Geist"
                        font.pixelSize: 10
                        color: "#a1a1aa"
                        elide: Text.ElideRight
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10
                        Layout.topMargin: 2

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

                        Rectangle {
                            width: 24
                            height: 24
                            radius: 6
                            color: "#38bdf8"

                            Text {
                                anchors.centerIn: parent
                                text: root.isPlaying ? "󰏤" : "󰐊"
                                font.pixelSize: 12
                                color: "#09090b"
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Quickshell.execDetached(["playerctl", "play-pause"])
                            }
                        }

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

                        Text {
                            text: root.playerName.toUpperCase()
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
