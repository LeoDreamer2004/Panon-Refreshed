import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Item {
    id: root

    property var colors: ["#8b5cf6", "#22d3ee", "#f472b6"]
    property bool mediaPlaying: false
    property real mediaPosition: 0
    property real mediaDuration: 0
    property bool canSeek: false
    property bool canGoPrevious: false
    property bool canGoNext: false
    property bool canPlayPause: false
    property bool showTranslation: true
    property bool translationAvailable: false
    property bool showFurigana: true
    property bool furiganaAvailable: false
    signal furiganaToggleRequested()
    signal translationToggleRequested()

    signal previousRequested()
    signal playPauseRequested()
    signal nextRequested()
    signal seekRequested(real position)

    readonly property color primaryColor: colors && colors.length > 0 ? colors[0] : "#8b5cf6"

    implicitHeight: 66

    function formatTime(seconds) {
        const safeSeconds = Math.max(0, Math.floor(Number(seconds) || 0))
        const minutes = Math.floor(safeSeconds / 60)
        const remainder = safeSeconds % 60
        return minutes + ":" + (remainder < 10 ? "0" : "") + remainder
    }

    component MediaButton: QQC2.ToolButton {
        property color accentColor: root.primaryColor
        property bool emphasized: false
        Layout.preferredWidth: emphasized ? 34 : 30
        Layout.preferredHeight: emphasized ? 34 : 30
        padding: 6

        contentItem: Kirigami.Icon {
            source: parent.icon.name
            color: parent.enabled ? "#f7f8fc" : "#697083"
        }

        background: Rectangle {
            radius: width / 2
            color: parent.emphasized
                   ? Qt.rgba(parent.accentColor.r, parent.accentColor.g,
                             parent.accentColor.b, parent.hovered ? 0.68 : 0.48)
                   : (parent.hovered ? "#32ffffff" : "#14ffffff")
            border.width: parent.emphasized ? 1 : 0
            border.color: "#78ffffff"
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 8
        anchors.topMargin: 4
        anchors.bottomMargin: 3
        spacing: 0

        QQC2.Slider {
            id: progressSlider
            Layout.fillWidth: true
            Layout.preferredHeight: 20
            from: 0
            to: Math.max(1, root.mediaDuration)
            enabled: root.canSeek && root.mediaDuration > 0

            background: Rectangle {
                x: progressSlider.leftPadding
                y: progressSlider.topPadding + progressSlider.availableHeight / 2 - height / 2
                width: progressSlider.availableWidth
                height: 4
                radius: 2
                color: "#40ffffff"

                Rectangle {
                    width: progressSlider.visualPosition * parent.width
                    height: parent.height
                    radius: parent.radius
                    color: root.primaryColor
                }
            }

            handle: Rectangle {
                x: progressSlider.leftPadding
                   + progressSlider.visualPosition * (progressSlider.availableWidth - width)
                y: progressSlider.topPadding + progressSlider.availableHeight / 2 - height / 2
                width: progressSlider.pressed ? 14 : 12
                height: width
                radius: width / 2
                color: "#ffffff"
                border.width: 2
                border.color: root.primaryColor

                Behavior on width { NumberAnimation { duration: 100 } }
            }

            Binding {
                target: progressSlider
                property: "value"
                value: root.mediaPosition
                when: !progressSlider.pressed
                restoreMode: Binding.RestoreNone
            }

            onPressedChanged: {
                if (!pressed && root.canSeek) {
                    root.seekRequested(value)
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 5

            QQC2.Label {
                text: root.formatTime(progressSlider.pressed
                                      ? progressSlider.value
                                      : root.mediaPosition)
                      + "  /  " + root.formatTime(root.mediaDuration)
                color: "#d8dbe6"
                font.pixelSize: 11
                font.weight: Font.Medium
            }

            QQC2.ToolButton {
                id: translationButton
                Layout.preferredWidth: 22
                Layout.preferredHeight: 22
                Layout.maximumWidth: 22
                Layout.maximumHeight: 22
                padding: 2
                text: qsTr("译")
                checkable: true
                checked: root.showTranslation
                enabled: root.translationAvailable
                onClicked: root.translationToggleRequested()
                Accessible.name: root.showTranslation ? qsTr("隐藏翻译") : qsTr("显示翻译")
                QQC2.ToolTip.visible: hovered
                QQC2.ToolTip.text: !root.translationAvailable ? qsTr("当前歌曲暂无翻译")
                                  : (root.showTranslation ? qsTr("隐藏翻译") : qsTr("显示翻译"))

                contentItem: QQC2.Label {
                    text: translationButton.text
                    color: translationButton.enabled ? "#ffffff" : "#89909e"
                    font.pixelSize: 12
                    font.bold: (root.showTranslation && root.translationAvailable)
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                background: Rectangle {
                    radius: 5
                    color: (root.showTranslation && root.translationAvailable) ? Qt.rgba(root.primaryColor.r,
                               root.primaryColor.g, root.primaryColor.b, 0.48)
                           : (translationButton.hovered ? "#30ffffff" : "#12ffffff")
                    border.width: 1
                    border.color: (root.showTranslation && root.translationAvailable) ? "#90ffffff" : "#38ffffff"
                }
            }

            QQC2.ToolButton {
                id: furiganaButton
                Layout.preferredWidth: 22
                Layout.preferredHeight: 22
                Layout.maximumWidth: 22
                Layout.maximumHeight: 22
                padding: 2
                enabled: root.furiganaAvailable
                checkable: true
                checked: root.showFurigana
                onClicked: root.furiganaToggleRequested()
                Accessible.name: i18nd("plasma_applet_panon", "Toggle Japanese readings")
                QQC2.ToolTip.visible: hovered
                QQC2.ToolTip.text: i18nd("plasma_applet_panon", "Japanese readings: NetEase first, local fallback")
                contentItem: QQC2.Label {
                    text: "音"
                    font.pixelSize: 12
                    font.bold: root.showFurigana && root.furiganaAvailable
                    color: furiganaButton.enabled ? "#ffffff" : "#89909e"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                background: Rectangle {
                    radius: 5
                    color: root.showFurigana && root.furiganaAvailable
                           ? Qt.rgba(root.primaryColor.r, root.primaryColor.g, root.primaryColor.b, 0.48)
                           : (furiganaButton.hovered ? "#30ffffff" : "#12ffffff")
                    border.width: 1
                    border.color: root.showFurigana && root.furiganaAvailable ? "#90ffffff" : "#38ffffff"
                }
            }

            Item { Layout.fillWidth: true }

            MediaButton {
                enabled: root.canGoPrevious
                icon.name: "media-skip-backward"
                onClicked: root.previousRequested()
            }

            MediaButton {
                emphasized: true
                accentColor: root.primaryColor
                enabled: root.canPlayPause
                icon.name: root.mediaPlaying ? "media-playback-pause" : "media-playback-start"
                onClicked: root.playPauseRequested()
            }

            MediaButton {
                enabled: root.canGoNext
                icon.name: "media-skip-forward"
                onClicked: root.nextRequested()
            }
        }
    }
}
