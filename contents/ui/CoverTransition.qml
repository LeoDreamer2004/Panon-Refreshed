import QtQuick

Item {
    id: root
    property url source: ""
    property bool playing: false
    property int duration: 600
    property int front: -1
    readonly property bool ready: front >= 0
    readonly property bool softwareRendering: GraphicsInfo.api === GraphicsInfo.Software

    function prepare() {
        // Keep the last decoded image until the replacement is ready.
        if (!source.toString()) return
        if (front >= 0 && buffers.itemAt(front).source.toString() === source.toString()) return
        const back = front === 0 ? 1 : 0
        const image = buffers.itemAt(back)
        if (!image) return
        image.source = source
        if (image.status === Image.Ready) accept(back)
    }
    function accept(index) {
        const image = buffers.itemAt(index)
        if (image.status === Image.Ready && image.source.toString() === source.toString())
            front = index
    }
    onSourceChanged: Qt.callLater(prepare)
    Component.onCompleted: Qt.callLater(prepare)

    Item {
        anchors.fill: parent
        NumberAnimation on rotation {
            from: 0; to: 360; duration: 24000
            loops: Animation.Infinite
            running: root.ready
            paused: root.ready && !root.playing
        }
        Repeater {
            id: buffers
            model: 2
            Item {
                id: buffer
                required property int index
                property alias source: image.source
                property alias status: image.status
                anchors.fill: parent
                opacity: root.front === index ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: root.duration; easing.type: Easing.InOutCubic } }
                onStatusChanged: if (status === Image.Ready) root.accept(index)
                Image {
                    id: image
                    anchors.fill: parent
                    asynchronous: true
                    cache: true
                    sourceSize: root.softwareRendering ? Qt.size(0, 0) : Qt.size(512, 512)
                    fillMode: Image.PreserveAspectCrop
                    visible: !root.softwareRendering
                    layer.enabled: !root.softwareRendering
                    layer.effect: ShaderEffect {
                        fragmentShader: Qt.resolvedUrl("shaders/circular-cover.frag.qsb")
                    }
                }
                Canvas {
                    id: softwareCover
                    anchors.fill: parent
                    visible: root.softwareRendering
                    property url imageSource: buffer.source
                    onImageSourceChanged: if (visible && imageSource.toString()) loadImage(imageSource)
                    onImageLoaded: requestPaint()
                    onVisibleChanged: if (visible && imageSource.toString()) loadImage(imageSource)
                    onWidthChanged: requestPaint()
                    onHeightChanged: requestPaint()
                    onPaint: {
                        const ctx = getContext("2d")
                        ctx.reset()
                        if (!isImageLoaded(imageSource)) return
                        const size = image.sourceSize
                        const side = Math.min(size.width, size.height)
                        if (side <= 0) return
                        ctx.beginPath()
                        ctx.arc(width / 2, height / 2, width / 2, 0, Math.PI * 2)
                        ctx.clip()
                        ctx.drawImage(imageSource, (size.width - side) / 2, (size.height - side) / 2,
                                      side, side, 0, 0, width, height)
                    }
                }
            }
        }
    }
}
