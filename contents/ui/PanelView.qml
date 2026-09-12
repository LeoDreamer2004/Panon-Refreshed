import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid

Item {
    id: root

    readonly property var cfg: plasmoid.configuration
    property var spectrum: []
    property real audioLevel: 0.0
    property string backendError: ""
    property string trackTitle: ""
    property string trackArtist: ""
    property string currentLyric: ""
    property var lyricTiming: ({})
    property string lyricKey: ""
    property bool mediaPlaying: false
    property bool lyricsAvailable: false
    property bool audioAvailable: false

    readonly property bool collapsed: cfg.autoHide && !audioAvailable && backendError.length === 0
    readonly property bool showLyrics: audioAvailable && lyricsAvailable
    readonly property real spectrumWidth: cfg.panelSpectrumWidth
    readonly property real contentWidth: showLyrics ? cfg.preferredWidth : spectrumWidth
    property real animatedWidth: collapsed ? 0 : contentWidth

    implicitWidth: animatedWidth
    implicitHeight: Kirigami.Units.gridUnit * 2
    Layout.minimumWidth: 0
    Layout.preferredWidth: animatedWidth
    Layout.maximumWidth: animatedWidth

    opacity: collapsed ? 0.0 : 1.0
    clip: true

    Behavior on animatedWidth {
        NumberAnimation {
            duration: cfg.animateAutoHiding ? 250 : 0
            easing.type: Easing.InOutCubic
        }
    }
    Behavior on opacity {
        NumberAnimation { duration: cfg.animateAutoHiding ? 250 : 0 }
    }

    onAudioLevelChanged: {
        if (audioLevel > 0.0008) {
            silenceTimer.stop()
            audioAvailable = true
        } else if (audioAvailable && !silenceTimer.running) {
            silenceTimer.start()
        }
    }

    Timer {
        id: silenceTimer
        interval: 1500
        repeat: false
        onTriggered: root.audioAvailable = false
    }

    RowLayout {
        anchors.fill: parent
        spacing: Kirigami.Units.smallSpacing

        Spectrum {
            spectrum: root.spectrum
            audioLevel: root.audioLevel
            backendError: root.backendError
            preferredExtentOverride: root.spectrumWidth
            Layout.preferredWidth: root.spectrumWidth
            Layout.maximumWidth: root.spectrumWidth
            Layout.fillHeight: true
        }

        Rectangle {
            visible: root.showLyrics
            Layout.preferredWidth: 1
            Layout.preferredHeight: parent.height * 0.58
            color: Kirigami.Theme.textColor
            opacity: 0.22
        }

        LyricTicker {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root.showLyrics
            text: root.currentLyric
            timing: root.lyricTiming
            lineKey: root.lyricKey
        }
    }
}
