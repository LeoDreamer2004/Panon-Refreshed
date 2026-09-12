import QtQuick
import Qt5Compat.GraphicalEffects
OpacityMask {
    property alias image: effect.source
    id: effect
    cached: true
    maskSource: Rectangle {
        width: effect.width
        height: effect.height
        radius: width / 2
        color: "white"
    }
}
