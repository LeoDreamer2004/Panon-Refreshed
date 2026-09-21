import QtQuick
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore

PlasmoidItem {
    id: root

    property var spectrum: []
    property real audioLevel: 0.0
    property string backendError: ""
    property string trackTitle: ""
    property string mediaProvider: ""
    property string trackArtist: ""
    property string currentLyric: ""
    property string previousLyric: ""
    property string nextLyric: ""
    property string artUrl: ""
    property var coverColors: ["#8b5cf6", "#22d3ee", "#f472b6"]
    property bool mediaPlaying: false
    property bool mediaActive: false
    property string wallpaperUrl: ""
    property bool lyricsAvailable: false
    property int currentLyricIndex: -1
    property var lyricTiming: ({})
    property string lyricModelId: ""
    property var lyricWindow: ({
        "hasTranslation": false,
        "entries": [],
        "currentIndex": -1,
        "modelId": ""
    })

    compactRepresentation: PanelView {
        spectrum: root.spectrum
        audioLevel: root.audioLevel
        backendError: root.backendError
        trackTitle: root.trackTitle
        trackArtist: root.trackArtist
        currentLyric: root.currentLyric
        mediaPlaying: root.mediaPlaying
        lyricsAvailable: root.lyricsAvailable
        lyricTiming: root.lyricTiming
        lyricWords: root.currentLyricIndex >= 0 && root.lyricWindow.entries
                    ? (root.lyricWindow.entries[root.currentLyricIndex] || {}).words || [] : []
        lyricKey: root.lyricModelId + ":" + root.currentLyricIndex
    }
    fullRepresentation: DesktopView {
        lyricFont: plasmoid.configuration.lyricFont
        mediaProvider: root.mediaProvider
        spectrum: root.spectrum
        audioLevel: root.audioLevel
        backendError: root.backendError
        trackTitle: root.trackTitle
        trackArtist: root.trackArtist
        currentLyric: root.currentLyric
        previousLyric: root.previousLyric
        nextLyric: root.nextLyric
        artUrl: root.artUrl
        colors: root.coverColors
        mediaActive: root.mediaActive
        wallpaperUrl: root.wallpaperUrl
        wallpaperInfo: backend.controlState.wallpaper || ({})
        blurStrength: plasmoid.configuration.desktopBlurStrength
        overlayStrength: plasmoid.configuration.desktopOverlayStrength
        borderWidth: plasmoid.configuration.desktopBorderWidth
        showTranslation: plasmoid.configuration.showTranslation
        showFurigana: plasmoid.configuration.showFurigana
        onFuriganaToggleRequested: {
            plasmoid.configuration.showFurigana = !plasmoid.configuration.showFurigana
        }
        onTranslationToggleRequested: {
            plasmoid.configuration.showTranslation = !plasmoid.configuration.showTranslation
        }
        mediaPlaying: root.mediaPlaying
        lyricsAvailable: root.lyricsAvailable
        lyricWindow: root.lyricWindow
        currentLyricIndex: root.currentLyricIndex
        mediaPosition: backend.controlState.position || 0
        mediaDuration: backend.controlState.duration || 0
        canSeek: Boolean(backend.controlState.canSeek)
        canGoPrevious: Boolean(backend.controlState.canGoPrevious)
        canGoNext: Boolean(backend.controlState.canGoNext)
        canPlayPause: Boolean(backend.controlState.canPlayPause)
        onPreviousRequested: backend.command("previous")
        onPlayPauseRequested: backend.command("playPause")
        onNextRequested: backend.command("next")
        onSeekRequested: function(position) { backend.command("seek", position) }
    }

    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground

    WsConnection {
        id: backend
        screenId: root.screen
        onSpectrumReceived: function(values, level) {
            root.backendError = ""
            root.spectrum = values
            root.audioLevel = level
        }
        onBackendFailed: function(message) {
            root.backendError = message
        }
        onMediaUpdated: function(title, artist, lyric, previousLyric, nextLyric,
                                 artUrl, colors, playing, active,
                                 wallpaperUrl, available, lyricWindow, provider) {
            root.mediaProvider = provider
            root.trackTitle = title
            root.trackArtist = artist
            root.currentLyric = lyric
            root.previousLyric = previousLyric
            root.nextLyric = nextLyric
            root.artUrl = artUrl
            root.coverColors = colors
            root.mediaPlaying = playing
            root.mediaActive = active
            root.wallpaperUrl = wallpaperUrl
            root.lyricsAvailable = available
            const incomingModelId = lyricWindow.modelId || ""
            if (incomingModelId !== root.lyricModelId) {
                root.lyricModelId = incomingModelId
                root.lyricWindow = lyricWindow
            }
            root.currentLyricIndex = typeof lyricWindow.currentIndex === "number"
                    ? lyricWindow.currentIndex : -1
            root.lyricTiming = lyricWindow.timing || ({})
        }
    }
}
