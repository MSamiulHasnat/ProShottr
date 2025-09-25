import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import ProShottr 1.0

RowLayout {
    id: toolbar
    spacing: 8

    property int currentTool: AnnotationEnums.Rectangle
    signal selectTool(int tool)
    signal undo()
    signal redo()
    signal cancel()
    signal apply()

    function toolButton(label, tool) {
        return ToolButton {
            text: label
            checkable: true
            checked: toolbar.currentTool === tool
            onClicked: {
                toolbar.currentTool = tool
                toolbar.selectTool(tool)
            }
        }
    }

    ToolButton {
        text: "✕"
        onClicked: toolbar.cancel()
        ToolTip.visible: hovered
        ToolTip.text: qsTr("Exit")
    }

    ToolButton {
        text: "↶"
        onClicked: toolbar.undo()
        ToolTip.visible: hovered
        ToolTip.text: qsTr("Undo")
    }

    ToolButton {
        text: "↷"
        onClicked: toolbar.redo()
        ToolTip.visible: hovered
        ToolTip.text: qsTr("Redo")
    }

    ToolSeparator {}

    ToolButton {
        text: "➔"
        checkable: true
        checked: toolbar.currentTool === AnnotationEnums.Arrow
        onClicked: {
            toolbar.currentTool = AnnotationEnums.Arrow
            toolbar.selectTool(AnnotationEnums.Arrow)
        }
        ToolTip.visible: hovered
        ToolTip.text: qsTr("Arrow")
    }

    ToolButton {
        text: "▭"
        checkable: true
        checked: toolbar.currentTool === AnnotationEnums.Rectangle
        onClicked: {
            toolbar.currentTool = AnnotationEnums.Rectangle
            toolbar.selectTool(AnnotationEnums.Rectangle)
        }
        ToolTip.visible: hovered
        ToolTip.text: qsTr("Rectangle")
    }

    ToolButton {
        text: "⬭"
        checkable: true
        checked: toolbar.currentTool === AnnotationEnums.Ellipse
        onClicked: {
            toolbar.currentTool = AnnotationEnums.Ellipse
            toolbar.selectTool(AnnotationEnums.Ellipse)
        }
        ToolTip.visible: hovered
        ToolTip.text: qsTr("Ellipse")
    }

    ToolButton {
        text: "T"
        checkable: true
        checked: toolbar.currentTool === AnnotationEnums.Text
        onClicked: {
            toolbar.currentTool = AnnotationEnums.Text
            toolbar.selectTool(AnnotationEnums.Text)
        }
        ToolTip.visible: hovered
        ToolTip.text: qsTr("Text")
    }

    ToolButton {
        text: "✏"
        checkable: true
        checked: toolbar.currentTool === AnnotationEnums.Pencil
        onClicked: {
            toolbar.currentTool = AnnotationEnums.Pencil
            toolbar.selectTool(AnnotationEnums.Pencil)
        }
        ToolTip.visible: hovered
        ToolTip.text: qsTr("Pencil")
    }

    ToolButton {
        text: "⌫"
        checkable: true
        checked: toolbar.currentTool === AnnotationEnums.Eraser
        onClicked: {
            toolbar.currentTool = AnnotationEnums.Eraser
            toolbar.selectTool(AnnotationEnums.Eraser)
        }
        ToolTip.visible: hovered
        ToolTip.text: qsTr("Eraser")
    }

    ToolSeparator {}

    ColorDialogButton {
        id: colorButton
        onColorSelected: parent.strokeColor = color
    }

    ToolButton {
        text: qsTr("Copy")
        onClicked: toolbar.apply()
        ToolTip.visible: hovered
        ToolTip.text: qsTr("Copy & Finish")
    }
}

