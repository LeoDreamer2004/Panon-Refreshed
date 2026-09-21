import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import QtQuick.Window
import org.kde.kirigami as Kirigami

Item {
    id: root

    property var spectrum: []
    property real audioLevel: 0.0
    property string backendError: ""
    property string trackTitle: ""
    property string lyricFont: ""
    property string mediaProvider: ""
    property string trackArtist: ""
    property string currentLyric: ""
    property string previousLyric: ""
    property string nextLyric: ""
    property var lyricWindow: ({
        "hasTranslation": false,
        "entries": [],
        "currentIndex": -1
    })
    property int currentLyricIndex: -1
    property bool showTranslation: true
    property bool showFurigana: true
    signal furiganaToggleRequested()
    signal translationToggleRequested()
    property string artUrl: ""
    property var colors: ["#8b5cf6", "#22d3ee", "#f472b6"]
    property bool mediaPlaying: false
    property bool mediaActive: false
    property bool displayActive: false
    property string wallpaperUrl: ""
    property var wallpaperInfo: ({})
    property int blurStrength: 100
    property int overlayStrength: 70
    property int borderWidth: 1

    function overlayAlpha(defaultAlpha) {
        const strength = Math.max(0, Math.min(100, overlayStrength)) / 100
        // Preserve the existing gradient at 70%, with transparent/opaque endpoints.
        return strength <= 0.7 ? defaultAlpha * strength / 0.7
             : defaultAlpha + (1 - defaultAlpha) * (strength - 0.7) / 0.3
    }
    property bool lyricsAvailable: false
    property real mediaPosition: 0
    property real mediaDuration: 0
    property bool canSeek: false
    property bool canGoPrevious: false
    property bool canGoNext: false
    property bool canPlayPause: false

    signal previousRequested()
    signal playPauseRequested()
    signal nextRequested()
    signal seekRequested(real position)

    property color primaryColor: colors && colors.length > 0 ? colors[0] : "#8b5cf6"
    property color secondaryColor: colors && colors.length > 1 ? colors[1] : "#22d3ee"
    property color tertiaryColor: colors && colors.length > 2 ? colors[2] : "#f472b6"
    Behavior on primaryColor { ColorAnimation { duration: 600; easing.type: Easing.InOutCubic } }
    Behavior on secondaryColor { ColorAnimation { duration: 600; easing.type: Easing.InOutCubic } }
    Behavior on tertiaryColor { ColorAnimation { duration: 600; easing.type: Easing.InOutCubic } }
    readonly property var displayColors: [primaryColor, secondaryColor, tertiaryColor]
    readonly property real gaussianRadius: blurStrength <= 0
                                                   ? 0
                                                   : 4 + 28 * blurStrength / 100.0
    property real globalX: 0
    property real globalY: 0

    property real revealProgress: displayActive ? 1.0 : 0.0
    visible: displayActive || revealProgress > 0.0
    enabled: displayActive
    opacity: revealProgress
    scale: 0.975 + 0.025 * revealProgress
    transformOrigin: Item.Center

    Behavior on revealProgress {
        NumberAnimation {
            duration: root.displayActive ? 420 : 300
            easing.type: Easing.InOutCubic
        }
    }

    onMediaActiveChanged: {
        if (mediaActive) {
            delayedHide.stop()
            displayActive = true
        } else if (displayActive) {
            delayedHide.restart()
        }
    }

    Component.onCompleted: {
        displayActive = mediaActive
        updateGlobalPosition()
    }

    Timer {
        id: delayedHide
        interval: 1800
        repeat: false
        onTriggered: {
            if (!root.mediaActive) {
                root.displayActive = false
            }
        }
    }

    function updateGlobalPosition() {
        // Ignore our entrance scale: the wallpaper crop must not drift or
        // invalidate the cached blur while the panel is fading in/out.
        const point = root.parent ? root.parent.mapToGlobal(root.x, root.y)
                                  : root.mapToGlobal(0, 0)
        globalX = point.x - Screen.virtualX
        globalY = point.y - Screen.virtualY
    }

    Timer {
        interval: 1000
        running: root.visible
        repeat: true
        triggeredOnStart: true
        onTriggered: root.updateGlobalPosition()
    }

    implicitWidth: 760
    implicitHeight: 360
    Layout.minimumWidth: 560
    Layout.minimumHeight: 280
    Layout.preferredWidth: 760
    Layout.preferredHeight: 360
    Loader {
        id: wallpaperEffect
        anchors.fill: parent
        anchors.margins: 3
        active: root.wallpaperUrl.length > 0 && root.blurStrength > 0
        source: Qt.resolvedUrl("BlurredWallpaper.qml")
        onLoaded: {
            item.wallpaperUrl = Qt.binding(() => root.wallpaperUrl)
            item.screenWidth = Qt.binding(() => root.Screen.width)
            item.screenHeight = Qt.binding(() => root.Screen.height)
            item.offsetX = Qt.binding(() => root.globalX + 3)
            item.offsetY = Qt.binding(() => root.globalY + 3)
            item.blurRadius = Qt.binding(() => root.gaussianRadius)
            item.fillMode = Qt.binding(() => root.wallpaperInfo.fillMode === undefined ? Image.PreserveAspectCrop : root.wallpaperInfo.fillMode)
            item.backgroundColor = Qt.binding(() => root.wallpaperInfo.color || "#000000")
        }
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: 3
        radius: 22
        color: "#20070a12"
        border.width: Math.max(0, Math.min(8, root.borderWidth))
        border.color: Qt.rgba(root.primaryColor.r, root.primaryColor.g,
                              root.primaryColor.b, 0.64)
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop {
                position: 0
                color: Qt.rgba(0.025 + root.primaryColor.r * 0.24,
                               0.03 + root.primaryColor.g * 0.24,
                               0.045 + root.primaryColor.b * 0.24,
                               root.overlayAlpha(0.62))
            }
            GradientStop {
                position: 0.58
                color: Qt.rgba(0.025 + root.secondaryColor.r * 0.18,
                               0.03 + root.secondaryColor.g * 0.18,
                               0.045 + root.secondaryColor.b * 0.18,
                               root.overlayAlpha(0.70))
            }
            GradientStop {
                position: 1
                color: Qt.rgba(0.025 + root.tertiaryColor.r * 0.16,
                               0.03 + root.tertiaryColor.g * 0.16,
                               0.045 + root.tertiaryColor.b * 0.16,
                               root.overlayAlpha(0.72))
            }
        }
    }

    Item {
        id: providerBadge
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.margins: 16
        width: 30
        height: 30
        z: 2
        visible: root.mediaProvider === "netease" || root.mediaProvider === "qqmusic"
        readonly property string providerName: root.mediaProvider === "netease" ? "网易云音乐" : "QQ 音乐"
        Accessible.role: Accessible.Graphic
        Accessible.name: providerName

        Kirigami.Icon {
            anchors.centerIn: parent
            width: 22
            height: 22
            source: root.mediaProvider === "netease" ? Qt.resolvedUrl("../images/netease-circle.svg") : Qt.resolvedUrl("../images/qqmusic.svg")
        }
        HoverHandler { id: providerHover }
        QQC2.ToolTip.visible: providerHover.hovered
        QQC2.ToolTip.text: providerName
    }

    Item {
        id: contentArea
        anchors.fill: parent
        anchors.margins: 14

        Item {
            id: leftPane
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: Math.max(0, (contentArea.width - 12) * 0.44)

            ColumnLayout {
                anchors.fill: parent
                spacing: 4

                RadialAlbum {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spectrum: root.spectrum
                    audioLevel: root.audioLevel
                    artUrl: root.artUrl
                    colors: root.displayColors
                    playing: root.mediaPlaying
                }

                PlaybackControls {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 66
                    colors: root.displayColors
                    mediaPlaying: root.mediaPlaying
                    mediaPosition: root.mediaPosition
                    mediaDuration: root.mediaDuration
                    canSeek: root.canSeek
                    canGoPrevious: root.canGoPrevious
                    canGoNext: root.canGoNext
                    canPlayPause: root.canPlayPause
                    showTranslation: root.showTranslation
                    showFurigana: root.showFurigana
                    furiganaAvailable: Boolean(root.lyricWindow && root.lyricWindow.hasFurigana)
                    onFuriganaToggleRequested: root.furiganaToggleRequested()
                    translationAvailable: Boolean(root.lyricWindow && root.lyricWindow.hasTranslation)
                    onTranslationToggleRequested: root.translationToggleRequested()
                    onPreviousRequested: root.previousRequested()
                    onPlayPauseRequested: root.playPauseRequested()
                    onNextRequested: root.nextRequested()
                    onSeekRequested: function(position) { root.seekRequested(position) }
                }
            }
        }

        DesktopLyrics {
            preferredFont: root.lyricFont
            anchors.left: leftPane.right
            anchors.leftMargin: 12
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            trackTitle: root.trackTitle
            trackArtist: root.trackArtist
            currentLyric: root.currentLyric
            lyricWindow: root.lyricWindow
            currentLyricIndex: root.currentLyricIndex
            showTranslation: root.showTranslation
            showFurigana: root.showFurigana
            colors: root.displayColors
            lyricsAvailable: root.lyricsAvailable
            mediaPlaying: root.mediaPlaying
            mediaPosition: root.mediaPosition
            canSeek: root.canSeek
            onSeekRequested: function(position) { root.seekRequested(position) }
        }

        QQC2.Label {
            visible: root.backendError.length > 0
            anchors.centerIn: parent
            text: root.backendError
            color: Kirigami.Theme.negativeTextColor
            wrapMode: Text.WordWrap
        }
    }
}
