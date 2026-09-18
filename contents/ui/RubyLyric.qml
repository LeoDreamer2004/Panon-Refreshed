import QtQuick

Flow {
    id: root
    property var segments: []
    property int pixelSize: 21
    property bool emphasized: false
    property color textColor: "white"
    property string fontFamily: Qt.application.font.family
    property var words: []
    property real position: 0
    property bool karaoke: false
    property bool showReadings: true
    readonly property real sungCharacters: {
        let count = 0
        for (const word of words) {
            if (position < word.start) break
            const fraction = word.duration > 0 ? Math.max(0, Math.min(1, (position - word.start) / word.duration)) : 1
            count += Array.from(word.text).length * fraction
            if (fraction < 1) break
        }
        return count
    }
    readonly property var tokens: {
        const result = []
        let offset = 0
        for (const part of segments) {
            if (part.reading && showReadings) {
                const length = Array.from(part.text).length
                result.push({text: part.text, reading: part.reading, offset: offset, length: length})
                offset += length
            }
            else for (const character of Array.from(part.text))
                result.push({text: character, reading: "", offset: offset++, length: 1})
        }
        return result
    }
    spacing: 0

    Repeater {
        model: root.tokens
        delegate: Item {
            id: token
            required property var modelData
            readonly property real progress: Math.max(0, Math.min(1, (root.sungCharacters - modelData.offset) / modelData.length))
            width: Math.min(root.width, Math.max(original.implicitWidth, reading.implicitWidth + (reading.text ? 2 : 0)))
            height: root.pixelSize * (root.showReadings ? 1.65 : 1.25)

            Text {
                id: reading
                anchors.top: parent.top
                width: parent.width
                height: root.showReadings ? root.pixelSize * 0.68 : 0
                text: modelData.reading || ""
                textFormat: Text.PlainText
                font.family: root.fontFamily
                font.pixelSize: Math.max(9, Math.round(root.pixelSize * 0.52))
                font.weight: root.emphasized ? Font.DemiBold : Font.Normal
                fontSizeMode: Text.HorizontalFit
                minimumPixelSize: 6
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignBottom
                color: root.textColor
                opacity: 0.82
            }
            Text {
                id: original
                anchors.top: reading.bottom
                anchors.topMargin: root.showReadings ? -root.pixelSize * 0.18 : 0
                width: parent.width
                text: modelData.text
                textFormat: Text.PlainText
                font.family: root.fontFamily
                font.pixelSize: root.pixelSize
                font.weight: root.emphasized ? Font.Bold : Font.Normal
                horizontalAlignment: Text.AlignHCenter
                fontSizeMode: Text.HorizontalFit
                color: root.karaoke ? "#80909f" : root.textColor
            }
            Item {
                x: original.x
                y: original.y
                width: original.width * token.progress
                height: original.height
                clip: true
                visible: root.karaoke
                Text {
                    width: original.width
                    text: original.text
                    textFormat: Text.PlainText
                    font: original.font
                    fontSizeMode: original.fontSizeMode
                    horizontalAlignment: Text.AlignHCenter
                    color: "#ffffff"
                }
            }
        }
    }
}
