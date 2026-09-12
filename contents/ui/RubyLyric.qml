import QtQuick

Flow {
    id: root
    property var segments: []
    property int pixelSize: 21
    property bool emphasized: false
    property color textColor: "white"
    property string fontFamily: Qt.application.font.family
    readonly property var tokens: {
        const result = []
        for (const part of segments) {
            if (part.reading) result.push(part)
            else for (const character of Array.from(part.text))
                result.push({text: character, reading: ""})
        }
        return result
    }
    spacing: 0

    Repeater {
        model: root.tokens
        delegate: Item {
            required property var modelData
            width: Math.min(root.width, Math.max(original.implicitWidth, reading.implicitWidth + (reading.text ? 2 : 0)))
            height: root.pixelSize * 1.65

            Text {
                id: reading
                anchors.top: parent.top
                width: parent.width
                height: root.pixelSize * 0.68
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
                anchors.topMargin: -root.pixelSize * 0.18
                width: parent.width
                text: modelData.text
                textFormat: Text.PlainText
                font.family: root.fontFamily
                font.pixelSize: root.pixelSize
                font.weight: root.emphasized ? Font.Bold : Font.Normal
                horizontalAlignment: Text.AlignHCenter
                fontSizeMode: Text.HorizontalFit
                color: root.textColor
            }
        }
    }
}
