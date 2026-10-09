import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

// Interactive Media Flyout Card (Liquid Glass Surface)
// Independent Wayland Layer-Shell surface bound to StateMachine and MprisBridge.
PanelWindow {
    id: flyoutWindow

    // Injected foundation dependencies
    property QtObject fsm: null
    property QtObject bridge: null

    // Layer-Shell configuration: Overlay layer anchored top-right
    WlrLayershell.layer: WlrLayer.Overlay
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

    implicitWidth: 380
    implicitHeight: 170
    color: "transparent"

    // Engine Type Invariant: PanelWindow lifecycle governed strictly by internal card opacity.
    // Do NOT assign opacity or Behavior on opacity directly to PanelWindow.
    visible: cardBackground.opacity > 0.0

    // Time formatting helper (MM:SS)
    function formatTime(totalSeconds) {
        if (isNaN(totalSeconds) || totalSeconds <= 0) return "00:00";
        var mins = Math.floor(totalSeconds / 60);
        var secs = Math.floor(totalSeconds % 60);
        return (mins < 10 ? "0" + mins : "" + mins) + ":" + (secs < 10 ? "0" + secs : "" + secs);
    }

    // Main Card Body (shadcn Dark Zinc #09090b @ 0.75, 16px corner radius, specular border)
    Rectangle {
        id: cardBackground
        anchors.fill: parent
        radius: 16
        color: Qt.rgba(9 / 255, 9 / 255, 11 / 255, 0.75)
        border.color: Qt.rgba(1.0, 1.0, 1.0, 0.12)
        border.width: 1
        clip: true

        // Mutual Exclusivity: Tied to StateMachine.isExpanded and media presence
        opacity: (flyoutWindow.fsm && flyoutWindow.fsm.isExpanded && flyoutWindow.bridge && flyoutWindow.bridge.hasMedia) ? 1.0 : 0.0
        Behavior on opacity {
            NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
        }

        // Hover tracking for StateMachine auto-hide timer suppression
        MouseArea {
            id: cardHoverArea
            anchors.fill: parent
            hoverEnabled: true
            onContainsMouseChanged: {
                if (flyoutWindow.fsm) {
                    flyoutWindow.fsm.isHovered = containsMouse;
                }
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 8

            // Top Section: Album Artwork + Metadata + Close Button
            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                // 80x80px HD Album Artwork Container
                Rectangle {
                    width: 80
                    height: 80
                    radius: 10
                    color: Qt.rgba(24 / 255, 24 / 255, 27 / 255, 0.90)
                    border.color: Qt.rgba(1.0, 1.0, 1.0, 0.15)
                    border.width: 1
                    clip: true
                    Layout.alignment: Qt.AlignTop

                    Image {
                        id: coverImage
                        anchors.fill: parent
                        source: flyoutWindow.bridge ? flyoutWindow.bridge.artUrl : ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        visible: flyoutWindow.bridge && flyoutWindow.bridge.artUrl !== "" && status === Image.Ready
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "󰎆"
                        color: (flyoutWindow.bridge && flyoutWindow.bridge.isPlaying) ? "#38bdf8" : "#71717a"
                        font.pixelSize: 28
                        visible: !coverImage.visible
                    }
                }

                // Metadata Column
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    Layout.alignment: Qt.AlignVCenter

                    // Header row: Track Title + Close Button
                    RowLayout {
                        Layout.fillWidth: true

                        // Marquee Box for Track Title
                        Item {
                            id: titleMarqueeBox
                            Layout.fillWidth: true
                            implicitHeight: titleText.paintedHeight
                            clip: true

                            Text {
                                id: titleText
                                text: (flyoutWindow.bridge && flyoutWindow.bridge.title !== "") ? flyoutWindow.bridge.title : "No Media"
                                font.family: "Geist"
                                font.pixelSize: 14
                                font.weight: Font.Bold
                                color: "#fafafa"

                                property bool needScroll: paintedWidth > titleMarqueeBox.width && titleMarqueeBox.width > 0
                                onTextChanged: titleText.x = 0

                                SequentialAnimation on x {
                                    running: titleText.needScroll && flyoutWindow.bridge && flyoutWindow.bridge.isPlaying
                                    loops: Animation.Infinite

                                    PauseAnimation { duration: 1800 }
                                    NumberAnimation {
                                        to: -(titleText.paintedWidth - titleMarqueeBox.width)
                                        duration: Math.max(1500, (titleText.paintedWidth - titleMarqueeBox.width) * 30)
                                        easing.type: Easing.Linear
                                    }
                                    PauseAnimation { duration: 1800 }
                                    NumberAnimation {
                                        to: 0
                                        duration: Math.max(1500, (titleText.paintedWidth - titleMarqueeBox.width) * 30)
                                        easing.type: Easing.Linear
                                    }
                                }
                            }
                        }

                        // Close Button (dismiss to IDLE)
                        Rectangle {
                            width: 20
                            height: 20
                            radius: 10
                            color: closeMouse.containsMouse ? Qt.rgba(1.0, 1.0, 1.0, 0.18) : "transparent"

                            Text {
                                anchors.centerIn: parent
                                text: "󰅖"
                                font.pixelSize: 11
                                color: "#a1a1aa"
                            }

                            MouseArea {
                                id: closeMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (flyoutWindow.fsm) {
                                        flyoutWindow.fsm.dismiss();
                                    }
                                }
                            }
                        }
                    }

                    // Artist Name (12px Zinc-400)
                    Text {
                        Layout.fillWidth: true
                        text: (flyoutWindow.bridge && flyoutWindow.bridge.artist !== "") ? flyoutWindow.bridge.artist : "Unknown Artist"
                        font.family: "Geist"
                        font.pixelSize: 12
                        color: "#a1a1aa"
                        elide: Text.ElideRight
                        maximumLineCount: 1
                    }

                    // Album / Player Badge Pill
                    Rectangle {
                        implicitWidth: badgeText.paintedWidth + 10
                        implicitHeight: 18
                        radius: 4
                        color: Qt.rgba(1.0, 1.0, 1.0, 0.08)
                        border.color: Qt.rgba(1.0, 1.0, 1.0, 0.12)
                        border.width: 1
                        visible: flyoutWindow.bridge && (flyoutWindow.bridge.album !== "" || flyoutWindow.bridge.title !== "")

                        Text {
                            id: badgeText
                            anchors.centerIn: parent
                            text: (flyoutWindow.bridge && flyoutWindow.bridge.album !== "") ? flyoutWindow.bridge.album : "Media"
                            font.family: "Geist"
                            font.pixelSize: 9
                            color: "#d4d4d8"
                            elide: Text.ElideRight
                        }
                    }
                }
            }

            // Center Section: Interactive Seekbar Timeline
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3

                Rectangle {
                    id: seekbarTrack
                    Layout.fillWidth: true
                    height: 5
                    radius: 2.5
                    color: Qt.rgba(1.0, 1.0, 1.0, 0.15)

                    // Interactive scrubbing lock & cooldown state
                    property bool isScrubbing: false
                    property real scrubRatio: 0.0

                    Timer {
                        id: scrubCooldownTimer
                        interval: 350
                        repeat: false
                        onTriggered: {
                            seekbarTrack.isScrubbing = false;
                        }
                    }

                    // Fill bar
                    Rectangle {
                        height: parent.height
                        radius: 2.5
                        color: "#38bdf8"
                        width: {
                            if (seekbarTrack.isScrubbing) {
                                return Math.min(seekbarTrack.width, Math.max(0, seekbarTrack.scrubRatio * seekbarTrack.width));
                            }
                            if (flyoutWindow.bridge && flyoutWindow.bridge.lengthSec > 0) {
                                return Math.min(seekbarTrack.width, Math.max(0, (flyoutWindow.bridge.positionSec / flyoutWindow.bridge.lengthSec) * seekbarTrack.width));
                            }
                            return 0;
                        }
                    }

                    // Thumb dot
                    Rectangle {
                        width: 10
                        height: 10
                        radius: 5
                        color: "#fafafa"
                        anchors.verticalCenter: parent.verticalCenter
                        x: {
                            if (seekbarTrack.isScrubbing) {
                                return Math.min(seekbarTrack.width - width, Math.max(0, seekbarTrack.scrubRatio * seekbarTrack.width - width / 2));
                            }
                            if (flyoutWindow.bridge && flyoutWindow.bridge.lengthSec > 0) {
                                return Math.min(seekbarTrack.width - width, Math.max(0, (flyoutWindow.bridge.positionSec / flyoutWindow.bridge.lengthSec) * seekbarTrack.width - width / 2));
                            }
                            return 0;
                        }
                        visible: seekArea.containsMouse || seekArea.pressed || seekbarTrack.isScrubbing
                    }

                    MouseArea {
                        id: seekArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor

                        function updateScrub(mouseX) {
                            if (seekbarTrack.width > 0) {
                                var ratio = Math.max(0.0, Math.min(1.0, mouseX / seekbarTrack.width));
                                seekbarTrack.scrubRatio = ratio;
                            }
                        }

                        function commitSeek() {
                            if (flyoutWindow.bridge && flyoutWindow.bridge.lengthSec > 0 && seekbarTrack.width > 0) {
                                var targetSec = seekbarTrack.scrubRatio * flyoutWindow.bridge.lengthSec;
                                var clampedSec = Math.max(0.0, Math.min(targetSec, flyoutWindow.bridge.lengthSec));
                                flyoutWindow.bridge.seek(clampedSec);
                            }
                            // Start 350ms cooldown before unlocking background D-Bus position updates
                            scrubCooldownTimer.restart();
                        }

                        onPressed: mouse => {
                            scrubCooldownTimer.stop();
                            seekbarTrack.isScrubbing = true;
                            updateScrub(mouse.x);
                        }

                        onPositionChanged: mouse => {
                            if (pressed) {
                                updateScrub(mouse.x);
                            }
                        }

                        onReleased: mouse => {
                            updateScrub(mouse.x);
                            commitSeek();
                        }

                        onCanceled: {
                            scrubCooldownTimer.restart();
                        }
                    }
                }

                // Time indicators (MM:SS)
                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: flyoutWindow.formatTime(flyoutWindow.bridge ? flyoutWindow.bridge.positionSec : 0)
                        font.family: "GeistMono Nerd Font"
                        font.pixelSize: 9
                        color: "#71717a"
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: flyoutWindow.formatTime(flyoutWindow.bridge ? flyoutWindow.bridge.lengthSec : 0)
                        font.family: "GeistMono Nerd Font"
                        font.pixelSize: 9
                        color: "#71717a"
                    }
                }
            }

            // Bottom Section: Playback Control Bar
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 14

                // Shuffle Toggle
                Rectangle {
                    width: 26
                    height: 26
                    radius: 13
                    opacity: (flyoutWindow.bridge && flyoutWindow.bridge.canShuffle) ? 1.0 : 0.35
                    color: (flyoutWindow.bridge && flyoutWindow.bridge.shuffleStatus) ? Qt.rgba(56 / 255, 189 / 255, 248 / 255, 0.25) : (shuffleMouse.containsMouse ? Qt.rgba(1.0, 1.0, 1.0, 0.15) : "transparent")
                    border.color: (flyoutWindow.bridge && flyoutWindow.bridge.shuffleStatus) ? Qt.rgba(56 / 255, 189 / 255, 248 / 255, 0.50) : "transparent"
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "󰒝"
                        font.pixelSize: 12
                        color: (flyoutWindow.bridge && flyoutWindow.bridge.shuffleStatus) ? "#38bdf8" : "#71717a"
                    }

                    MouseArea {
                        id: shuffleMouse
                        anchors.fill: parent
                        enabled: flyoutWindow.bridge ? flyoutWindow.bridge.canShuffle : false
                        hoverEnabled: enabled
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: {
                            if (flyoutWindow.bridge && flyoutWindow.bridge.canShuffle) flyoutWindow.bridge.toggleShuffle();
                        }
                    }
                }

                // Previous
                Rectangle {
                    width: 28
                    height: 28
                    radius: 14
                    color: prevMouse.containsMouse ? Qt.rgba(1.0, 1.0, 1.0, 0.18) : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: "󰒮"
                        font.pixelSize: 13
                        color: "#fafafa"
                    }

                    MouseArea {
                        id: prevMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (flyoutWindow.bridge) flyoutWindow.bridge.previous();
                        }
                    }
                }

                // Play / Pause Toggle (Primary Action Pill)
                Rectangle {
                    width: 32
                    height: 32
                    radius: 16
                    color: playMouse.containsMouse ? Qt.rgba(56 / 255, 189 / 255, 248 / 255, 0.40) : Qt.rgba(1.0, 1.0, 1.0, 0.14)
                    border.color: (flyoutWindow.bridge && flyoutWindow.bridge.isPlaying) ? Qt.rgba(56 / 255, 189 / 255, 248 / 255, 0.6) : Qt.rgba(1.0, 1.0, 1.0, 0.2)
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: (flyoutWindow.bridge && flyoutWindow.bridge.isPlaying) ? "󰏤" : "󰐊"
                        font.pixelSize: 14
                        color: (flyoutWindow.bridge && flyoutWindow.bridge.isPlaying) ? "#38bdf8" : "#fafafa"
                    }

                    MouseArea {
                        id: playMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (flyoutWindow.bridge) flyoutWindow.bridge.playPause();
                        }
                    }
                }

                // Next
                Rectangle {
                    width: 28
                    height: 28
                    radius: 14
                    color: nextMouse.containsMouse ? Qt.rgba(1.0, 1.0, 1.0, 0.18) : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: "󰒭"
                        font.pixelSize: 13
                        color: "#fafafa"
                    }

                    MouseArea {
                        id: nextMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (flyoutWindow.bridge) flyoutWindow.bridge.next();
                        }
                    }
                }

                // Loop Cycle
                Rectangle {
                    width: 26
                    height: 26
                    radius: 13
                    opacity: (flyoutWindow.bridge && flyoutWindow.bridge.canLoop) ? 1.0 : 0.35
                    property bool isLooping: flyoutWindow.bridge && (flyoutWindow.bridge.loopStatus === "Playlist" || flyoutWindow.bridge.loopStatus === "Track")
                    color: isLooping ? Qt.rgba(56 / 255, 189 / 255, 248 / 255, 0.25) : (loopMouse.containsMouse ? Qt.rgba(1.0, 1.0, 1.0, 0.15) : "transparent")
                    border.color: isLooping ? Qt.rgba(56 / 255, 189 / 255, 248 / 255, 0.50) : "transparent"
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: (flyoutWindow.bridge && flyoutWindow.bridge.loopStatus === "Track") ? "󰑗" : "󰑖"
                        font.pixelSize: 12
                        color: parent.isLooping ? "#38bdf8" : "#71717a"
                    }

                    MouseArea {
                        id: loopMouse
                        anchors.fill: parent
                        enabled: flyoutWindow.bridge ? flyoutWindow.bridge.canLoop : false
                        hoverEnabled: enabled
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: {
                            if (flyoutWindow.bridge && flyoutWindow.bridge.canLoop) flyoutWindow.bridge.cycleLoop();
                        }
                    }
                }
            }
        }
    }
}
