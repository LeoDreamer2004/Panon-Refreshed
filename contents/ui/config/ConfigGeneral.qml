import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import "../Fonts.js" as Fonts

KCM.SimpleKCM {
    id: root
    property string cfg_pythonExecutable
    property string cfg_audioSource
    property string cfg_preferredPlayer
    property alias cfg_lyricFont: lyricFont.text
    property var cfg_pythonExecutableDefault
    property var cfg_audioSourceDefault
    property var cfg_preferredPlayerDefault
    property var cfg_lyricFontDefault
    property string cfg_neteaseAppPath
    property string cfg_neteaseElectron
    property string cfg_qqmusicAppPath
    property string cfg_qqmusicElectron
    property var cfg_neteaseAppPathDefault
    property var cfg_neteaseElectronDefault
    property var cfg_qqmusicAppPathDefault
    property var cfg_qqmusicElectronDefault
    property bool cfg_showTranslation
    property bool cfg_showFurigana
    property var cfg_showFuriganaDefault
    property var cfg_showTranslationDefault
    property alias cfg_fps: fps.value
    property alias cfg_theme: theme.currentIndex
    property alias cfg_barCount: barCount.value
    property alias cfg_sensitivity: sensitivity.value
    property alias cfg_decay: decay.value
    property alias cfg_mirror: mirror.checked
    property alias cfg_autoHide: autoHide.checked
    property alias cfg_animateAutoHiding: animateAutoHiding.checked
    property alias cfg_autoExtend: autoExtend.checked
    property alias cfg_preferredWidth: preferredWidth.value
    property alias cfg_panelSpectrumWidth: panelSpectrumWidth.value
    property alias cfg_desktopBlurStrength: desktopBlurStrength.value
    property alias cfg_desktopOverlayStrength: desktopOverlayStrength.value
    property alias cfg_desktopBorderWidth: desktopBorderWidth.value

    // Plasma 6.7 also injects every schema default as an initial property.
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

    Kirigami.FormLayout {
        DetectedField {
            id: lyricFont
            Kirigami.FormData.label: i18nd("plasma_applet_panon", "Lyrics font:")
            placeholderText: i18nd("plasma_applet_panon", "Automatic")
            onDetectRequested: text = Fonts.select("", Qt.fontFamilies(), Qt.application.font.family)
        }
        QQC2.ComboBox {
            id: theme
            Kirigami.FormData.label: i18nd("plasma_applet_panon", "Theme:")
            model: [
                i18nd("plasma_applet_panon", "Classic Bars"),
                i18nd("plasma_applet_panon", "Center Equalizer"),
                i18nd("plasma_applet_panon", "Wave Ribbon"),
                i18nd("plasma_applet_panon", "Mountains"),
                i18nd("plasma_applet_panon", "Neon Dots"),
                i18nd("plasma_applet_panon", "Radial"),
                i18nd("plasma_applet_panon", "Spectrogram")
            ]
        }

        QQC2.SpinBox {
            id: fps
            Kirigami.FormData.label: i18nd("plasma_applet_panon", "Refresh rate:")
            from: 5
            to: 60
            textFromValue: function(value) { return i18nd("plasma_applet_panon", "%1 FPS", value) }
            valueFromText: function(text) { return parseInt(text) }
        }

        QQC2.SpinBox {
            id: barCount
            Kirigami.FormData.label: i18nd("plasma_applet_panon", "Bars:")
            from: 8
            to: 128
        }

        QQC2.SpinBox {
            id: sensitivity
            Kirigami.FormData.label: i18nd("plasma_applet_panon", "Sensitivity:")
            from: 20
            to: 300
            textFromValue: function(value) { return i18nd("plasma_applet_panon", "%1%", value) }
            valueFromText: function(text) { return parseInt(text) }
        }

        QQC2.SpinBox {
            id: decay
            Kirigami.FormData.label: i18nd("plasma_applet_panon", "Decay:")
            from: 20
            to: 97
            textFromValue: function(value) { return i18nd("plasma_applet_panon", "%1%", value) }
            valueFromText: function(text) { return parseInt(text) }
        }

        QQC2.CheckBox {
            id: mirror
            visible: theme.currentIndex === 0
            text: i18nd("plasma_applet_panon", "Mirror spectrum from the center")
        }

        QQC2.CheckBox {
            id: autoHide
            text: i18nd("plasma_applet_panon", "Collapse completely when no audio is playing")
        }

        QQC2.CheckBox {
            id: animateAutoHiding
            enabled: autoHide.checked
            text: i18nd("plasma_applet_panon", "Animate hiding")
        }

        QQC2.CheckBox {
            id: autoExtend
            text: i18nd("plasma_applet_panon", "Fill available panel space")
        }

        QQC2.SpinBox {
            id: preferredWidth
            Kirigami.FormData.label: i18nd("plasma_applet_panon", "Panel width:")
            from: 100
            to: 2000
            stepSize: 10
            textFromValue: function(value) { return i18nd("plasma_applet_panon", "%1 px", value) }
            valueFromText: function(text) { return parseInt(text) }
        }

        QQC2.SpinBox {
            id: panelSpectrumWidth
            Kirigami.FormData.label: i18nd("plasma_applet_panon", "Spectrum width:")
            from: 48
            to: 240
            stepSize: 8
            textFromValue: function(value) { return i18nd("plasma_applet_panon", "%1 px", value) }
            valueFromText: function(text) { return parseInt(text) }
        }

        QQC2.SpinBox {
            id: desktopBlurStrength
            Kirigami.FormData.label: i18nd("plasma_applet_panon", "Desktop blur:")
            from: 0
            to: 200
            stepSize: 5
            textFromValue: function(value) { return i18nd("plasma_applet_panon", "%1%", value) }
            valueFromText: function(text) { return parseInt(text) }
        }

        QQC2.SpinBox {
            id: desktopOverlayStrength
            Kirigami.FormData.label: i18nd("plasma_applet_panon", "Background dark overlay:")
            from: 0
            to: 100
            stepSize: 5
            textFromValue: function(value) { return i18nd("plasma_applet_panon", "%1%", value) }
            valueFromText: function(text) { return parseInt(text) }
        }

        QQC2.SpinBox {
            id: desktopBorderWidth
            Kirigami.FormData.label: i18nd("plasma_applet_panon", "Desktop border width:")
            from: 0
            to: 8
            stepSize: 1
            textFromValue: function(value) {
                return value === 0 ? i18nd("plasma_applet_panon", "No border")
                                   : i18nd("plasma_applet_panon", "%1 px", value)
            }
            valueFromText: function(text) {
                return text.trim() === i18nd("plasma_applet_panon", "No border") ? 0 : parseInt(text)
            }
        }
    }
}
