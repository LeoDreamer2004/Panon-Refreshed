import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import org.kde.plasma.plasma5support as Plasma5Support
import "../utils.js" as Utils

KCM.SimpleKCM {
    id: root
    property alias cfg_pythonExecutable: pythonExecutable.text
    property alias cfg_audioSource: audioSource.text
    property alias cfg_preferredPlayer: preferredPlayer.text
    property string cfg_neteaseAppPath
    property string cfg_neteaseElectron
    property string cfg_qqmusicAppPath
    property string cfg_qqmusicElectron
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
    property int cfg_desktopBorderWidth
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
    property var cfg_desktopBorderWidthDefault

    property string command: ""
    property string operation: ""
    property var targetField: null
    property int requestId: 0
    property var dependencyReport: null
    property string dependencyError: ""
    property string dependencyDetails: ""
    property bool dependencyCheckStarted: false

    function showDoctorResult(output, errors) {
        dependencyReport = null
        dependencyError = ""
        dependencyDetails = errors || ""
        try {
            const report = JSON.parse(output)
            if (!Array.isArray(report.checks) || !report.checks.length || typeof report.python !== "string"
                || typeof report.version !== "string" || !report.checks.every(c => c && typeof c.name === "string"
                    && typeof c.ok === "boolean" && typeof c.required === "boolean"))
                throw new Error("Invalid dependency report")
            dependencyReport = report
        } catch (error) {
            dependencyError = errors || String(error)
        }
    }

    function scriptsCommand(python) {
        return Utils.chdir_scripts_root(Qt.resolvedUrl("../../scripts/"))
             + "exec " + Utils.shellQuote(python || "python3")
    }
    function detect(kind, field) {
        if (command) return
        targetField = field
        field.errorMessage = ""
        operation = "detect"
        const python = kind === "python" ? "python3" : (pythonExecutable.text || "python3")
        command = scriptsCommand(python) + " -m panon.backend.detect " + Utils.shellQuote(kind)
                + " # request " + (++requestId)
    }
    Plasma5Support.DataSource {
        engine: "executable"
        connectedSources: root.command ? [root.command] : []
        onNewData: function(source, data) {
            if (source !== root.command || data["exit code"] === undefined) return
            root.command = ""
            if (root.operation === "doctor") {
                root.showDoctorResult(data.stdout || "", data.stderr || "")
                return
            }
            try {
                const result = JSON.parse(data.stdout || "{}")
                if (data["exit code"] !== 0 || result.error) throw new Error(result.error || data.stderr || "Detection failed")
                root.targetField.applyResult(result)
                if (!(result.candidates || []).length)
                    root.targetField.errorMessage = i18nd("plasma_applet_panon", "No compatible candidate found; existing values were kept.")
            } catch (error) {
                root.targetField.errorMessage = i18nd("plasma_applet_panon", "Detection failed: %1", String(error))
            }
        }
    }

    Kirigami.FormLayout {
        DetectedField {
            id: pythonExecutable
            Kirigami.FormData.label: i18nd("plasma_applet_panon", "Python interpreter:")
            placeholderText: "python3"
            busy: Boolean(root.command)
            onDetectRequested: root.detect("python", pythonExecutable)
        }
        QQC2.Button {
            text: i18nd("plasma_applet_panon", "Check dependencies")
            enabled: !root.command
            onClicked: {
                root.operation = "doctor"
                root.dependencyCheckStarted = true
                root.dependencyReport = null
                root.dependencyError = ""
                root.dependencyDetails = ""
                root.command = root.scriptsCommand(pythonExecutable.text) + " -m panon.backend.doctor # request " + (++root.requestId)
            }
        }
        DependencyReport {
            visible: root.dependencyCheckStarted
            Layout.fillWidth: true
            Layout.preferredWidth: 460
            checking: root.operation === "doctor" && Boolean(root.command)
            report: root.dependencyReport
            error: root.dependencyError
            details: root.dependencyDetails
        }
        DetectedField {
            id: audioSource
            Kirigami.FormData.label: i18nd("plasma_applet_panon", "Audio source:")
            placeholderText: i18nd("plasma_applet_panon", "Automatic")
            busy: Boolean(root.command)
            onDetectRequested: root.detect("audio", audioSource)
        }
        DetectedField {
            id: preferredPlayer
            Kirigami.FormData.label: i18nd("plasma_applet_panon", "Preferred MPRIS service:")
            placeholderText: i18nd("plasma_applet_panon", "Automatic")
            busy: Boolean(root.command)
            onDetectRequested: root.detect("services", preferredPlayer)
        }
        QQC2.Label {
            text: i18nd("plasma_applet_panon", "Leave audio source and MPRIS service empty to follow changes automatically. Detection fills the current choice.")
            wrapMode: Text.WordWrap
            Layout.preferredWidth: 460
        }
    }
}
