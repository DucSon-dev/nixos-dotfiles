import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

PanelWindow {
    id: flyoutWindow

    // Wayland Layer-shell configuration anchored strictly to Top-Right
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore

    anchors {
        top: true
        right: true
    }

    margins {
        top: 48
        right: 280
    }

    implicitWidth: 380
    implicitHeight: 170
    color: "transparent"

    // Flyout visibility state with smooth fade animation
    property bool flyoutVisible: false
    visible: card.opacity > 0.0

    // Media properties
    property string trackTitle: "No Media"
    property string trackArtist: "Unknown Artist"
    property string artUrl: ""
    property string playbackStatus: "Stopped"
    property string playerName: "Media"
    property real positionSec: 0
    property real lengthSec: 0
    property string loopStatus: "None"
    property bool shuffleStatus: false

    readonly property bool isPlaying: playbackStatus === "Playing"

    // Time formatting helper (MM:SS)
    function formatTime(totalSeconds) {
        if (isNaN(totalSeconds) || totalSeconds <= 0) return "00:00";
        var mins = Math.floor(totalSeconds / 60);
        var secs = Math.floor(totalSeconds % 60);
        var minStr = mins < 10 ? "0" + mins : "" + mins;
        var secStr = secs < 10 ? "0" + secs : "" + secs;
        return minStr + ":" + secStr;
    }

    function toggleFlyout() {
        if (flyoutVisible) {
            closeFlyout();
        } else {
            openFlyout();
        }
    }

    function openFlyout() {
        refreshMedia();
        flyoutVisible = true;
        dismissTimer.restart();
    }

    function closeFlyout() {
        dismissTimer.stop();
        flyoutVisible = false;
    }

    function triggerAutoPopup() {
        refreshMedia();
        flyoutVisible = true;
        dismissTimer.restart();
    }

    // Auto-dismiss timer (3500ms duration, cancelled on hover)
    Timer {
        id: dismissTimer
        interval: 3500
        repeat: false
        onTriggered: {
            if (!cardHoverArea.containsMouse) {
                flyoutWindow.flyoutVisible = false;
            }
        }
    }

    // Continuous progress tracking while media is playing
    Timer {
        interval: 1000
        running: flyoutWindow.flyoutVisible && flyoutWindow.isPlaying
        repeat: true
        onTriggered: {
            if (flyoutWindow.lengthSec > 0 && flyoutWindow.positionSec < flyoutWindow.lengthSec) {
                flyoutWindow.positionSec += 1;
            }
        }
    }

    // Autonomous event watcher: follows playerctl metadata updates
    Process {
        id: playerWatcher
        command: ["playerctl", "--follow", "metadata", "--format", "{{xesam:title}}|||{{xesam:artist}}|||{{mpris:artUrl}}|||{{status}}|||{{playerName}}|||{{position}}|||{{mpris:length}}|||{{loop}}|||{{shuffle}}"]
        stdout: SplitParser {
            onRead: data => {
                var line = data.trim();
                if (line === "") return;
                var parts = line.split("|||");
                if (parts.length >= 4) {
                    var newTitle = parts[0].trim();
                    var newArtist = parts[1].trim();
                    var newArt = parts[2].trim();
                    var newStatus = parts[3].trim();
                    var newPlayer = parts.length >= 5 ? parts[4].trim() : "Media";

                    // Trigger auto-popup when track changes and audio is playing
                    if (newTitle !== "" && newTitle !== flyoutWindow.trackTitle && newStatus === "Playing") {
                        flyoutWindow.triggerAutoPopup();
                    }

                    flyoutWindow.trackTitle = newTitle !== "" ? newTitle : "No Media";
                    flyoutWindow.trackArtist = newArtist !== "" ? newArtist : "Unknown Artist";
                    flyoutWindow.artUrl = newArt;
                    flyoutWindow.playbackStatus = newStatus;
                    flyoutWindow.playerName = newPlayer !== "" ? newPlayer : "Media";

                    if (parts.length >= 7) {
                        var posUs = parseFloat(parts[5].trim()) || 0;
                        var lenUs = parseFloat(parts[6].trim()) || 0;
                        flyoutWindow.positionSec = posUs / 1000000;
                        flyoutWindow.lengthSec = lenUs / 1000000;
                    }
                    if (parts.length >= 9) {
                        flyoutWindow.loopStatus = parts[7].trim();
                        flyoutWindow.shuffleStatus = parts[8].trim() === "On" || parts[8].trim() === "true";
                    }
                }
            }
        }
        onExited: restartWatcherTimer.restart()
    }

    Timer {
        id: restartWatcherTimer
        interval: 2000
        repeat: false
        onTriggered: {
            if (!playerWatcher.running) playerWatcher.running = true;
        }
    }

    // Single-shot refresh query
    Process {
        id: refreshProcess
        command: ["playerctl", "metadata", "--format", "{{xesam:title}}|||{{xesam:artist}}|||{{mpris:artUrl}}|||{{status}}|||{{playerName}}|||{{position}}|||{{mpris:length}}|||{{loop}}|||{{shuffle}}"]
        stdout: SplitParser {
            onRead: data => {
                var line = data.trim();
                if (line === "") return;
                var parts = line.split("|||");
                if (parts.length >= 4) {
                    var t = parts[0].trim();
                    flyoutWindow.trackTitle = t !== "" ? t : "No Media";
                    flyoutWindow.trackArtist = parts[1].trim() !== "" ? parts[1].trim() : "Unknown Artist";
                    flyoutWindow.artUrl = parts[2].trim();
                    flyoutWindow.playbackStatus = parts[3].trim();
                    if (parts.length >= 5 && parts[4].trim() !== "") flyoutWindow.playerName = parts[4].trim();
                    if (parts.length >= 7) {
                        flyoutWindow.positionSec = (parseFloat(parts[5].trim()) || 0) / 1000000;
                        flyoutWindow.lengthSec = (parseFloat(parts[6].trim()) || 0) / 1000000;
                    }
                    if (parts.length >= 9) {
                        flyoutWindow.loopStatus = parts[7].trim();
                        flyoutWindow.shuffleStatus = parts[8].trim() === "On" || parts[8].trim() === "true";
                    }
                }
            }
        }
    }

    function refreshMedia() {
        if (!refreshProcess.running) refreshProcess.running = true;
    }

    // IPC Socket Listener on /tmp/fluent_flyout.sock
    Process {
        id: socketListener
        command: ["sh", "-c", "rm -f /tmp/fluent_flyout.sock; while true; do nc -l -U /tmp/fluent_flyout.sock 2>/dev/null; echo 'toggle'; done"]
        stdout: SplitParser {
            onRead: data => {
                flyoutWindow.toggleFlyout();
            }
        }
    }

    // Secondary file-watch trigger fallback on /tmp/fluent_flyout_trigger
    FileView {
        id: triggerFileView
        path: "/tmp/fluent_flyout_trigger"
        watchChanges: true
        onFileChanged: {
            flyoutWindow.toggleFlyout();
        }
    }

    Component.onCompleted: {
        Quickshell.execDetached(["touch", "/tmp/fluent_flyout_trigger"]);
        socketListener.running = true;
        playerWatcher.running = true;
        refreshMedia();
    }

    // Fluent Glass Blur Card (380px x 170px, radius 16px, background #09090b @ 0.75, specular border)
    Rectangle {
        id: card
        anchors.fill: parent
        radius: 16
        color: Qt.rgba(9 / 255, 9 / 255, 11 / 255, 0.75)
        border.color: Qt.rgba(1.0, 1.0, 1.0, 0.12)
        border.width: 1
        clip: true

        opacity: flyoutWindow.flyoutVisible ? 1.0 : 0.0

        Behavior on opacity {
            NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
        }

        // HoverArea prevents auto-dismiss while hovered
        MouseArea {
            id: cardHoverArea
            anchors.fill: parent
            hoverEnabled: true
            onEntered: dismissTimer.stop()
            onExited: {
                if (flyoutWindow.flyoutVisible) {
                    dismissTimer.restart();
                }
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8

            // Top Row: Album Art (80x80) + Metadata + Controls + Close
            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                // High-Res Album Art Container (80x80, rounded 12px)
                Rectangle {
                    width: 80
                    height: 80
                    radius: 12
                    color: Qt.rgba(24 / 255, 24 / 255, 27 / 255, 0.85)
                    border.color: Qt.rgba(1.0, 1.0, 1.0, 0.12)
                    border.width: 1
                    clip: true
                    Layout.alignment: Qt.AlignVCenter

                    Image {
                        anchors.fill: parent
                        source: flyoutWindow.artUrl
                        fillMode: Image.PreserveAspectCrop
                        visible: flyoutWindow.artUrl !== ""
                        smooth: true
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "󰎆"
                        color: "#a1a1aa"
                        font.pixelSize: 34
                        visible: flyoutWindow.artUrl === ""
                    }
                }

                // Middle Info Column + Action Bar
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 3

                    // Header Row: Player Source Badge + Close Button
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        Rectangle {
                            height: 16
                            implicitWidth: badgeLabel.implicitWidth + 8
                            radius: 4
                            color: Qt.rgba(56 / 255, 189 / 255, 248 / 255, 0.18)
                            border.color: Qt.rgba(56 / 255, 189 / 255, 248 / 255, 0.40)
                            border.width: 1

                            Text {
                                id: badgeLabel
                                anchors.centerIn: parent
                                text: flyoutWindow.playerName.toUpperCase()
                                font.family: "Geist"
                                font.pixelSize: 9
                                font.weight: Font.DemiBold
                                color: "#38bdf8"
                            }
                        }

                        Item { Layout.fillWidth: true }

                        // Dismiss / Close Button
                        Rectangle {
                            width: 18
                            height: 18
                            radius: 9
                            color: closeMouse.containsMouse ? Qt.rgba(1.0, 1.0, 1.0, 0.18) : "transparent"

                            Text {
                                anchors.centerIn: parent
                                text: "󰅖"
                                font.pixelSize: 10
                                color: "#a1a1aa"
                            }

                            MouseArea {
                                id: closeMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: flyoutWindow.closeFlyout()
                            }
                        }
                    }

                    // Track Title (Auto-truncation via ElideRight)
                    Text {
                        Layout.fillWidth: true
                        text: flyoutWindow.trackTitle
                        font.family: "Geist"
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        color: "#fafafa"
                        elide: Text.ElideRight
                    }

                    // Track Artist (Auto-truncation via ElideRight)
                    Text {
                        Layout.fillWidth: true
                        text: flyoutWindow.trackArtist
                        font.family: "Geist"
                        font.pixelSize: 11
                        color: "#a1a1aa"
                        elide: Text.ElideRight
                    }

                    // Extended Action Bar (Previous, Play/Pause, Next, Shuffle, Loop)
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        Layout.topMargin: 2

                        // Previous Button
                        Rectangle {
                            width: 24
                            height: 24
                            radius: 12
                            color: prevMouse.containsMouse ? Qt.rgba(1.0, 1.0, 1.0, 0.18) : Qt.rgba(1.0, 1.0, 1.0, 0.08)

                            Text {
                                anchors.centerIn: parent
                                text: "󰒮"
                                font.pixelSize: 11
                                color: "#fafafa"
                            }

                            MouseArea {
                                id: prevMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    Quickshell.execDetached(["playerctl", "previous"]);
                                    flyoutWindow.refreshMedia();
                                }
                            }
                        }

                        // Play / Pause Toggle Button
                        Rectangle {
                            width: 28
                            height: 28
                            radius: 14
                            color: playMouse.containsMouse ? Qt.rgba(56 / 255, 189 / 255, 248 / 255, 0.45) : Qt.rgba(56 / 255, 189 / 255, 248 / 255, 0.25)
                            border.color: Qt.rgba(56 / 255, 189 / 255, 248 / 255, 0.60)
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                text: flyoutWindow.isPlaying ? "󰏤" : "󰐊"
                                font.pixelSize: 12
                                color: "#38bdf8"
                            }

                            MouseArea {
                                id: playMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    Quickshell.execDetached(["playerctl", "play-pause"]);
                                    flyoutWindow.refreshMedia();
                                }
                            }
                        }

                        // Next Button
                        Rectangle {
                            width: 24
                            height: 24
                            radius: 12
                            color: nextMouse.containsMouse ? Qt.rgba(1.0, 1.0, 1.0, 0.18) : Qt.rgba(1.0, 1.0, 1.0, 0.08)

                            Text {
                                anchors.centerIn: parent
                                text: "󰒭"
                                font.pixelSize: 11
                                color: "#fafafa"
                            }

                            MouseArea {
                                id: nextMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    Quickshell.execDetached(["playerctl", "next"]);
                                    flyoutWindow.refreshMedia();
                                }
                            }
                        }

                        // Shuffle Toggle Button (playerctl shuffle toggle)
                        Rectangle {
                            width: 24
                            height: 24
                            radius: 12
                            color: flyoutWindow.shuffleStatus ? Qt.rgba(56 / 255, 189 / 255, 248 / 255, 0.25) : (shuffleMouse.containsMouse ? Qt.rgba(1.0, 1.0, 1.0, 0.15) : "transparent")
                            border.color: flyoutWindow.shuffleStatus ? Qt.rgba(56 / 255, 189 / 255, 248 / 255, 0.50) : "transparent"
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                text: "󰒝"
                                font.pixelSize: 11
                                color: flyoutWindow.shuffleStatus ? "#38bdf8" : "#71717a"
                            }

                            MouseArea {
                                id: shuffleMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    flyoutWindow.shuffleStatus = !flyoutWindow.shuffleStatus;
                                    Quickshell.execDetached(["playerctl", "shuffle", "toggle"]);
                                }
                            }
                        }

                        // Repeat / Loop Toggle Button (playerctl loop [None|Track|Playlist])
                        Rectangle {
                            width: 24
                            height: 24
                            radius: 12
                            property bool isLoopActive: flyoutWindow.loopStatus === "Playlist" || flyoutWindow.loopStatus === "Track"
                            color: isLoopActive ? Qt.rgba(56 / 255, 189 / 255, 248 / 255, 0.25) : (loopMouse.containsMouse ? Qt.rgba(1.0, 1.0, 1.0, 0.15) : "transparent")
                            border.color: isLoopActive ? Qt.rgba(56 / 255, 189 / 255, 248 / 255, 0.50) : "transparent"
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                text: flyoutWindow.loopStatus === "Track" ? "󰑗" : "󰑖"
                                font.pixelSize: 11
                                color: parent.isLoopActive ? "#38bdf8" : "#71717a"
                            }

                            MouseArea {
                                id: loopMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    var nextLoop = "Playlist";
                                    if (flyoutWindow.loopStatus === "Playlist") nextLoop = "Track";
                                    else if (flyoutWindow.loopStatus === "Track") nextLoop = "None";
                                    flyoutWindow.loopStatus = nextLoop;
                                    Quickshell.execDetached(["playerctl", "loop", nextLoop]);
                                }
                            }
                        }
                    }
                }
            }

            // Bottom Section: Interactive Seekbar (Slider)
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                // Seek Slider Track
                Rectangle {
                    id: seekSliderTrack
                    Layout.fillWidth: true
                    height: 6
                    radius: 3
                    color: Qt.rgba(1.0, 1.0, 1.0, 0.12)

                    // Track Progress Fill
                    Rectangle {
                        height: parent.height
                        radius: 3
                        color: "#38bdf8"
                        width: {
                            if (flyoutWindow.lengthSec > 0) {
                                return Math.min(seekSliderTrack.width, Math.max(0, (flyoutWindow.positionSec / flyoutWindow.lengthSec) * seekSliderTrack.width));
                            }
                            return 0;
                        }
                    }

                    // Seek Handle Dot
                    Rectangle {
                        width: 10
                        height: 10
                        radius: 5
                        color: "#fafafa"
                        anchors.verticalCenter: parent.verticalCenter
                        x: {
                            if (flyoutWindow.lengthSec > 0) {
                                return Math.min(seekSliderTrack.width - width, Math.max(0, (flyoutWindow.positionSec / flyoutWindow.lengthSec) * seekSliderTrack.width - width / 2));
                            }
                            return 0;
                        }
                        visible: seekArea.containsMouse || seekArea.pressed
                    }

                    MouseArea {
                        id: seekArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        function performSeek(mouseX) {
                            if (flyoutWindow.lengthSec > 0 && seekSliderTrack.width > 0) {
                                var ratio = Math.max(0.0, Math.min(1.0, mouseX / seekSliderTrack.width));
                                var targetSec = Math.round(ratio * flyoutWindow.lengthSec);
                                flyoutWindow.positionSec = targetSec;
                                Quickshell.execDetached(["playerctl", "position", targetSec.toString()]);
                            }
                        }
                        onClicked: mouse => performSeek(mouse.x)
                        onPositionChanged: mouse => {
                            if (pressed) performSeek(mouse.x);
                        }
                    }
                }

                // Progress Time Indicators (Elapsed and Total Duration)
                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: flyoutWindow.formatTime(flyoutWindow.positionSec)
                        font.family: "GeistMono Nerd Font"
                        font.pixelSize: 9
                        color: "#71717a"
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: flyoutWindow.formatTime(flyoutWindow.lengthSec)
                        font.family: "GeistMono Nerd Font"
                        font.pixelSize: 9
                        color: "#71717a"
                    }
                }
            }
        }
    }
}
