import QtQuick
import QtWebSockets
import org.kde.plasma.plasma5support as Plasma5Support
import org.kde.plasma.plasmoid
import "utils.js" as Utils

Item {
    id: root

    readonly property var cfg: plasmoid.configuration
    property var activeSocket: null
    property var controlState: ({})
    property int screenId: -1
    property bool visualActive: true
    property bool wantsWallpaper: true
    property var cachedLyrics: ({})
    function sendActivity() {
        if (activeSocket) activeSocket.sendTextMessage(JSON.stringify({token: sessionToken,
            action: "activity", active: visualActive, wallpaper: wantsWallpaper}))
    }
    onVisualActiveChanged: sendActivity()
    onWantsWallpaperChanged: sendActivity()
    function sendScreen() {
        if (activeSocket) activeSocket.sendTextMessage(JSON.stringify({token:sessionToken, action:"screen", screen:screenId}))
    }
    onScreenIdChanged: sendScreen()
    property int retryCount: 0
    property int generation: 0
    property real lastFrameAt: 0
    // Per-launch nonce; not a replacement for the same-user session boundary.
    readonly property string sessionToken: Array.from({length: 8}, () => Math.random().toString(36).slice(2)).join("")

    function command(action, position) {
        if (!activeSocket || !controlState.service) return
        activeSocket.sendTextMessage(JSON.stringify({token: sessionToken, action: action,
            service: controlState.service, owner: controlState.owner,
            trackId: controlState.trackId, position: position}))
    }

    Timer {
        id: restartTimer
        interval: Math.min(30000, 1000 * Math.pow(2, root.retryCount))
        onTriggered: { root.retryCount++; root.generation++ }
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: {
            if (root.lastFrameAt && Date.now() - root.lastFrameAt > 5000) {
                root.controlState = ({})
                root.backendFailed(i18nd("plasma_applet_panon", "Audio backend is not responding"))
            }
        }
    }
    signal spectrumReceived(var values, real level)
    signal mediaUpdated(string title, string artist, string lyric,
                        string previousLyric, string nextLyric,
                        string artUrl, var colors,
                        bool playing, bool mediaActive,
                        string wallpaperUrl, bool lyricsAvailable,
                        var lyricWindow, string provider)
    signal backendFailed(string message)

    WebSocketServer {
        id: server
        host: "127.0.0.1"
        listen: true

        onClientConnected: function(webSocket) {
            let authenticated = false
            webSocket.onTextMessageReceived.connect(function(message) {
                try {
                    if (message.length > 2000000) { webSocket.active = false; return }
                    const payload = JSON.parse(message)
                    if (!authenticated) {
                        if (payload.hello !== root.sessionToken || root.activeSocket) {
                            webSocket.active = false
                            return
                        }
                        authenticated = true
                        root.activeSocket = webSocket
                        root.cachedLyrics = ({})
                        root.sendActivity()
                        root.sendScreen()
                        return
                    }
                    root.lastFrameAt = Date.now()
                    if (payload.idle) return
                    if (payload.media && payload.media.lyricWindow) {
                        const delta = payload.media.lyricWindow
                        if (delta.entries !== undefined) root.cachedLyrics = delta
                        payload.media.lyricWindow = Object.assign({}, root.cachedLyrics, delta)
                    }
                    root.controlState = payload.media || ({})
                    if (payload.error) {
                        root.backendFailed(payload.error)
                    } else {
                        root.spectrumReceived(payload.bands || [], payload.level || 0.0)
                        if (payload.audioError) root.backendFailed(payload.audioError)
                        const media = payload.media || {}
                        root.mediaUpdated(
                            media.title || "",
                            media.artist || "",
                            media.lyric || "",
                            media.previousLyric || "",
                            media.nextLyric || "",
                            media.artUrl || "",
                            media.colors || [],
                            media.playing || false,
                            media.active || false,
                            media.wallpaperUrl || "",
                            media.lyricsAvailable || false,
                            media.lyricWindow || ({
                                "hasTranslation": false,
                                "entries": [],
                                "currentIndex": -1,
                                "modelId": ""
                            }),
                            media.provider || ""
                        )
                    }
                } catch (error) {
                    root.backendFailed(i18n("Invalid data from audio backend"))
                }
            })
            webSocket.statusChanged.connect(function() {
                if (webSocket.status === WebSocket.Closed || webSocket.status === WebSocket.Error) {
                    if (root.activeSocket === webSocket) {
                        root.activeSocket = null
                        root.controlState = ({})
                    }
                }
            })
        }
    }

    readonly property string startBackend: {
        if (server.port === 0) {
            return ""
        }
        return Utils.chdir_scripts_root(Qt.resolvedUrl("../scripts/"))
            + "exec " + Utils.shellQuote(cfg.pythonExecutable || "python3") + " -m panon.backend.client "
            + Utils.shellQuote(server.url)
            + " --fps=" + cfg.fps
            + " --bands=64"
            + " --decay=" + cfg.decay
            + " --token=" + Utils.shellQuote(sessionToken)
            + " --audio-source=" + Utils.shellQuote(cfg.audioSource || "")
            + " --preferred-player=" + Utils.shellQuote(cfg.preferredPlayer || "")
            + " # restart " + generation
    }

    Plasma5Support.DataSource {
        engine: "executable"
        connectedSources: root.startBackend.length > 0 ? [root.startBackend] : []

        onNewData: function(sourceName, data) {
            if (sourceName !== root.startBackend) return
            if (data.stderr && data.stderr.trim().length > 0) {
                console.warn("Panon backend:", data.stderr)
            }
            if (data["exit code"] && data["exit code"] !== 0) {
                root.backendFailed(i18n("Audio backend stopped (exit code %1)", data["exit code"]))
            }
            if (data["exit code"] !== undefined) {
                root.activeSocket = null
                root.controlState = ({})
                if (root.retryCount < 5) restartTimer.restart()
            }
        }
    }
}
