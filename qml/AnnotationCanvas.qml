import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import ProShottr 1.0

Item {
    id: root
    property string imageUrl: ""
    property real canvasScale: 1.0

    signal cancel()
    signal apply(string dataUrl, bool annotated)

    anchors.fill: parent
    visible: true

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0.0, 0.0, 0.0, 0.55)
    }

    ColumnLayout {
        id: layout
        anchors.fill: parent
        anchors.margins: 32
        spacing: 16

        Item {
            id: canvasWrapper
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            property real maxWidth: width
            property real maxHeight: height
            property real imageWidth: baseImage.sourceSize.width > 0 ? baseImage.sourceSize.width : baseImage.implicitWidth
            property real imageHeight: baseImage.sourceSize.height > 0 ? baseImage.sourceSize.height : baseImage.implicitHeight

            property real scaleFactor: {
                if (imageWidth === 0 || imageHeight === 0)
                    return 1.0
                var scale = Math.min(maxWidth / imageWidth, maxHeight / imageHeight)
                return Math.min(1.5, Math.max(0.1, scale))
            }

            Component.onCompleted: updateScale()
            onWidthChanged: updateScale()
            onHeightChanged: updateScale()
            onImageWidthChanged: updateScale()
            onImageHeightChanged: updateScale()

            function updateScale() {
                root.canvasScale = scaleFactor
                drawingCanvas.requestPaint()
            }

            Image {
                id: baseImage
                source: root.imageUrl
                visible: false
                onStatusChanged: if (status === Image.Ready) drawingCanvas.requestPaint()
            }

            Item {
                id: canvasSurface
                anchors.centerIn: parent
                width: canvasWrapper.imageWidth * canvasWrapper.scaleFactor
                height: canvasWrapper.imageHeight * canvasWrapper.scaleFactor
                visible: width > 0 && height > 0
            }

            Canvas {
                id: drawingCanvas
                anchors.top: canvasSurface.top
                anchors.left: canvasSurface.left
                width: Math.max(1, canvasWrapper.imageWidth)
                height: Math.max(1, canvasWrapper.imageHeight)
                transformOrigin: Item.TopLeft
                scale: canvasWrapper.scaleFactor
                renderTarget: Canvas.Image

                onPaint: {
                    if (!baseImage.paintedWidth)
                        return
                    var ctx = getContext("2d")
                    ctx.reset()
                    ctx.clearRect(0, 0, width, height)
                    ctx.save()
                    ctx.drawImage(baseImage, 0, 0, width, height)

                    var cmds = annotationHistory.commands
                    if (cmds && cmds.length) {
                        for (var i = 0; i < cmds.length; ++i) {
                            var command = cmds[i]
                            ctx.save()
                            ctx.strokeStyle = command.color || "#FF4A4A"
                            ctx.lineWidth = command.width || 4
                            ctx.fillStyle = command.fill || Qt.rgba(0,0,0,0)
                            switch (command.tool) {
                            case AnnotationEnums.Rectangle:
                                ctx.strokeRect(command.rect.x, command.rect.y, command.rect.width, command.rect.height)
                                break
                            case AnnotationEnums.Ellipse:
                                ctx.beginPath()
                                ctx.ellipse(command.rect.x + command.rect.width / 2,
                                            command.rect.y + command.rect.height / 2,
                                            Math.abs(command.rect.width / 2),
                                            Math.abs(command.rect.height / 2),
                                            0, 0, Math.PI * 2)
                                ctx.stroke()
                                break
                            case AnnotationEnums.Arrow:
                                drawArrow(ctx, command.start, command.end, command.width || 4)
                                break
                            case AnnotationEnums.Pencil:
                                drawStroke(ctx, command.points, command.width || 4)
                                break
                            case AnnotationEnums.Text:
                                ctx.font = (command.fontSize || 18) + "px \"Segoe UI\""
                                ctx.fillStyle = command.color || "#FFFFFF"
                                ctx.fillText(command.text || "", command.position.x, command.position.y)
                                break
                            default:
                                break
                            }
                            ctx.restore()
                        }
                    }
                    if (preview.visible) {
                        ctx.save()
                        ctx.strokeStyle = preview.color
                        ctx.lineWidth = preview.width
                        switch (preview.tool) {
                        case AnnotationEnums.Rectangle:
                            ctx.strokeRect(preview.rect.x, preview.rect.y, preview.rect.width, preview.rect.height)
                            break
                        case AnnotationEnums.Ellipse:
                            ctx.beginPath()
                            ctx.ellipse(preview.rect.x + preview.rect.width / 2,
                                        preview.rect.y + preview.rect.height / 2,
                                        Math.abs(preview.rect.width / 2),
                                        Math.abs(preview.rect.height / 2),
                                        0, 0, Math.PI * 2)
                            ctx.stroke()
                            break
                        case AnnotationEnums.Arrow:
                            drawArrow(ctx, preview.start, preview.end, preview.width)
                            break
                        case AnnotationEnums.Pencil:
                            drawStroke(ctx, preview.points, preview.width)
                            break
                        }
                        ctx.restore()
                    }
                    ctx.restore()
                }

                function drawArrow(ctx, start, end, width) {
                    if (!start || !end)
                        return
                    var headLength = 12 + width
                    var dx = end.x - start.x
                    var dy = end.y - start.y
                    var angle = Math.atan2(dy, dx)
                    ctx.beginPath()
                    ctx.moveTo(start.x, start.y)
                    ctx.lineTo(end.x, end.y)
                    ctx.stroke()
                    ctx.beginPath()
                    ctx.moveTo(end.x, end.y)
                    ctx.lineTo(end.x - headLength * Math.cos(angle - Math.PI / 6), end.y - headLength * Math.sin(angle - Math.PI / 6))
                    ctx.lineTo(end.x - headLength * Math.cos(angle + Math.PI / 6), end.y - headLength * Math.sin(angle + Math.PI / 6))
                    ctx.lineTo(end.x, end.y)
                    ctx.fillStyle = ctx.strokeStyle
                    ctx.fill()
                }

                function drawStroke(ctx, points, width) {
                    if (!points || points.length < 2)
                        return
                    ctx.lineJoin = "round"
                    ctx.lineCap = "round"
                    ctx.beginPath()
                    ctx.moveTo(points[0].x, points[0].y)
                    for (var i = 1; i < points.length; ++i) {
                        ctx.lineTo(points[i].x, points[i].y)
                    }
                    ctx.stroke()
                }
            }

            MouseArea {
                anchors.fill: canvasSurface
                hoverEnabled: true
                cursorShape: toolbar.currentTool === AnnotationEnums.Text ? Qt.IBeamCursor : Qt.CrossCursor

                property point startPoint
                property var pencilPoints: []

                onPressed: function(mouse) {
                    var pos = mapToImage(mouse.x, mouse.y)
                    startPoint = pos
                    if (toolbar.currentTool === AnnotationEnums.Pencil) {
                        pencilPoints = [pos]
                        preview.points = pencilPoints
                        preview.tool = AnnotationEnums.Pencil
                        preview.visible = true
                    } else if (toolbar.currentTool === AnnotationEnums.Text) {
                        createTextEditor(mouse.x, mouse.y)
                    } else if (toolbar.currentTool === AnnotationEnums.Eraser) {
                        eraseAt(pos)
                    } else {
                        preview.tool = toolbar.currentTool
                        preview.color = toolbar.strokeColor
                        preview.width = toolbar.strokeWidth
                        preview.rect = Qt.rect(pos.x, pos.y, 0, 0)
                        preview.start = pos
                        preview.end = pos
                        preview.visible = true
                    }
                }

                onPositionChanged: function(mouse) {
                    var pos = mapToImage(mouse.x, mouse.y)
                    if (!mouse.buttons || mouse.buttons !== Qt.LeftButton)
                        return
                    if (toolbar.currentTool === AnnotationEnums.Pencil) {
                        pencilPoints.push(pos)
                        preview.points = pencilPoints
                        drawingCanvas.requestPaint()
                    } else if (toolbar.currentTool === AnnotationEnums.Arrow) {
                        preview.end = pos
                        drawingCanvas.requestPaint()
                    } else if (toolbar.currentTool === AnnotationEnums.Rectangle || toolbar.currentTool === AnnotationEnums.Ellipse) {
                        preview.rect = rectFromPoints(startPoint, pos)
                        drawingCanvas.requestPaint()
                    } else if (toolbar.currentTool === AnnotationEnums.Eraser) {
                        eraseAt(pos)
                    }
                }

                onReleased: function(mouse) {
                    if (toolbar.currentTool === AnnotationEnums.Pencil) {
                        commitPencil()
                    } else if (toolbar.currentTool === AnnotationEnums.Arrow) {
                        commitArrow()
                    } else if (toolbar.currentTool === AnnotationEnums.Rectangle || toolbar.currentTool === AnnotationEnums.Ellipse) {
                        commitRect()
                    }
                    preview.visible = false
                    drawingCanvas.requestPaint()
                }

                function mapToImage(x, y) {
                    var point = drawingCanvas.mapFromItem(canvasSurface, x, y)
                    return Qt.point(point.x, point.y)
                }

                function rectFromPoints(start, end) {
                    var left = Math.min(start.x, end.x)
                    var top = Math.min(start.y, end.y)
                    var width = Math.abs(start.x - end.x)
                    var height = Math.abs(start.y - end.y)
                    return Qt.rect(left, top, width, height)
                }

                function commitRect() {
                    if (!preview.rect || preview.rect.width < 2 || preview.rect.height < 2)
                        return
                    annotationHistory.push({
                        tool: toolbar.currentTool,
                        rect: preview.rect,
                        color: toolbar.strokeColor,
                        width: toolbar.strokeWidth
                    })
                }

                function commitArrow() {
                    if (!preview.start || !preview.end)
                        return
                    annotationHistory.push({
                        tool: AnnotationEnums.Arrow,
                        start: preview.start,
                        end: preview.end,
                        color: toolbar.strokeColor,
                        width: toolbar.strokeWidth
                    })
                }

                function commitPencil() {
                    if (!pencilPoints || pencilPoints.length < 2)
                        return
                    annotationHistory.push({
                        tool: AnnotationEnums.Pencil,
                        points: pencilPoints.slice(0),
                        color: toolbar.strokeColor,
                        width: toolbar.strokeWidth
                    })
                    pencilPoints = []
                }

                function eraseAt(point) {
                    var commands = annotationHistory.commands
                    for (var i = commands.length - 1; i >= 0; --i) {
                        var cmd = commands[i]
                        if (!cmd)
                            continue
                        if (cmd.tool === AnnotationEnums.Rectangle || cmd.tool === AnnotationEnums.Ellipse) {
                            if (point.x >= cmd.rect.x && point.x <= cmd.rect.x + cmd.rect.width &&
                                    point.y >= cmd.rect.y && point.y <= cmd.rect.y + cmd.rect.height) {
                                annotationHistory.removeAt(i)
                                break
                            }
                        } else if (cmd.tool === AnnotationEnums.Arrow) {
                            // simple distance check to line
                            var dist = distanceToSegment(point, cmd.start, cmd.end)
                            if (dist < (cmd.width || 6)) {
                                annotationHistory.removeAt(i)
                                break
                            }
                        } else if (cmd.tool === AnnotationEnums.Pencil) {
                            if (hitStroke(point, cmd.points, cmd.width || 6)) {
                                annotationHistory.removeAt(i)
                                break
                            }
                        } else if (cmd.tool === AnnotationEnums.Text) {
                            var extent = textExtent(cmd)
                            if (point.x >= extent.x && point.x <= extent.x + extent.width &&
                                    point.y >= extent.y && point.y <= extent.y + extent.height) {
                                annotationHistory.removeAt(i)
                                break
                            }
                        }
                    }
                    drawingCanvas.requestPaint()
                }

                function distanceToSegment(p, v, w) {
                    var l2 = Math.pow(v.x - w.x, 2) + Math.pow(v.y - w.y, 2)
                    if (l2 === 0)
                        return Math.hypot(p.x - v.x, p.y - v.y)
                    var t = ((p.x - v.x) * (w.x - v.x) + (p.y - v.y) * (w.y - v.y)) / l2
                    t = Math.max(0, Math.min(1, t))
                    var proj = { x: v.x + t * (w.x - v.x), y: v.y + t * (w.y - v.y) }
                    return Math.hypot(p.x - proj.x, p.y - proj.y)
                }

                function hitStroke(point, points, width) {
                    for (var i = 1; i < points.length; ++i) {
                        if (distanceToSegment(point, points[i - 1], points[i]) < width)
                            return true
                    }
                    return false
                }

                function textExtent(cmd) {
                    var size = cmd.text ? cmd.text.length : 0
                    return Qt.rect(cmd.position.x, cmd.position.y - (cmd.fontSize || 18), size * (cmd.fontSize || 18) * 0.6, cmd.fontSize || 18)
                }
            }

            Component {
                id: textEditorComponent
                TextField {
                    id: editor
                    width: 220
                    focus: true
                    placeholderText: qsTr("Text")
                    property point imagePosition
                    onEditingFinished: {
                        if (text.length > 0) {
                            annotationHistory.push({
                                tool: AnnotationEnums.Text,
                                text: text,
                                position: imagePosition,
                                color: toolbar.strokeColor,
                                fontSize: 18
                            })
                        }
                        destroy()
                    }
                }
            }

            function createTextEditor(x, y) {
                var imagePoint = drawingCanvas.mapFromItem(canvasSurface, x, y)
                var editor = textEditorComponent.createObject(canvasSurface, {
                    x: x,
                    y: y,
                    imagePosition: Qt.point(imagePoint.x, imagePoint.y)
                })
                if (editor)
                    editor.forceActiveFocus()
            }
        }

        Rectangle {
            id: toolbarContainer
            Layout.fillWidth: true
            Layout.preferredHeight: 48
            radius: 12
            color: Qt.rgba(0.1, 0.1, 0.1, 0.85)
            border.color: Qt.rgba(1, 1, 1, 0.1)
            border.width: 1

            Toolbar {
                id: toolbar
                anchors.centerIn: parent
                onCancel: root.cancel()
                onUndo: {
                    annotationHistory.undo()
                    drawingCanvas.requestPaint()
                }
                onRedo: {
                    var restored = annotationHistory.redo()
                    if (restored)
                        drawingCanvas.requestPaint()
                }
                onApply: {
                    drawingCanvas.requestPaint()
                    root.apply(drawingCanvas.toDataURL("image/png"), annotationHistory.commands.length > 0)
                }
                onColorChanged: drawingCanvas.requestPaint()
                onWidthChanged: drawingCanvas.requestPaint()
                onSelectTool: function(tool) {
                    preview.tool = tool
                }
            }
        }
    }

    Connections {
        target: annotationHistory
        function onCommandsChanged() {
            drawingCanvas.requestPaint()
        }
    }

    QtObject {
        id: preview
        property bool visible: false
        property var rect
        property var start
        property var end
        property var points: []
        property color color: toolbar.strokeColor
        property int width: toolbar.strokeWidth
        property int tool: AnnotationEnums.Rectangle
    }
}
