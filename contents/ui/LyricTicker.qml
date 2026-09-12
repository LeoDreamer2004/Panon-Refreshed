import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami

Item {
    id: root

    property string text: ""
    property var timing: ({})
    property string lineKey: ""
    property string displayedKey: ""
    property bool initialized: false
    readonly property real overflow: Math.max(0, currentLyric.implicitWidth - width)
    readonly property real scrollProgress: {
        const start = Number(timing.start || 0)
        const end = Number(timing.end || 0)
        const elapsed = Math.max(0, Number(timing.position || 0) - start)
        // Unknown final duration: retain a gentle, one-way fallback.
        const total = end > start ? end - start : 1.6 + overflow * 0.038
        const head = Math.min(1.0, total * 0.15)
        const tail = Math.min(0.6, total * 0.12)
        return Math.max(0, Math.min(1, (elapsed - head) / Math.max(0.01, total - head - tail)))
    }

    clip: true

    function changeLine(nextText) {
        if (initialized && nextText === currentLyric.text && displayedKey === lineKey) {
            return
        }
        verticalScroll.stop()
        previousLyric.text = currentLyric.text
        previousLyric.x = currentLyric.x
        previousLyric.y = 0
        displayedKey = lineKey

        if (!initialized) {
            currentLyric.text = nextText
            currentLyric.y = 0
            initialized = true
            return
        }
        currentLyric.text = nextText
        currentLyric.y = root.height
        verticalScroll.start()
    }

    // Coalesce the text, index and timestamp updates from one backend frame.
    onTextChanged: Qt.callLater(refreshLine)
    onLineKeyChanged: Qt.callLater(refreshLine)
    function refreshLine() { changeLine(text) }
    Component.onCompleted: changeLine(text)

    QQC2.Label {
        id: previousLyric
        y: 0
        height: root.height
        verticalAlignment: Text.AlignVCenter
        color: Kirigami.Theme.textColor
        font.weight: Font.Medium
        maximumLineCount: 1
        wrapMode: Text.NoWrap
    }

    QQC2.Label {
        id: currentLyric
        x: -root.overflow * root.scrollProgress
        y: 0
        height: root.height
        verticalAlignment: Text.AlignVCenter
        color: Kirigami.Theme.textColor
        font.weight: Font.Medium
        maximumLineCount: 1
        wrapMode: Text.NoWrap
    }

    ParallelAnimation {
        id: verticalScroll

        NumberAnimation {
            target: previousLyric
            property: "y"
            from: 0
            to: -root.height
            duration: Math.min(320, Math.max(60, (Number(root.timing.end || 0) - Number(root.timing.start || 0)) * 100))
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: currentLyric
            property: "y"
            from: root.height
            to: 0
            duration: Math.min(320, Math.max(60, (Number(root.timing.end || 0) - Number(root.timing.start || 0)) * 100))
            easing.type: Easing.OutCubic
        }

    }
}
