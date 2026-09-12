import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

QQC2.Pane {
    id: root
    property var report: null
    property bool checking: false
    property string error: ""
    property string details: ""
    readonly property var checks: report ? report.checks : []
    readonly property int failedRequired: checks.filter(c => c.required && !c.ok).length
    readonly property int failedOptional: checks.filter(c => !c.required && !c.ok).length
    readonly property color statusColor: error || failedRequired ? Kirigami.Theme.negativeTextColor
                                        : failedOptional ? Kirigami.Theme.neutralTextColor : Kirigami.Theme.positiveTextColor
    padding: 14
    background: Rectangle {
        radius: 8
        color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.04)
        border.color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.15)
    }

    function purpose(name) {
        switch (name) {
        case "numpy": return i18nd("plasma_applet_panon", "Spectrum analysis")
        case "websockets": return i18nd("plasma_applet_panon", "Widget communication")
        case "dbus": return i18nd("plasma_applet_panon", "Media information and controls")
        case "PIL": return i18nd("plasma_applet_panon", "Album artwork processing")
        case "pykakasi": case "jaconv": return i18nd("plasma_applet_panon", "Japanese readings (optional)")
        case "pactl": case "parec": return i18nd("plasma_applet_panon", "Audio capture; lyrics still work without it")
        default: return ""
        }
    }

    contentItem: ColumnLayout {
        spacing: 10
        RowLayout {
            QQC2.BusyIndicator {
                visible: root.checking
                running: visible
                Layout.preferredWidth: 24
                Layout.preferredHeight: 24
            }
            Kirigami.Icon {
                visible: !root.checking
                source: root.error || root.failedRequired ? "dialog-error" : root.failedOptional ? "dialog-warning" : "dialog-positive"
                color: root.statusColor
                Layout.preferredWidth: 22
                Layout.preferredHeight: 22
            }
            QQC2.Label {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                font.bold: true
                text: root.checking ? i18nd("plasma_applet_panon", "Checking Python environment…")
                      : root.error ? i18nd("plasma_applet_panon", "Environment check could not run")
                      : root.failedRequired ? i18nd("plasma_applet_panon", "Required dependencies need attention")
                      : root.failedOptional ? i18nd("plasma_applet_panon", "Core dependencies ready; some features unavailable")
                      : i18nd("plasma_applet_panon", "All dependencies are available")
            }
        }
        QQC2.Label {
            visible: Boolean(root.report) && !root.checking
            text: root.report ? "Python " + root.report.version : ""
            font.bold: true
        }
        QQC2.Label {
            visible: Boolean(root.report) && !root.checking
            Layout.fillWidth: true
            wrapMode: Text.WrapAnywhere
            textFormat: Text.PlainText
            text: root.report ? root.report.python : ""
            opacity: 0.75
            font.pointSize: Kirigami.Theme.smallFont.pointSize
        }
        Repeater {
            model: root.checking ? [] : root.checks
            delegate: ColumnLayout {
                id: dependency
                required property var modelData
                Layout.fillWidth: true
                spacing: 3
                RowLayout {
                    Kirigami.Icon {
                        source: dependency.modelData.ok ? "dialog-positive" : dependency.modelData.required ? "dialog-error" : "dialog-warning"
                        color: dependency.modelData.ok ? Kirigami.Theme.positiveTextColor : dependency.modelData.required ? Kirigami.Theme.negativeTextColor : Kirigami.Theme.neutralTextColor
                        Layout.preferredWidth: 16
                        Layout.preferredHeight: 16
                    }
                    QQC2.Label {
                        text: dependency.modelData.name === "PIL" ? "Pillow" : dependency.modelData.name === "dbus" ? "dbus-python" : dependency.modelData.name
                        font.bold: true
                    }
                    Item { Layout.fillWidth: true }
                    QQC2.Label {
                        text: dependency.modelData.ok ? i18nd("plasma_applet_panon", "Available") : i18nd("plasma_applet_panon", "Unavailable")
                    }
                }
                QQC2.Label {
                    Layout.fillWidth: true
                    Layout.leftMargin: 22
                    text: root.purpose(dependency.modelData.name)
                    wrapMode: Text.WordWrap
                    opacity: 0.7
                }
                QQC2.ToolButton {
                    id: dependencyDetails
                    visible: Boolean(dependency.modelData.error)
                    text: checked ? i18nd("plasma_applet_panon", "Hide error details") : i18nd("plasma_applet_panon", "Show error details")
                    checkable: true
                }
                QQC2.TextArea {
                    visible: dependencyDetails.checked && Boolean(dependency.modelData.error)
                    Layout.fillWidth: true
                    readOnly: true
                    wrapMode: TextEdit.WrapAnywhere
                    textFormat: TextEdit.PlainText
                    text: dependency.modelData.error || ""
                }
            }
        }
        QQC2.Label {
            visible: Boolean(root.error) && !root.checking
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            text: i18nd("plasma_applet_panon", "Check the interpreter path or use Auto-detect, then try again.")
        }
        QQC2.ToolButton {
            id: extraDetails
            visible: !root.checking && Boolean(root.error || root.details)
            text: checked ? i18nd("plasma_applet_panon", "Hide error details") : i18nd("plasma_applet_panon", "Show error details")
            checkable: true
        }
        QQC2.TextArea {
            visible: extraDetails.visible && extraDetails.checked
            Layout.fillWidth: true
            text: root.error || root.details
            readOnly: true
            wrapMode: TextEdit.WrapAnywhere
            textFormat: TextEdit.PlainText
        }
    }
}
