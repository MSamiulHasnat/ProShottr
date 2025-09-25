import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Window 2.15
import ProShottr 1.0

Window {
    id: overlay
    visible: overlayManager.overlayVisible || captureOrchestrator.state === CaptureOrchestrator.Annotating
    flags: Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint | Qt.Tool | Qt.NoDropShadowWindowHint
    color: captureOrchestrator.state === CaptureOrchestrator.TargetRegion ? Qt.rgba(0, 0, 0, 0.35) : "transparent"
    modality: Qt.ApplicationModal
    focus: true

    property rect hoverRect: Qt.rect(0, 0, 0, 0)
    property string hoverTitle: ""
    property bool dragging: false
    property point dragStart: Qt.point(0, 0)
    property rect dragRect: Qt.rect(0, 0, 0, 0)
    property real overlayDpr: Screen.devicePixelRatio

    Component.onCompleted: {
        updateBounds()
        overlayManager.registerOverlayWindow(overlay)
    }

    Connections {
        target: Qt.application
        function onScreensChanged() {
            updateBounds()
        }
    }

    function updateBounds() {
        var screens = Qt.application.screens
        if (!screens || screens.length === 0)
            return
        var minX = screens[0].geometry.x
        var minY = screens[0].geometry.y
        var maxX = screens[0].geometry.x + screens[0].geometry.width
        var maxY = screens[0].geometry.y + screens[0].geometry.height
        for (var i = 1; i < screens.length; ++i) {
            var geo = screens[i].geometry
            minX = Math.min(minX, geo.x)
            minY = Math.min(minY, geo.y)
            maxX = Math.max(maxX, geo.x + geo.width)
            maxY = Math.max(maxY, geo.y + geo.height)
        }
        x = minX
        y = minY
        width = maxX - minX
        height = maxY - minY
    }

    Keys.onEscapePressed: captureOrchestrator.cancelCapture()

    Label {
        id: statusLabel
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 32
        text: captureOrchestrator.statusMessage
        color: "white"
        visible: text.length > 0 && captureOrchestrator.state !== CaptureOrchestrator.Annotating
        font.pointSize: 16
        font.bold: true
        layer.enabled: true
        layer.effect: DropShadow {
            radius: 12
            samples: 24
            color: "#99000000"
            horizontalOffset: 0
            verticalOffset: 2
        }
    }

    Rectangle {
        id: hoverHighlight
        visible: captureOrchestrator.state === CaptureOrchestrator.TargetWindow && hoverRect.width > 0 && hoverRect.height > 0
        x: hoverRect.x
        y: hoverRect.y
        width: hoverRect.width
        height: hoverRect.height
        color: "transparent"
        border.width: 3
        border.color: "#33A1FF"
        radius: 18
        layer.enabled: true
        layer.effect: DropShadow {
            radius: 20
            samples: 32
            color: "#A033A1FF"
            horizontalOffset: 0
            verticalOffset: 0
        }
    }

    Rectangle {
        id: regionRect
        visible: captureOrchestrator.state === CaptureOrchestrator.TargetRegion && dragRect.width > 0 && dragRect.height > 0
        x: dragRect.x
        y: dragRect.y
        width: dragRect.width
        height: dragRect.height
        color: Qt.rgba(0.2, 0.4, 0.9, 0.15)
        border.width: 2
        border.color: "#3385FF"
        radius: 6
    }

    MouseArea {
        id: overlayMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: captureOrchestrator.state === CaptureOrchestrator.TargetRegion ? Qt.CrossCursor : Qt.ArrowCursor

        onPressed: function(mouse) {
            if (captureOrchestrator.state === CaptureOrchestrator.TargetRegion) {
                dragging = true
                dragStart = Qt.point(mouse.x, mouse.y)
                dragRect = Qt.rect(mouse.x, mouse.y, 0, 0)
            }
        }

        onPositionChanged: function(mouse) {
            if (captureOrchestrator.state === CaptureOrchestrator.TargetWindow) {
                var info = overlayManager.windowInfoAtPoint(Qt.point(mouse.x, mouse.y))
                if (info && info.geometry) {
                    var rect = info.geometry
                    var topLeft = overlayManager.globalToOverlay(Qt.point(rect.x, rect.y))
                    hoverRect = Qt.rect(topLeft.x, topLeft.y, rect.width, rect.height)
                    hoverTitle = info.title || ""
                }
            } else if (captureOrchestrator.state === CaptureOrchestrator.TargetRegion && dragging) {
                var dx = mouse.x - dragStart.x
                var dy = mouse.y - dragStart.y
                var rectX = dx < 0 ? mouse.x : dragStart.x
                var rectY = dy < 0 ? mouse.y : dragStart.y
                dragRect = Qt.rect(rectX, rectY, Math.abs(dx), Math.abs(dy))
            }
        }

        onReleased: function(mouse) {
            if (captureOrchestrator.state === CaptureOrchestrator.TargetRegion && dragging) {
                dragging = false
                if (dragRect.width > 4 && dragRect.height > 4) {
                    var topLeftGlobal = overlayManager.overlayToGlobal(Qt.point(dragRect.x, dragRect.y))
                    captureOrchestrator.confirmRegionCapture(
                                Qt.rect(topLeftGlobal.x, topLeftGlobal.y, dragRect.width, dragRect.height),
                                overlay.screen ? overlay.screen.devicePixelRatio : 1.0)
                }
                dragRect = Qt.rect(0, 0, 0, 0)
            } else if (captureOrchestrator.state === CaptureOrchestrator.TargetWindow) {
                var info = overlayManager.windowInfoAtPoint(Qt.point(mouse.x, mouse.y))
                if (info && info.handle) {
                    captureOrchestrator.confirmWindowCapture(info.handle)
                }
            }
        }
    }

    AnnotationCanvas {
        id: annotationCanvas
        anchors.fill: parent
        visible: captureOrchestrator.state === CaptureOrchestrator.Annotating
        imageUrl: captureOrchestrator.capturedImageUrl
        onCancel: captureOrchestrator.cancelCapture()
        onApply: function(dataUrl, annotated) {
            captureOrchestrator.finalizeCapture(dataUrl, annotated)
        }
    }
}