// Helper button for picking colors
Control {
    id: colorDialogButton
    implicitWidth: 32
    implicitHeight: 32

    property color color: "#FF4A4A"
    signal colorSelected(color color)

    background: Rectangle {
        anchors.fill: parent
        import QtQuick 2.15
        import QtQuick.Controls 2.15
        import QtQuick.Layouts 1.15
        import ProShottr 1.0

        RowLayout {
            id: toolbar
            spacing: 8

            property int currentTool: AnnotationEnums.Rectangle
            property color strokeColor: "#FF4A4A"
            property int strokeWidth: 4

            signal selectTool(int tool)
            signal undo()
            signal redo()
            signal cancel()
            signal apply()
            signal colorChanged(color color)
            signal widthChanged(int width)

            ToolButton {
                text: "✕"
                onClicked: toolbar.cancel()
                ToolTip.visible: hovered
                ToolTip.text: qsTr("Exit")
            }

            ToolButton {
                text: "↶"
                onClicked: toolbar.undo()
                ToolTip.visible: hovered
                ToolTip.text: qsTr("Undo")
            }

            ToolButton {
                text: "↷"
                onClicked: toolbar.redo()
                ToolTip.visible: hovered
                ToolTip.text: qsTr("Redo")
            }

            ToolSeparator {}

            ToolButton {
                text: "➔"
                checkable: true
                checked: toolbar.currentTool === AnnotationEnums.Arrow
                onClicked: {
                    toolbar.currentTool = AnnotationEnums.Arrow
                    toolbar.selectTool(AnnotationEnums.Arrow)
                }
                ToolTip.visible: hovered
                ToolTip.text: qsTr("Arrow")
            }

            ToolButton {
                text: "▭"
                checkable: true
                checked: toolbar.currentTool === AnnotationEnums.Rectangle
                onClicked: {
                    toolbar.currentTool = AnnotationEnums.Rectangle
                    toolbar.selectTool(AnnotationEnums.Rectangle)
                }
                ToolTip.visible: hovered
                ToolTip.text: qsTr("Rectangle")
            }

            ToolButton {
                text: "⬭"
                checkable: true
                checked: toolbar.currentTool === AnnotationEnums.Ellipse
                onClicked: {
                    toolbar.currentTool = AnnotationEnums.Ellipse
                    toolbar.selectTool(AnnotationEnums.Ellipse)
                }
                ToolTip.visible: hovered
                ToolTip.text: qsTr("Ellipse")
            }

            ToolButton {
                text: "T"
                checkable: true
                checked: toolbar.currentTool === AnnotationEnums.Text
                onClicked: {
                    toolbar.currentTool = AnnotationEnums.Text
                    toolbar.selectTool(AnnotationEnums.Text)
                }
                ToolTip.visible: hovered
                ToolTip.text: qsTr("Text")
            }

            ToolButton {
                text: "✏"
                checkable: true
                checked: toolbar.currentTool === AnnotationEnums.Pencil
                onClicked: {
                    toolbar.currentTool = AnnotationEnums.Pencil
                    toolbar.selectTool(AnnotationEnums.Pencil)
                }
                ToolTip.visible: hovered
                ToolTip.text: qsTr("Pencil")
            }

            ToolButton {
                text: "⌫"
                checkable: true
                checked: toolbar.currentTool === AnnotationEnums.Eraser
                onClicked: {
                    toolbar.currentTool = AnnotationEnums.Eraser
                    toolbar.selectTool(AnnotationEnums.Eraser)
                }
                ToolTip.visible: hovered
                ToolTip.text: qsTr("Eraser")
            }

            ToolSeparator {}

            ToolButton {
                id: colorButton
                implicitWidth: 32
                implicitHeight: 32
                checkable: false
                contentItem: Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: toolbar.strokeColor
                    border.width: 1
                    border.color: "#DDDDDD"
                }
                onClicked: colorMenu.open()
                ToolTip.visible: hovered
                ToolTip.text: qsTr("Stroke color")
            }

            Menu {
                id: colorMenu
                MenuItem { text: qsTr("Red"); onTriggered: { toolbar.strokeColor = "#FF4A4A"; toolbar.colorChanged(toolbar.strokeColor) } }
                MenuItem { text: qsTr("Orange"); onTriggered: { toolbar.strokeColor = "#FFA534"; toolbar.colorChanged(toolbar.strokeColor) } }
                MenuItem { text: qsTr("Yellow"); onTriggered: { toolbar.strokeColor = "#FFD740"; toolbar.colorChanged(toolbar.strokeColor) } }
                MenuItem { text: qsTr("Green"); onTriggered: { toolbar.strokeColor = "#4CAF50"; toolbar.colorChanged(toolbar.strokeColor) } }
                MenuItem { text: qsTr("Blue"); onTriggered: { toolbar.strokeColor = "#2196F3"; toolbar.colorChanged(toolbar.strokeColor) } }
                MenuItem { text: qsTr("Purple"); onTriggered: { toolbar.strokeColor = "#9C27B0"; toolbar.colorChanged(toolbar.strokeColor) } }
                MenuItem { text: qsTr("White"); onTriggered: { toolbar.strokeColor = "#FFFFFF"; toolbar.colorChanged(toolbar.strokeColor) } }
                MenuItem { text: qsTr("Black"); onTriggered: { toolbar.strokeColor = "#000000"; toolbar.colorChanged(toolbar.strokeColor) } }
            }

            ComboBox {
                id: widthSelector
                model: [2, 4, 6, 8, 12]
                Component.onCompleted: {
                    var index = model.indexOf(toolbar.strokeWidth)
                    if (index >= 0)
                        currentIndex = index
                }
                onActivated: {
                    toolbar.strokeWidth = model[index]
                    toolbar.widthChanged(toolbar.strokeWidth)
                }
                ToolTip.visible: hovered
                ToolTip.text: qsTr("Stroke width")
            }

            ToolSeparator {}

            ToolButton {
                text: qsTr("Done")
                onClicked: toolbar.apply()
                ToolTip.visible: hovered
                ToolTip.text: qsTr("Copy & finish")
            }
        }
