import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts

ColumnLayout {
    id: root
    property alias text: field.text
    property alias placeholderText: field.placeholderText
    property bool busy: false
    property string errorMessage: ""
    property var candidates: []
    signal detectRequested()
    signal detected(string value)

    function applyResult(result) {
        candidates = result.candidates || []
        choices.currentIndex = -1
        if (result.selected) {
            field.text = result.selected
            root.detected(result.selected)
            candidates = []
        }
    }

    RowLayout {
        Layout.fillWidth: true
    QQC2.TextField {
        id: field
        Layout.fillWidth: true
        implicitWidth: 260
        selectByMouse: true
    }
    QQC2.Button {
        text: i18nd("plasma_applet_panon", "Auto-detect")
        enabled: !root.busy
        onClicked: root.detectRequested()
    }
    QQC2.ComboBox {
        id: choices
        visible: root.candidates.length > 1
        model: root.candidates
        textRole: "label"
        Layout.preferredWidth: 190
        displayText: currentIndex < 0 ? i18nd("plasma_applet_panon", "Select a detected candidate") : currentText
        onActivated: {
            field.text = root.candidates[currentIndex].value
            root.detected(field.text)
            root.candidates = []
        }
    }
    }
    QQC2.Label {
        visible: root.errorMessage.length > 0
        text: root.errorMessage
        textFormat: Text.PlainText
        wrapMode: Text.WrapAnywhere
        Layout.fillWidth: true
        Layout.preferredWidth: 400
    }
}
