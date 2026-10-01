import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

Scope {
    id: rootScope

    // Reactive State Properties
    property string songTitle: "No media playing"
    property string songArtist: ""
    property string playbackStatus: "Stopped"
    property string artUrl: ""
    property string playerName: ""
    property string fullPlayerId: ""
    property bool canGoNext: false
    property bool canGoPrevious: false
    readonly property bool isPlaying: playbackStatus === "Playing"
    property bool popupVisible: false

    // Auto-hide timer for transient popup
    Timer {
        id: autoHideTimer
        interval: 4000
        repeat: false
        onTriggered: rootScope.popupVisible = false
    }

    // Normalized Application Display Name Resolver
    function getNormalizedAppName(rawId) {
        let idLower = rawId.toLowerCase();
        if (idLower.indexOf("amberol") !== -1) return "Amberol";
        if (idLower.indexOf("brave") !== -1) return "Brave";
        if (idLower.indexOf("spotify") !== -1) return "Spotify";
        if (idLower.indexOf("firefox") !== -1) return "Firefox";
        if (idLower.indexOf("chrome") !== -1 || idLower.indexOf("chromium") !== -1) return "Chrome";
        if (idLower.indexOf("vlc") !== -1) return "VLC";
        return rawId.split(".")[0];
    }

    // Application Icon Resolver using Nerd Fonts
    function getAppIcon(rawId) {
        let idLower = rawId.toLowerCase();
        if (idLower.indexOf("amberol") !== -1) return "󰎈";
        if (idLower.indexOf("brave") !== -1) return "󰖟";
        if (idLower.indexOf("spotify") !== -1) return "󰓇";
        if (idLower.indexOf("firefox") !== -1) return "󰈹";
        if (idLower.indexOf("chrome") !== -1 || idLower.indexOf("chromium") !== -1) return "󰊯";
        if (idLower.indexOf("vlc") !== -1) return "󰕼";
        return "󰎆";
    }

    // Media action dispatcher
    function triggerAction(action) {
        let pFlag = rootScope.fullPlayerId !== "" ? ["-p", rootScope.fullPlayerId] : [];
        if (action === "next" && rootScope.canGoNext) {
            Quickshell.execDetached(["playerctl", ...pFlag, "next"]);
        } else if (action === "previous" && rootScope.canGoPrevious) {
            Quickshell.execDetached(["playerctl", ...pFlag, "previous"]);
        } else if (action === "play-pause") {
            Quickshell.execDetached(["playerctl", ...pFlag, "play-pause"]);
        }
    }

    // Periodic capability poller via D-Bus properties
    Process {
        id: capabilityPoller
        running: false

        stdout: SplitParser {
            onRead: data => {
                let line = data.trim();
                if (!line) return;
                let parts = line.split(":::");
                if (parts.length >= 2) {
                    rootScope.canGoNext = (parts[0] === "true");
                    rootScope.canGoPrevious = (parts[1] === "true");
                }
            }
        }
    }

    Timer {
        id: capabilityTimer
        interval: 1000
        repeat: true
        running: rootScope.fullPlayerId !== ""
        onTriggered: {
            if (rootScope.fullPlayerId !== "") {
                capabilityPoller.command = [
                    "bash", "-c",
                    "NEXT=$(busctl --user get-property org.mpris.MediaPlayer2." + rootScope.fullPlayerId + " /org/mpris/MediaPlayer2 org.mpris.MediaPlayer2.Player CanGoNext 2>/dev/null | awk '{print $2}'); " +
                    "PREV=$(busctl --user get-property org.mpris.MediaPlayer2." + rootScope.fullPlayerId + " /org/mpris/MediaPlayer2 org.mpris.MediaPlayer2.Player CanGoPrevious 2>/dev/null | awk '{print $2}'); " +
                    "echo \"${NEXT:-false}:::${PREV:-false}\""
                ];
                capabilityPoller.running = true;
            }
        }
    }

    // Continuous MPRIS metadata stream
    Process {
        id: mprisWatcher
        command: [
            "playerctl", "--follow", "metadata",
            "--format", "{{status}}:::{{xesam:title}}:::{{xesam:artist}}:::{{mpris:artUrl}}:::{{playerName}}"
        ]
        running: true

        stdout: SplitParser {
            onRead: data => {
                let line = data.trim();
                if (!line) return;
                let parts = line.split(":::");
                if (parts.length >= 3) {
                    let oldTitle = rootScope.songTitle;
                    rootScope.playbackStatus = parts[0] ? parts[0] : "Stopped";
                    rootScope.songTitle = parts[1] ? parts[1] : "Unknown Title";
                    rootScope.songArtist = parts[2] ? parts[2] : "";
                    rootScope.artUrl = (parts.length >= 4 && parts[3]) ? parts[3] : "";
                    let rawPlayer = (parts.length >= 5 && parts[4]) ? parts[4] : "media";
                    rootScope.fullPlayerId = rawPlayer;
                    rootScope.playerName = rootScope.getNormalizedAppName(rawPlayer);

                    // Trigger popup on song transition
                    if (oldTitle !== rootScope.songTitle && rootScope.songTitle !== "No media playing") {
                        rootScope.popupVisible = true;
                        autoHideTimer.restart();
                    }
                }
            }
        }
    }

    // ========================================================
    // 1. Taskbar Capsule Widget (Perfect Vertical Center Alignment)
    // ========================================================
        PanelWindow {
        id: capsuleWindow

        anchors {
            top: true
            right: true
        }

        // Exact vertical center alignment based on Noctalia compact density (barHeight 25, frame 6, padding 3)
        margins {
            top: 18
            right: 320
        }

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "noctalia-flyout-capsule"
        exclusionMode: ExclusionMode.Ignore

        color: "transparent"
        implicitHeight: 23
        implicitWidth: capsulePill.implicitWidth

        Rectangle {
            id: capsulePill
            implicitHeight: 23
            implicitWidth: contentRow.implicitWidth + 14
            radius: 9999
            // shadcn Dark Zinc #09090b + Specular rim border
            color: Qt.rgba(9 / 255, 9 / 255, 11 / 255, 0.88)
            border.color: Qt.rgba(1.0, 1.0, 1.0, 0.12)
            border.width: 1

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    rootScope.popupVisible = !rootScope.popupVisible;
                    if (rootScope.popupVisible) autoHideTimer.restart();
                }
            }

            RowLayout {
                id: contentRow
                anchors.centerIn: parent
                spacing: 6

                // Thumbnail Cover Art
                Rectangle {
                    width: 16
                    height: 16
                    radius: 3
                    color: Qt.rgba(24 / 255, 24 / 255, 27 / 255, 0.85)
                    border.color: Qt.rgba(1.0, 1.0, 1.0, 0.18)
                    border.width: 1
                    clip: true
                    Layout.alignment: Qt.AlignVCenter

                    Image {
                        anchors.fill: parent
                        source: rootScope.artUrl
                        fillMode: Image.PreserveAspectCrop
                        visible: rootScope.artUrl !== ""
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "󰎆"
                        color: rootScope.isPlaying ? "#fafafa" : "#71717a"
                        font.pixelSize: 9
                        visible: rootScope.artUrl === ""
                    }
                }

                // Marquee Text Label
                Item {
                    id: textContainer
                    implicitWidth: 95
                    implicitHeight: 14
                    clip: true
                    Layout.alignment: Qt.AlignVCenter

                    readonly property string fullLabel: rootScope.songArtist !== ""
                        ? (rootScope.songTitle + " • " + rootScope.songArtist)
                        : rootScope.songTitle

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
                            running: primaryLabel.implicitWidth > textContainer.implicitWidth && rootScope.isPlaying
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

                // Playback Navigation Controls with Dynamic Opacity
                RowLayout {
                    spacing: 2
                    Layout.alignment: Qt.AlignVCenter

                    // Previous Button
                    Rectangle {
                        width: 16
                        height: 16
                        radius: 8
                        opacity: rootScope.canGoPrevious ? 1.0 : 0.28
                        color: (rootScope.canGoPrevious && prevArea.containsMouse) ? Qt.rgba(255, 255, 255, 0.15) : "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: "󰒮"
                            font.pixelSize: 9
                            color: rootScope.canGoPrevious ? (prevArea.containsMouse ? "#fafafa" : "#d4d4d8") : "#71717a"
                        }

                        MouseArea {
                            id: prevArea
                            anchors.fill: parent
                            hoverEnabled: rootScope.canGoPrevious
                            cursorShape: rootScope.canGoPrevious ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: rootScope.triggerAction("previous")
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
                            text: rootScope.isPlaying ? "󰏤" : "󰐊"
                            font.pixelSize: 9
                            color: "#fafafa"
                        }

                        MouseArea {
                            id: playArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: rootScope.triggerAction("play-pause")
                        }
                    }

                    // Next Button
                    Rectangle {
                        width: 16
                        height: 16
                        radius: 8
                        opacity: rootScope.canGoNext ? 1.0 : 0.28
                        color: (rootScope.canGoNext && nextArea.containsMouse) ? Qt.rgba(255, 255, 255, 0.15) : "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: "󰒭"
                            font.pixelSize: 9
                            color: rootScope.canGoNext ? (nextArea.containsMouse ? "#fafafa" : "#d4d4d8") : "#71717a"
                        }

                        MouseArea {
                            id: nextArea
                            anchors.fill: parent
                            hoverEnabled: rootScope.canGoNext
                            cursorShape: rootScope.canGoNext ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: rootScope.triggerAction("next")
                        }
                    }
                }

                // Waveform Audio Spectrum Bars
                Row {
                    id: waveformRow
                    spacing: 2
                    Layout.alignment: Qt.AlignVCenter

                    Repeater {
                        model: [7, 12, 5, 11, 14, 9, 12, 6]
                        Rectangle {
                            width: 2
                            height: rootScope.isPlaying ? modelData : 3
                            radius: 1
                            color: Qt.rgba(250 / 255, 250 / 255, 250 / 255, 0.85)
                            anchors.verticalCenter: parent.verticalCenter

                            SequentialAnimation on height {
                                running: rootScope.isPlaying
                                loops: Animation.Infinite
                                NumberAnimation {
                                    from: 3
                                    to: modelData
                                    duration: 250 + (index * 50)
                                    easing.type: Easing.InOutQuad
                                }
                                NumberAnimation {
                                    from: modelData
                                    to: 3
                                    duration: 250 + (index * 50)
                                    easing.type: Easing.InOutQuad
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // ========================================================
    // 2. Rectangular Popup Card
    // ========================================================
    PanelWindow {
        id: cardWindow
        visible: rootScope.popupVisible

        anchors {
            top: true
            right: true
        }

        margins {
            top: 44
            right: 300
        }

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "noctalia-flyout-card"
        exclusionMode: ExclusionMode.Ignore

        color: "transparent"
        implicitWidth: 320
        implicitHeight: 110

        Rectangle {
            anchors.fill: parent
            radius: 14
            color: Qt.rgba(18 / 255, 18 / 255, 22 / 255, 0.95)
            border.color: Qt.rgba(1.0, 1.0, 1.0, 0.14)
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 14

                // Album Art HD
                Rectangle {
                    width: 78
                    height: 78
                    radius: 8
                    color: Qt.rgba(28 / 255, 28 / 255, 32 / 255, 0.8)
                    border.color: Qt.rgba(1.0, 1.0, 1.0, 0.12)
                    border.width: 1
                    clip: true
                    Layout.alignment: Qt.AlignVCenter

                    Image {
                        anchors.fill: parent
                        source: rootScope.artUrl
                        fillMode: Image.PreserveAspectCrop
                        visible: rootScope.artUrl !== ""
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "󰎆"
                        font.pixelSize: 28
                        color: "#71717a"
                        visible: rootScope.artUrl === ""
                    }
                }

                // Details and Card Controls
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 4

                    Text {
                        text: rootScope.songTitle
                        font.family: "Geist"
                        font.pixelSize: 13
                        font.weight: Font.Bold
                        color: "#ffffff"
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                    Text {
                        text: rootScope.songArtist !== "" ? rootScope.songArtist : "Unknown Artist"
                        font.family: "Geist"
                        font.pixelSize: 11
                        font.weight: Font.Medium
                        color: "#a1a1aa"
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                    Item { implicitHeight: 4 }

                    RowLayout {
                        spacing: 12

                        // Card Previous Button
                        Text {
                            text: "󰒮"
                            font.pixelSize: 14
                            opacity: rootScope.canGoPrevious ? 1.0 : 0.28
                            color: rootScope.canGoPrevious ? (cardPrevArea.containsMouse ? "#ffffff" : "#a1a1aa") : "#52525b"
                            MouseArea {
                                id: cardPrevArea
                                anchors.fill: parent
                                hoverEnabled: rootScope.canGoPrevious
                                cursorShape: rootScope.canGoPrevious ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onClicked: {
                                    rootScope.triggerAction("previous");
                                    autoHideTimer.restart();
                                }
                            }
                        }

                        // Prominent Play/Pause Button
                        Rectangle {
                            width: 32
                            height: 26
                            radius: 6
                            color: rootScope.isPlaying ? "#38bdf8" : Qt.rgba(255, 255, 255, 0.15)

                            Text {
                                anchors.centerIn: parent
                                text: rootScope.isPlaying ? "󰏤" : "󰐊"
                                font.pixelSize: 13
                                color: rootScope.isPlaying ? "#09090b" : "#ffffff"
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    rootScope.triggerAction("play-pause");
                                    autoHideTimer.restart();
                                }
                            }
                        }

                        // Card Next Button
                        Text {
                            text: "󰒭"
                            font.pixelSize: 14
                            opacity: rootScope.canGoNext ? 1.0 : 0.28
                            color: rootScope.canGoNext ? (cardNextArea.containsMouse ? "#ffffff" : "#a1a1aa") : "#52525b"
                            MouseArea {
                                id: cardNextArea
                                anchors.fill: parent
                                hoverEnabled: rootScope.canGoNext
                                cursorShape: rootScope.canGoNext ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onClicked: {
                                    rootScope.triggerAction("next");
                                    autoHideTimer.restart();
                                }
                            }
                        }

                        // Application Badge with Clean Icon & Name
                        RowLayout {
                            spacing: 5
                            Layout.leftMargin: 8

                            Text {
                                text: rootScope.getAppIcon(rootScope.fullPlayerId)
                                font.pixelSize: 13
                                color: "#38bdf8"
                            }

                            Text {
                                text: rootScope.playerName.toUpperCase()
                                font.family: "Geist"
                                font.pixelSize: 10
                                font.weight: Font.Bold
                                color: "#71717a"
                            }
                        }
                    }
                }
            }
        }
    }
}
