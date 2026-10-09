import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

// Dynamic Floating Taskbar Capsule (Liquid Glass Pill)
// Multi-head floating media capsule bound to injected StateMachine and MprisBridge.
Scope {
    id: rootScope

    // Injected foundation dependencies
    property QtObject fsm: null
    property QtObject bridge: null

    // Multi-head binding: instantiate capsule across all connected displays
    Variants {
        model: Quickshell.screens

        delegate: Component {
            PanelWindow {
                id: capsuleWindow
                required property var modelData
                screen: modelData

                // Layer-shell configuration
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
                implicitHeight: 32
                implicitWidth: capsuleBackground.implicitWidth

                // Engine Type Invariant: PanelWindow visibility must be strictly boolean governed.
                // Do NOT assign opacity or Behavior on opacity to PanelWindow directly.
                visible: rootScope.bridge && rootScope.bridge.hasMedia && (!rootScope.fsm || !rootScope.fsm.isExpanded)

                // Main Pill Squircle Container
                Rectangle {
                    id: capsuleBackground
                    anchors.fill: parent
                    radius: 16
                    implicitHeight: 32
                    implicitWidth: contentRow.implicitWidth + 18
                    color: Qt.rgba(9 / 255, 9 / 255, 11 / 255, 0.72)
                    border.color: Qt.rgba(1.0, 1.0, 1.0, 0.12)
                    border.width: 1

                    // Opacity fading transition resides strictly on internal Rectangle
                    opacity: (rootScope.bridge && rootScope.bridge.hasMedia && (!rootScope.fsm || !rootScope.fsm.isExpanded)) ? 1.0 : 0.0
                    Behavior on opacity {
                        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                    }

                    // Interaction: Clicking capsule triggers StateMachine.togglePin()
                    MouseArea {
                        id: capsuleClickArea
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (rootScope.fsm) {
                                rootScope.fsm.togglePin();
                            }
                        }
                    }

                    RowLayout {
                        id: contentRow
                        anchors.centerIn: parent
                        spacing: 6

                        // 22x22px Album Art Container (radius 4px, fallback music note icon)
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
                                id: albumArtImage
                                anchors.fill: parent
                                source: rootScope.bridge ? rootScope.bridge.artUrl : ""
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                visible: rootScope.bridge && rootScope.bridge.artUrl !== "" && status === Image.Ready
                            }

                            Text {
                                anchors.centerIn: parent
                                text: "󰎆"
                                color: (rootScope.bridge && rootScope.bridge.isPlaying) ? "#38bdf8" : "#71717a"
                                font.pixelSize: 11
                                visible: !albumArtImage.visible
                            }
                        }

                        // 2-Tier Metadata: Track Title (bold 10px), Artist (9px Zinc-400 #a1a1aa)
                        ColumnLayout {
                            spacing: 0
                            Layout.alignment: Qt.AlignVCenter

                            // Track Title with smooth Marquee ticker for long text
                            Item {
                                id: marqueeBox
                                implicitWidth: Math.min(titleLabel.paintedWidth, 100)
                                Layout.preferredWidth: implicitWidth
                                implicitHeight: titleLabel.paintedHeight
                                Layout.preferredHeight: implicitHeight
                                clip: true

                                Text {
                                id: titleLabel
                                text: (rootScope.bridge && rootScope.bridge.title !== "") ? rootScope.bridge.title : "No Media"
                                font.family: "Geist"
                                font.pixelSize: 10
                                font.weight: Font.Bold
                                color: "#fafafa"

                                property bool needScroll: paintedWidth > 100
                                onTextChanged: titleLabel.x = 0

                                SequentialAnimation on x {
                                    running: titleLabel.needScroll && rootScope.bridge && rootScope.bridge.isPlaying
                                    loops: Animation.Infinite

                                    PauseAnimation { duration: 1500 }
                                    NumberAnimation {
                                        to: -(titleLabel.paintedWidth - 100)
                                        duration: Math.max(1500, (titleLabel.paintedWidth - 100) * 35)
                                        easing.type: Easing.Linear
                                    }
                                    PauseAnimation { duration: 1500 }
                                    NumberAnimation {
                                        to: 0
                                        duration: Math.max(1500, (titleLabel.paintedWidth - 100) * 35)
                                        easing.type: Easing.Linear
                                    }
                                }
                            }
                        }

                        // Artist Name
                        Text {
                            Layout.maximumWidth: 100
                            text: (rootScope.bridge && rootScope.bridge.artist !== "") ? rootScope.bridge.artist : "Unknown Artist"
                            font.family: "Geist"
                            font.pixelSize: 9
                            color: "#a1a1aa"
                            elide: Text.ElideRight
                            maximumLineCount: 1
                        }
                    }

                    // Inline Controls: Previous, Play/Pause toggle, Next
                    RowLayout {
                        id: controlsRow
                        spacing: 2
                        Layout.alignment: Qt.AlignVCenter

                        // Previous Track Button
                        Rectangle {
                            width: 18
                            height: 18
                            radius: 9
                            color: prevMouse.containsMouse ? Qt.rgba(1.0, 1.0, 1.0, 0.18) : "transparent"

                            Text {
                                anchors.centerIn: parent
                                text: "󰒮"
                                font.pixelSize: 9
                                color: "#fafafa"
                            }

                            MouseArea {
                                id: prevMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (rootScope.bridge) rootScope.bridge.previous();
                                }
                            }
                        }

                        // Play / Pause Toggle Button
                        Rectangle {
                            width: 18
                            height: 18
                            radius: 9
                            color: playMouse.containsMouse ? Qt.rgba(56 / 255, 189 / 255, 248 / 255, 0.35) : Qt.rgba(1.0, 1.0, 1.0, 0.12)
                            border.color: (rootScope.bridge && rootScope.bridge.isPlaying) ? Qt.rgba(56 / 255, 189 / 255, 248 / 255, 0.5) : "transparent"
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                text: (rootScope.bridge && rootScope.bridge.isPlaying) ? "󰏤" : "󰐊"
                                font.pixelSize: 9
                                color: (rootScope.bridge && rootScope.bridge.isPlaying) ? "#38bdf8" : "#fafafa"
                            }

                            MouseArea {
                                id: playMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (rootScope.bridge) rootScope.bridge.playPause();
                                }
                            }
                        }

                        // Next Track Button
                        Rectangle {
                            width: 18
                            height: 18
                            radius: 9
                            color: nextMouse.containsMouse ? Qt.rgba(1.0, 1.0, 1.0, 0.18) : "transparent"

                            Text {
                                anchors.centerIn: parent
                                text: "󰒭"
                                font.pixelSize: 9
                                color: "#fafafa"
                            }

                            MouseArea {
                                id: nextMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (rootScope.bridge) rootScope.bridge.next();
                                }
                            }
                        }
                    }

                    // Mini Spectrum: Dynamic 4-Bar Audio Visualizer
                    Row {
                        id: visualizerRow
                        spacing: 2
                        Layout.alignment: Qt.AlignVCenter
                        visible: true

                        Repeater {
                            model: 4

                            Rectangle {
                                id: waveBar
                                width: 2
                                radius: 1
                                color: "#38bdf8"
                                anchors.verticalCenter: parent.verticalCenter

                                property real baseHeight: 3
                                property real maxHeight: 10

                                height: (rootScope.bridge && rootScope.bridge.isPlaying) ? baseHeight : 2

                                SequentialAnimation on height {
                                    running: rootScope.bridge && rootScope.bridge.isPlaying
                                    loops: Animation.Infinite

                                    NumberAnimation {
                                        to: waveBar.maxHeight - (index % 2 === 0 ? 0 : 3)
                                        duration: 260 + index * 70
                                        easing.type: Easing.InOutSine
                                    }
                                    NumberAnimation {
                                        to: waveBar.baseHeight + (index % 3 === 0 ? 2 : 0)
                                        duration: 300 + index * 60
                                        easing.type: Easing.InOutSine
                                    }
                                }

                                Behavior on height {
                                    enabled: !rootScope.bridge || !rootScope.bridge.isPlaying
                                    NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
}
