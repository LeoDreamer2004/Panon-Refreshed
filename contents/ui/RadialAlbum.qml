import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami

Item {
    id: root

    property var spectrum: []
    property real audioLevel: 0.0
    property string artUrl: ""
    property var colors: ["#8b5cf6", "#22d3ee", "#f472b6"]
    property bool playing: false

    readonly property color primaryColor: colors && colors.length > 0 ? colors[0] : "#8b5cf6"
    readonly property color secondaryColor: colors && colors.length > 1 ? colors[1] : "#22d3ee"
    readonly property color tertiaryColor: colors && colors.length > 2 ? colors[2] : "#f472b6"
    readonly property real pulse: Math.min(1.0, audioLevel * 13.0)
    readonly property real coverSize: Math.min(width, height) * 0.47

    Item {
        id: particleOrbit
        anchors.fill: parent

        NumberAnimation on rotation {
            from: 0
            to: 360
            duration: 36000
            loops: Animation.Infinite
            running: root.visible
        }

        Repeater {
            model: 12

            Rectangle {
                required property int index
                readonly property real angle: index * Math.PI * 2 / 12
                readonly property real orbitRadius: root.coverSize * (0.78 + (index % 4) * 0.045)
                width: 2 + index % 3
                height: width
                radius: width / 2
                x: particleOrbit.width / 2 + Math.cos(angle) * orbitRadius - width / 2
                y: particleOrbit.height / 2 + Math.sin(angle) * orbitRadius - height / 2
                color: index % 3 === 0 ? root.primaryColor
                                      : index % 3 === 1 ? root.secondaryColor
                                                        : root.tertiaryColor
                opacity: 0.18 + (index % 5) * 0.07 + root.pulse * 0.22
            }
        }
    }

    Rectangle {
        width: root.coverSize * 1.12
        height: width
        anchors.centerIn: parent
        radius: width / 2
        color: "transparent"
        border.width: 1
        border.color: Qt.rgba(root.secondaryColor.r, root.secondaryColor.g,
                              root.secondaryColor.b, 0.38)
    }

    Item {
        id: radialSpectrum
        anchors.fill: parent
        readonly property int rayCount: 64

        function magnitudeAt(index) {
            const bands = root.spectrum
            if (!bands || bands.length === 0) {
                return 0
            }
            // Spread the entire spectrum clockwise once, including both ends.
            const position = index * (bands.length - 1) / (rayCount - 1)
            const lower = Math.floor(position)
            const upper = Math.min(lower + 1, bands.length - 1)
            const fraction = position - lower
            return (Number(bands[lower]) || 0) * (1 - fraction)
                    + (Number(bands[upper]) || 0) * fraction
        }

        Repeater {
            model: radialSpectrum.rayCount

            Item {
                id: ray
                required property int index
                readonly property real magnitude: radialSpectrum.magnitudeAt(index)
                readonly property real shaped: Math.pow(Math.max(0.025, magnitude), 0.78)
                readonly property real innerRadius: root.coverSize * 0.56 + 7
                readonly property real rayLength: 3 + shaped * Math.min(root.width, root.height) * 0.205
                readonly property color rayColor: index % 3 === 0 ? root.primaryColor
                                                  : index % 3 === 1 ? root.secondaryColor
                                                                    : root.tertiaryColor

                x: radialSpectrum.width / 2
                y: radialSpectrum.height / 2
                width: 0
                height: 0
                rotation: index * 360 / radialSpectrum.rayCount

                Rectangle {
                    id: rayGlow
                    x: -width / 2
                    y: -ray.innerRadius - height
                    width: 5
                    height: ray.rayLength
                    radius: width / 2
                    color: ray.rayColor
                    opacity: 0.08 + ray.shaped * 0.12
                }

                Rectangle {
                    x: -width / 2
                    y: -ray.innerRadius - height
                    width: 1.8 + ray.shaped * 1.2
                    height: ray.rayLength
                    radius: width / 2
                    color: ray.rayColor
                    opacity: 0.52 + ray.shaped * 0.42
                }
            }
        }
    }

    Item {
        id: coverFrame
        width: root.coverSize
        height: width
        anchors.centerIn: parent
        scale: 1.0 + root.pulse * 0.025

        Behavior on scale {
            NumberAnimation { duration: 100; easing.type: Easing.OutQuad }
        }

        Rectangle {
            id: fallbackCover
            anchors.fill: parent
            radius: width / 2
            antialiasing: true
            visible: !circularCover.ready
            gradient: Gradient {
                GradientStop { position: 0.0; color: root.primaryColor }
                GradientStop { position: 0.55; color: root.secondaryColor }
                GradientStop { position: 1.0; color: root.tertiaryColor }
            }

            QQC2.Label {
                anchors.centerIn: parent
                text: "♪"
                color: "white"
                font.pixelSize: parent.width * 0.34
                font.weight: Font.Light
                opacity: 0.88
            }

            NumberAnimation on rotation {
                from: 0
                to: 360
                duration: 24000
                loops: Animation.Infinite
                running: root.playing && fallbackCover.visible
            }
        }

        CoverTransition {
            id: circularCover
            anchors.fill: parent
            source: root.artUrl
            playing: root.playing
        }

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: "transparent"
            border.width: 2
            border.color: Qt.rgba(root.secondaryColor.r, root.secondaryColor.g,
                                  root.secondaryColor.b, 0.78)
        }

        Rectangle {
            width: parent.width * 0.105
            height: width
            radius: width / 2
            anchors.centerIn: parent
            color: "#d90b0d14"
            border.width: 1
            border.color: Qt.rgba(root.primaryColor.r, root.primaryColor.g,
                                  root.primaryColor.b, 0.85)
        }
    }
}
