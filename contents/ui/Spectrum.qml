import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid

Item {
    id: root

    readonly property var cfg: plasmoid.configuration
    readonly property bool vertical: plasmoid.formFactor === PlasmaCore.Types.Vertical

    property var spectrum: []
    property var spectrumHistory: []
    property real audioLevel: 0.0
    property bool audioAvailable: false
    property string backendError: ""
    property real preferredExtentOverride: -1
    readonly property real preferredExtent: preferredExtentOverride > 0 ? preferredExtentOverride : cfg.preferredWidth
    readonly property bool collapsed: cfg.autoHide && !audioAvailable && backendError.length === 0
    property real animatedExtent: collapsed ? 0 : preferredExtent

    implicitWidth: vertical ? 96 : animatedExtent
    implicitHeight: vertical ? animatedExtent : 96

    Layout.minimumWidth: vertical ? -1 : 0
    Layout.minimumHeight: vertical ? 0 : -1
    Layout.preferredWidth: vertical ? -1 : animatedExtent
    Layout.preferredHeight: vertical ? animatedExtent : -1
    Layout.maximumWidth: vertical ? -1 : animatedExtent
    Layout.maximumHeight: vertical ? animatedExtent : -1
    Layout.fillWidth: !vertical && cfg.autoExtend && !collapsed
    Layout.fillHeight: vertical && cfg.autoExtend && !collapsed

    opacity: collapsed ? 0.0 : 1.0
    Behavior on opacity {
        NumberAnimation { duration: cfg.animateAutoHiding ? 250 : 0 }
    }
    Behavior on animatedExtent {
        NumberAnimation {
            duration: cfg.animateAutoHiding ? 250 : 0
            easing.type: Easing.InOutCubic
        }
    }

    onSpectrumChanged: {
        if (cfg.theme === 6) {
            const nextHistory = spectrumHistory.slice(-95)
            nextHistory.push(spectrum.slice(0))
            spectrumHistory = nextHistory
        }
        canvas.requestPaint()
    }

    onAudioLevelChanged: {
        if (audioLevel > 0.0008) {
            silenceTimer.stop()
            audioAvailable = true
        } else if (audioAvailable && !silenceTimer.running) {
            silenceTimer.start()
        }
    }

    Timer {
        id: silenceTimer
        interval: 1500
        repeat: false
        onTriggered: root.audioAvailable = false
    }

    Canvas {
        id: canvas
        anchors.fill: parent
        visible: root.audioAvailable
        antialiasing: true

        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()

        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            ctx.clearRect(0, 0, width, height)

            if (!root.spectrum || root.spectrum.length === 0) {
                return
            }

            const totalBars = Math.max(8, cfg.barCount)
            const gain = Math.max(0.2, cfg.sensitivity / 100.0)

            function valueAt(position, count) {
                const denominator = Math.max(1, count - 1)
                const sourceIndex = Math.min(
                    root.spectrum.length - 1,
                    Math.round(position / denominator * (root.spectrum.length - 1))
                )
                return Math.min(1.0, Math.max(0.0, root.spectrum[sourceIndex] * gain))
            }

            function spectrumGradient() {
                const gradient = ctx.createLinearGradient(0, height, 0, 0)
                gradient.addColorStop(0.0, Kirigami.Theme.highlightColor)
                gradient.addColorStop(0.55, "#46d9ff")
                gradient.addColorStop(1.0, "#ff5edb")
                return gradient
            }

            function drawBars(centered, mirrored) {
                const logicalBars = mirrored ? Math.max(4, Math.floor(totalBars / 2)) : totalBars
                const gap = Math.max(1, Math.min(4, width / totalBars * 0.16))
                const barWidth = Math.max(1, (width - gap * (totalBars - 1)) / totalBars)
                ctx.fillStyle = spectrumGradient()

                for (let i = 0; i < totalBars; ++i) {
                    let logicalIndex = i
                    if (mirrored) {
                        logicalIndex = i < logicalBars ? logicalBars - i - 1 : i - logicalBars
                    }
                    const value = valueAt(logicalIndex, logicalBars)
                    const maximumHeight = centered ? height / 2 - 2 : height - 4
                    const barHeight = Math.max(2, value * maximumHeight)
                    const x = i * (barWidth + gap)
                    if (centered) {
                        ctx.fillRect(x, height / 2 - barHeight, barWidth, barHeight * 2)
                    } else {
                        ctx.fillRect(x, height - barHeight, barWidth, barHeight)
                    }
                }
            }

            function drawWave() {
                const count = Math.max(24, totalBars)
                const gradient = ctx.createLinearGradient(0, 0, width, 0)
                gradient.addColorStop(0.0, "#7b61ff")
                gradient.addColorStop(0.5, "#46d9ff")
                gradient.addColorStop(1.0, "#ff5edb")
                ctx.strokeStyle = gradient
                ctx.fillStyle = "rgba(70, 217, 255, 0.18)"
                ctx.lineWidth = Math.max(2, height / 36)
                ctx.beginPath()
                ctx.moveTo(0, height)
                for (let i = 0; i < count; ++i) {
                    const x = i / (count - 1) * width
                    const y = height - 3 - valueAt(i, count) * (height - 8)
                    ctx.lineTo(x, y)
                }
                ctx.lineTo(width, height)
                ctx.closePath()
                ctx.fill()
                ctx.beginPath()
                for (let i = 0; i < count; ++i) {
                    const x = i / (count - 1) * width
                    const y = height - 3 - valueAt(i, count) * (height - 8)
                    if (i === 0) ctx.moveTo(x, y)
                    else ctx.lineTo(x, y)
                }
                ctx.stroke()
            }

            function drawMountains() {
                const count = Math.max(32, totalBars)
                const midpoint = (count - 1) / 2
                const gradient = ctx.createLinearGradient(0, height, 0, 0)
                gradient.addColorStop(0.0, "rgba(70, 217, 255, 0.25)")
                gradient.addColorStop(0.65, "rgba(123, 97, 255, 0.72)")
                gradient.addColorStop(1.0, "rgba(255, 94, 219, 0.95)")
                ctx.fillStyle = gradient
                ctx.strokeStyle = "#8eeaff"
                ctx.lineWidth = 1.5
                ctx.beginPath()
                ctx.moveTo(0, height)
                for (let i = 0; i < count; ++i) {
                    const distance = Math.abs(i - midpoint)
                    const logicalIndex = Math.round(midpoint - distance)
                    const x = i / (count - 1) * width
                    const y = height - valueAt(logicalIndex, Math.ceil(count / 2)) * (height - 2)
                    ctx.lineTo(x, y)
                }
                ctx.lineTo(width, height)
                ctx.closePath()
                ctx.fill()
                ctx.stroke()
            }

            function drawDots() {
                const count = Math.max(12, Math.min(totalBars, 64))
                const radius = Math.max(1.8, Math.min(5, width / count * 0.18))
                ctx.shadowBlur = radius * 3
                ctx.shadowColor = "#46d9ff"
                for (let i = 0; i < count; ++i) {
                    const value = valueAt(i, count)
                    const x = (i + 0.5) / count * width
                    const y = height - radius - value * (height - radius * 2)
                    ctx.fillStyle = `hsla(${190 + value * 130}, 100%, 68%, 0.95)`
                    ctx.beginPath()
                    ctx.arc(x, y, radius + value * radius, 0, Math.PI * 2)
                    ctx.fill()
                }
                ctx.shadowBlur = 0
            }

            function drawRadial() {
                const count = Math.max(24, Math.min(totalBars, 96))
                const centerX = width / 2
                const centerY = height / 2
                const innerRadius = Math.min(width, height) * 0.16
                const maximumLength = Math.max(2, Math.min(width, height) * 0.33)
                ctx.lineWidth = Math.max(1.5, Math.min(5, Math.PI * innerRadius / count))
                ctx.lineCap = "round"
                for (let i = 0; i < count; ++i) {
                    const value = valueAt(i, count)
                    const angle = i / count * Math.PI * 2 - Math.PI / 2
                    const outerRadius = innerRadius + value * maximumLength
                    ctx.strokeStyle = `hsla(${185 + i / count * 190}, 100%, 67%, 0.95)`
                    ctx.beginPath()
                    ctx.moveTo(centerX + Math.cos(angle) * innerRadius, centerY + Math.sin(angle) * innerRadius)
                    ctx.lineTo(centerX + Math.cos(angle) * outerRadius, centerY + Math.sin(angle) * outerRadius)
                    ctx.stroke()
                }
            }

            function drawSpectrogram() {
                const frames = root.spectrumHistory
                if (!frames || frames.length === 0) return
                const frameWidth = width / 96
                const bandCount = Math.max(16, Math.min(totalBars, 64))
                const bandHeight = height / bandCount
                const startX = width - frames.length * frameWidth
                for (let frameIndex = 0; frameIndex < frames.length; ++frameIndex) {
                    const frame = frames[frameIndex]
                    for (let band = 0; band < bandCount; ++band) {
                        const sourceIndex = Math.min(
                            frame.length - 1,
                            Math.round(band / (bandCount - 1) * (frame.length - 1))
                        )
                        const value = Math.min(1, frame[sourceIndex] * gain)
                        ctx.fillStyle = `hsla(${245 - value * 210}, 100%, ${18 + value * 57}%, ${0.15 + value * 0.85})`
                        ctx.fillRect(
                            startX + frameIndex * frameWidth,
                            height - (band + 1) * bandHeight,
                            frameWidth + 1,
                            bandHeight + 1
                        )
                    }
                }
            }

            switch (cfg.theme) {
            case 1:
                drawBars(true, false)
                break
            case 2:
                drawWave()
                break
            case 3:
                drawMountains()
                break
            case 4:
                drawDots()
                break
            case 5:
                drawRadial()
                break
            case 6:
                drawSpectrogram()
                break
            default:
                drawBars(false, cfg.mirror)
            }
        }
    }

    QQC2.Label {
        anchors.centerIn: parent
        width: Math.min(parent.width - 12, implicitWidth)
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.Wrap
        visible: root.backendError.length > 0
        color: Kirigami.Theme.negativeTextColor
        text: root.backendError
    }

}
