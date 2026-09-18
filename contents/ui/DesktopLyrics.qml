import QtQuick
import "Fonts.js" as Fonts
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Item {
    id: root

    property string trackTitle: ""
    property string trackArtist: ""
    property string currentLyric: ""
    property var lyricWindow: ({
        "hasTranslation": false,
        "entries": [],
        "currentIndex": -1
    })
    property int currentLyricIndex: -1
    property var colors: ["#8b5cf6", "#22d3ee", "#f472b6"]
    property bool lyricsAvailable: false
    property bool mediaPlaying: false
    property real mediaPosition: 0
    property bool showTranslation: true
    property bool showFurigana: true
    property bool canSeek: false
    signal seekRequested(real position)
    property bool browsing: false
    property int pendingSeekIndex: -1

    function browse() {
        browsing = true
        resumeTimer.restart()
    }

    function followPlayback() {
        resumeTimer.stop()
        lyricList.cancelFlick()
        pendingSeekIndex = -1
        browsing = false
        if (currentLyricIndex >= 0)
            lyricList.positionViewAtIndex(currentLyricIndex, ListView.Center)
    }

    onCurrentLyricIndexChanged: {
        if (pendingSeekIndex >= 0 && pendingSeekIndex === currentLyricIndex)
            followPlayback()
    }
    onLyricEntriesChanged: {
        pendingSeekIndex = -1
        browsing = false
        resumeTimer.stop()
    }

    Timer {
        id: resumeTimer
        interval: 5000
        onTriggered: {
            if (lyricList.moving || lyricList.dragging) restart()
            else root.followPlayback()
        }
    }

    Timer {
        id: scrollBarTimer
        interval: 1400
    }

    readonly property color primaryColor: colors && colors.length > 0
                                                  ? colors[0] : "#8b5cf6"
    property string preferredFont: ""
    readonly property string originalFontFamily: Fonts.select(preferredFont, Qt.fontFamilies(), Qt.application.font.family)
    readonly property bool translationAvailable: Boolean(
                                                lyricWindow
                                                && lyricWindow.hasTranslation)
    readonly property bool hasTranslation: showTranslation && translationAvailable
    readonly property var lyricEntries: lyricWindow && lyricWindow.entries
                                                ? lyricWindow.entries : []

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Kirigami.Units.largeSpacing
        spacing: 0

        QQC2.Label {
            text: root.mediaPlaying ? qsTr("NOW PLAYING") : qsTr("PAUSED")
            color: "#e2e5ef"
            font.pixelSize: 10
            font.weight: Font.DemiBold
            font.letterSpacing: 2.4
            opacity: 0.82
        }

        QQC2.Label {
            Layout.fillWidth: true
            Layout.topMargin: 7
            text: root.trackTitle || qsTr("等待音乐")
            color: "#f7f8fc"
            font.family: root.originalFontFamily
            font.pixelSize: 24
            font.weight: Font.DemiBold
            elide: Text.ElideRight
        }

        QQC2.Label {
            Layout.fillWidth: true
            Layout.topMargin: 1
            text: root.trackArtist || qsTr("Panon · Chromatic Radial")
            color: "#d7dae5"
            font.pixelSize: 13
            elide: Text.ElideRight
        }

        Item { Layout.preferredHeight: 12 }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop {
                    position: 0
                    color: Qt.rgba(root.primaryColor.r, root.primaryColor.g,
                                   root.primaryColor.b, 0.82)
                }
                GradientStop { position: 1; color: "transparent" }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.topMargin: 8
            clip: true

            ListView {
                id: lyricList
                objectName: "lyricList"
                anchors.fill: parent
                visible: root.lyricsAvailable && root.lyricEntries.length > 0
                clip: true
                interactive: true
                layer.enabled: GraphicsInfo.api !== GraphicsInfo.Software
                layer.effect: ShaderEffect {
                    property real fadeSize: Math.min(0.12, 24 / Math.max(1, lyricList.height))
                    fragmentShader: Qt.resolvedUrl("shaders/lyric-fade.frag.qsb")
                }
                reuseItems: true
                cacheBuffer: height
                spacing: root.hasTranslation ? 3 : 5
                model: root.lyricEntries
                currentIndex: root.browsing ? -1 : root.currentLyricIndex
                highlightRangeMode: root.browsing ? ListView.NoHighlightRange : ListView.StrictlyEnforceRange
                preferredHighlightBegin: height * 0.34
                preferredHighlightEnd: height * 0.66
                highlightMoveDuration: 430
                highlightMoveVelocity: -1
                boundsBehavior: Flickable.StopAtBounds
                onDraggingChanged: {
                    if (dragging) root.browse()
                }
                onMovementEnded: {
                    if (root.browsing) resumeTimer.restart()
                }

                QQC2.ScrollBar.vertical: QQC2.ScrollBar {
                    id: lyricScrollBar
                    objectName: "lyricScrollBar"
                    policy: QQC2.ScrollBar.AlwaysOn
                    // Draw only the thumb, without the theme's track/divider.
                    background: null
                    padding: 0
                    implicitWidth: 5
                    opacity: size < 1 && (scrollBarTimer.running || pressed) ? 1 : 0
                    visible: opacity > 0
                    contentItem: Rectangle {
                        implicitWidth: 5
                        implicitHeight: 24
                        radius: width / 2
                        color: lyricScrollBar.pressed ? "#bfffffff" : "#65ffffff"
                    }
                    Behavior on opacity { NumberAnimation { duration: 160 } }
                    onPressedChanged: {
                        if (pressed) root.browse()
                        else if (root.browsing) {
                            resumeTimer.restart()
                            scrollBarTimer.restart()
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    z: 2
                    acceptedButtons: Qt.NoButton
                    onWheel: function(wheel) {
                        root.browse()
                        scrollBarTimer.restart()
                        wheel.accepted = false
                    }
                }

                delegate: Item {
                    id: lyricDelegate
                    required property var modelData
                    required property int index

                    readonly property bool isCurrent: index === root.currentLyricIndex
                    readonly property bool seekable: root.canSeek
                        && typeof modelData.timestamp === "number" && modelData.timestamp >= 0
                    width: ListView.view.width
                    height: lyricColumn.implicitHeight + (isCurrent ? 12 : 5)
                    opacity: isCurrent ? 1.0
                                       : (index < root.currentLyricIndex ? 0.68 : 0.56)

                    Behavior on opacity {
                        NumberAnimation { duration: 260; easing.type: Easing.OutQuad }
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: 5
                        visible: hover.hovered && lyricDelegate.seekable
                        color: "#18ffffff"
                    }

                    HoverHandler {
                        id: hover
                        cursorShape: lyricDelegate.seekable ? Qt.PointingHandCursor : Qt.ArrowCursor
                    }
                    TapHandler {
                        enabled: lyricDelegate.seekable
                        acceptedButtons: Qt.LeftButton
                        gesturePolicy: TapHandler.DragThreshold
                        onPressedChanged: {
                            if (pressed) root.browse()
                        }
                        onTapped: {
                            root.pendingSeekIndex = lyricDelegate.index
                            root.seekRequested(lyricDelegate.modelData.timestamp)
                            if (lyricDelegate.isCurrent) root.followPlayback()
                        }
                    }

                    Column {
                        id: lyricColumn
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: isCurrent && root.hasTranslation ? 1 : 0

                        QQC2.Label {
                            width: parent.width
                            visible: !rubyLine.visible
                            text: lyricDelegate.modelData.text || ""
                            color: lyricDelegate.isCurrent ? "#ffffff" : "#d5d8e3"
                            font.family: root.originalFontFamily
                            font.pixelSize: lyricDelegate.isCurrent ? 21
                                             : (root.hasTranslation ? 14 : 15)
                            font.weight: lyricDelegate.isCurrent ? Font.Bold : Font.Normal
                            wrapMode: Text.WordWrap
                        }

                        RubyLyric {
                            id: rubyLine
                            width: parent.width
                            visible: words.length > 0 || (showReadings && segments.some(part => Boolean(part.reading)))
                            segments: lyricDelegate.modelData.ruby && lyricDelegate.modelData.ruby.length
                                      ? lyricDelegate.modelData.ruby : [{text: lyricDelegate.modelData.text || "", reading: ""}]
                            words: lyricDelegate.modelData.words || []
                            position: lyricDelegate.isCurrent ? root.mediaPosition : 0
                            karaoke: lyricDelegate.isCurrent && words.length > 0
                            showReadings: root.showFurigana && segments.some(part => Boolean(part.reading))
                            pixelSize: lyricDelegate.isCurrent ? 21 : (root.hasTranslation ? 14 : 15)
                            emphasized: lyricDelegate.isCurrent
                            textColor: lyricDelegate.isCurrent ? "#ffffff" : "#d5d8e3"
                            fontFamily: root.originalFontFamily
                        }

                        QQC2.Label {
                            width: parent.width
                            visible: root.hasTranslation && text.length > 0
                            text: lyricDelegate.modelData.translation || ""
                            color: lyricDelegate.isCurrent ? "#eef0f7" : "#c5c9d7"
                            font.pixelSize: lyricDelegate.isCurrent ? 20 : 14
                            font.weight: lyricDelegate.isCurrent ? Font.Medium : Font.Normal
                            wrapMode: Text.WordWrap
                            opacity: lyricDelegate.isCurrent ? 0.9 : 0.76
                        }
                    }
                }
            }

            QQC2.Button {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                visible: root.browsing
                text: i18nd("plasma_applet_panon", "Return to current lyric")
                onClicked: root.followPlayback()
            }

            QQC2.Label {
                anchors.centerIn: parent
                width: parent.width
                visible: !lyricList.visible
                text: root.trackTitle ? (root.lyricWindow.instrumental ? qsTr("纯音乐 沉浸聆听")
                                        : i18nd("plasma_applet_panon", "No synchronized lyrics"))
                                      : qsTr("播放音乐后，色彩将随封面苏醒")
                color: "#eef0f7"
                font.pixelSize: 16
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                opacity: 0.82
            }
        }
    }
}
