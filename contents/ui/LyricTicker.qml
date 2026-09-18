import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami

Item {
    id: root

    property string text: ""
    property var timing: ({})
    property var words: []
    readonly property var wordWidths: {
        let prefix = ""
        const result = [0]
        for (const word of words) {
            prefix += word.text
            result.push(metrics.advanceWidth(prefix))
        }
        return result
    }
    readonly property real highlightWidth: {
        let width = 0
        const position = Number(timing.position || 0)
        for (let i = 0; i < words.length; ++i) {
            const word = words[i]
            if (position < word.start) break
            const fraction = word.duration > 0 ? Math.max(0, Math.min(1, (position - word.start) / word.duration)) : 1
            width = wordWidths[i] + (wordWidths[i + 1] - wordWidths[i]) * fraction
            if (fraction < 1) break
        }
        return width
    }
    FontMetrics { id: metrics; font: currentLyric.font }
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
        // Brief initial hold; reserve the final 30–40% for reading the end.
        // Scale short lines proportionally instead of consuming their duration.
        const head = Math.min(0.35, total * 0.08)
        const tail = Math.min(total * 0.40, Math.max(1.2, total * 0.30))
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
        opacity: root.words.length ? 0.45 : 1
        x: -root.overflow * root.scrollProgress
        y: 0
        height: root.height
        verticalAlignment: Text.AlignVCenter
        color: Kirigami.Theme.textColor
        font.weight: Font.Medium
        maximumLineCount: 1
        wrapMode: Text.NoWrap
    }

    Item {
        x: currentLyric.x
        y: currentLyric.y
        width: root.highlightWidth
        height: root.height
        clip: true
        visible: root.words.length > 0
        QQC2.Label {
            width: currentLyric.width
            height: root.height
            text: currentLyric.text
            textFormat: Text.PlainText
            font: currentLyric.font
            verticalAlignment: Text.AlignVCenter
            color: Kirigami.Theme.textColor
            maximumLineCount: 1
            wrapMode: Text.NoWrap
        }
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
