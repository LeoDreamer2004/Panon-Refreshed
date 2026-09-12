import QtQuick
import Qt5Compat.GraphicalEffects as GE

Item {
    id: root
    property url wallpaperUrl
    property real screenWidth: 0
    property real screenHeight: 0
    property real offsetX: 0
    property real offsetY: 0
    property real blurRadius: 32
    property int fillMode: Image.PreserveAspectCrop
    property color backgroundColor: "black"

    Item {
        id: wallpaperSource
        anchors.fill: parent
        visible: false
        clip: true
        layer.enabled: true
        Rectangle {
            width: root.screenWidth
            height: root.screenHeight
            x: -root.offsetX
            y: -root.offsetY
            color: root.backgroundColor
            Image {
                anchors.fill: parent
                source: root.wallpaperUrl
                fillMode: root.fillMode
                asynchronous: true
                cache: true
            }
        }
    }
    Rectangle {
        id: roundedMask
        anchors.fill: parent
        radius: 22
        color: "white"
        visible: false
        layer.enabled: true
    }
    GE.GaussianBlur {
        id: blurred
        anchors.fill: parent
        source: wallpaperSource
        visible: false
        radius: root.blurRadius
        samples: 121
        deviation: (radius + 1) / 3.3333
        cached: true
    }
    GE.OpacityMask {
        anchors.fill: parent
        source: blurred
        maskSource: roundedMask
        cached: true
    }
}
