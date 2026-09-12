import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import org.kde.plasma.plasma5support as Plasma5Support
import "../utils.js" as Utils

KCM.SimpleKCM {
    id: root
    property string cfg_pythonExecutable
    property string cfg_audioSource
    property string cfg_preferredPlayer
    property alias cfg_neteaseAppPath: neteaseApp.text
    property alias cfg_neteaseElectron: neteaseElectron.text
    property alias cfg_qqmusicAppPath: qqmusicApp.text
    property alias cfg_qqmusicElectron: qqmusicElectron.text
    property var cfg_pythonExecutableDefault
    property var cfg_audioSourceDefault
    property var cfg_preferredPlayerDefault
    property var cfg_neteaseAppPathDefault
    property var cfg_neteaseElectronDefault
    property var cfg_qqmusicAppPathDefault
    property var cfg_qqmusicElectronDefault

    // Plasma supplies all schema properties when creating a settings page.
    property string cfg_lyricFont
    property bool cfg_showTranslation
    property bool cfg_showFurigana
    property int cfg_fps
    property int cfg_theme
    property int cfg_barCount
    property int cfg_sensitivity
    property int cfg_decay
    property bool cfg_mirror
    property bool cfg_autoHide
    property bool cfg_animateAutoHiding
    property bool cfg_autoExtend
    property int cfg_preferredWidth
    property int cfg_panelSpectrumWidth
    property int cfg_desktopBlurStrength
    property int cfg_desktopOverlayStrength
    property var cfg_lyricFontDefault
    property var cfg_showTranslationDefault
    property var cfg_showFuriganaDefault
    property var cfg_fpsDefault
    property var cfg_themeDefault
    property var cfg_barCountDefault
    property var cfg_sensitivityDefault
    property var cfg_decayDefault
    property var cfg_mirrorDefault
    property var cfg_autoHideDefault
    property var cfg_animateAutoHidingDefault
    property var cfg_autoExtendDefault
    property var cfg_preferredWidthDefault
    property var cfg_panelSpectrumWidthDefault
    property var cfg_desktopBlurStrengthDefault
    property var cfg_desktopOverlayStrengthDefault

    property string command: ""
    property string operation: ""
    property var targetField: null
    property var runtimeField: null
    property bool runtimeOnly: false
    property string provider: ""
    property string neteaseNotice: ""
    property string qqmusicNotice: ""
    property int requestId: 0

    function detect(kind, field, runtime, onlyRuntime) {
        if (command) return
        targetField = field
        runtimeField = runtime
        runtimeOnly = Boolean(onlyRuntime)
        field.errorMessage = ""
        runtime.errorMessage = ""
        operation = "detect"
        command = Utils.chdir_scripts_root(Qt.resolvedUrl("../../scripts/"))
                + "exec " + Utils.shellQuote(cfg_pythonExecutable || "python3")
                + " -m panon.backend.detect " + Utils.shellQuote(kind)
                + (runtimeOnly ? " --app-path=" + Utils.shellQuote(field.text) : "")
                + " # request " + (++requestId)
    }
    function fillRuntime(value, field, runtime) {
        const app = field.candidates.find(candidate => candidate.value === value)
        if (app) runtime.text = app.electron || ""
    }
    function install(kind, app, runtime) {
        if (command || !app.text || !runtime.text) return
        operation = "install"
        provider = kind
        if (kind === "netease") neteaseNotice = ""
        else qqmusicNotice = ""
        command = "exec " + Utils.shellQuote(cfg_pythonExecutable || "python3") + " "
                + Utils.shellQuote(Utils.localPath(Qt.resolvedUrl("../../../integrations/" + kind + "/install-launcher.py")))
                + " --app-path=" + Utils.shellQuote(app.text) + " --electron=" + Utils.shellQuote(runtime.text)
                + " # request " + (++requestId)
    }
    Plasma5Support.DataSource {
        engine: "executable"
        connectedSources: root.command ? [root.command] : []
        onNewData: function(source, data) {
            if (source !== root.command || data["exit code"] === undefined) return
            root.command = ""
            if (root.operation === "install") {
                const notice = data["exit code"] === 0
                    ? i18nd("plasma_applet_panon", "Launcher updated. Restart the player using its Panon menu entry.")
                    : i18nd("plasma_applet_panon", "Launcher update failed: %1", data.stderr || data.stdout || String(data["exit code"]))
                if (root.provider === "netease") root.neteaseNotice = notice
                else root.qqmusicNotice = notice
                return
            }
            const errorField = root.runtimeOnly ? root.runtimeField : root.targetField
            try {
                const result = JSON.parse(data.stdout || "{}")
                if (data["exit code"] !== 0 || result.error) throw new Error(result.error || data.stderr || "Detection failed")
                if (root.runtimeOnly) {
                    const app = (result.candidates || []).find(c => c.value === result.selected)
                    if (app && app.electron) root.runtimeField.text = app.electron
                    else errorField.errorMessage = i18nd("plasma_applet_panon", "No compatible candidate found; existing values were kept.")
                } else {
                    root.targetField.applyResult(result)
                    if (!(result.candidates || []).length)
                        errorField.errorMessage = i18nd("plasma_applet_panon", "No compatible candidate found; existing values were kept.")
                }
            } catch (error) {
                errorField.errorMessage = i18nd("plasma_applet_panon", "Detection failed: %1", String(error))
            }
        }
    }
    Kirigami.FormLayout {
        QQC2.Label {
            text: i18nd("plasma_applet_panon", "How to enable player integration")
            font.bold: true
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
        }
        QQC2.Label {
            text: i18nd("plasma_applet_panon", "1. Auto-detect the application package and Electron runtime, or fill them manually.\n2. Click Update integration launcher to create a separate .desktop entry in your user applications directory ($XDG_DATA_HOME/applications, normally ~/.local/share/applications). The original launcher and player files are unchanged.\n3. Fully quit the player, including its tray process, then open the new NetEase/QQ Music (Panon) entry from the application menu. The original entry does not enable the lyrics bridge.\n4. Apply saves these fields only; it does not update the .desktop entry. After moving Panon or changing paths, update the launcher again.")
            textFormat: Text.PlainText
            wrapMode: Text.WordWrap
            Layout.preferredWidth: 520
            Layout.fillWidth: true
        }
        Kirigami.Separator { Kirigami.FormData.isSection: true }
        DetectedField {
            id: neteaseApp
            Kirigami.FormData.label: i18nd("plasma_applet_panon", "NetEase application package:")
            busy: Boolean(root.command)
            onDetectRequested: root.detect("netease", neteaseApp, neteaseElectron)
            onDetected: function(value) { root.fillRuntime(value, neteaseApp, neteaseElectron) }
        }
        DetectedField {
            id: neteaseElectron
            Kirigami.FormData.label: i18nd("plasma_applet_panon", "NetEase Electron runtime:")
            busy: Boolean(root.command)
            onDetectRequested: root.detect("netease", neteaseApp, neteaseElectron, true)
        }
        QQC2.Button {
            text: i18nd("plasma_applet_panon", "Update NetEase integration launcher")
            enabled: !root.command && neteaseApp.text.length > 0 && neteaseElectron.text.length > 0
            onClicked: root.install("netease", neteaseApp, neteaseElectron)
        }
        QQC2.Label {
            visible: root.neteaseNotice.length > 0
            text: root.neteaseNotice
            textFormat: Text.PlainText
            wrapMode: Text.WordWrap
            Layout.preferredWidth: 460
        }
        Kirigami.Separator { Kirigami.FormData.isSection: true }
        DetectedField {
            id: qqmusicApp
            Kirigami.FormData.label: i18nd("plasma_applet_panon", "QQ Music application package:")
            busy: Boolean(root.command)
            onDetectRequested: root.detect("qqmusic", qqmusicApp, qqmusicElectron)
            onDetected: function(value) { root.fillRuntime(value, qqmusicApp, qqmusicElectron) }
        }
        DetectedField {
            id: qqmusicElectron
            Kirigami.FormData.label: i18nd("plasma_applet_panon", "QQ Music Electron runtime:")
            busy: Boolean(root.command)
            onDetectRequested: root.detect("qqmusic", qqmusicApp, qqmusicElectron, true)
        }
        QQC2.Button {
            text: i18nd("plasma_applet_panon", "Update QQ Music integration launcher")
            enabled: !root.command && qqmusicApp.text.length > 0 && qqmusicElectron.text.length > 0
            onClicked: root.install("qqmusic", qqmusicApp, qqmusicElectron)
        }
        QQC2.Label {
            visible: root.qqmusicNotice.length > 0
            text: root.qqmusicNotice
            textFormat: Text.PlainText
            wrapMode: Text.WordWrap
            Layout.preferredWidth: 460
        }
    }
}
