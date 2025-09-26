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

    ColorDialogButton {
        id: colorButton
        color: toolbar.strokeColor
        onColorSelected: function(selectedColor) {
            toolbar.strokeColor = selectedColor
            toolbar.colorChanged(selectedColor)
        }
    }

    ComboBox {
        id: widthSelector
        model: [2, 4, 6, 8, 12]
        Component.onCompleted: {
            const index = model.indexOf(toolbar.strokeWidth)
            if (index >= 0)
                currentIndex = index
        }
        onActivated: function(index) {
            toolbar.strokeWidth = model[index]
            toolbar.widthChanged(toolbar.strokeWidth)
        }
        ToolTip.visible: hovered
        ToolTip.text: qsTr("Stroke width")
    }

    ToolSeparator {}

    ToolButton {
        text: qsTr("Copy")
        onClicked: toolbar.apply()
        ToolTip.visible: hovered
        ToolTip.text: qsTr("Copy & Finish")
    }
}

component ColorDialogButton: ToolButton {
    id: colorDialogButton
    implicitWidth: 32
    implicitHeight: 32

    property color color: "#FF4A4A"
    signal colorSelected(color color)

    checkable: false
    contentItem: Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: colorDialogButton.color
        border.width: 1
        border.color: "#DDDDDD"
    }

    onClicked: colorMenu.open()
    ToolTip.visible: hovered
    ToolTip.text: qsTr("Stroke color")

    function chooseColor(value) {
        colorSelected(value)
    }

    Menu {
        id: colorMenu
        y: colorDialogButton.height

        MenuItem {
            text: qsTr("Red")
            onTriggered: colorDialogButton.chooseColor("#FF4A4A")
        }
        MenuItem {
            text: qsTr("Orange")
            onTriggered: colorDialogButton.chooseColor("#FFA534")
        }
        MenuItem {
            text: qsTr("Yellow")
            onTriggered: colorDialogButton.chooseColor("#FFD740")
        }
        MenuItem {
            text: qsTr("Green")
            onTriggered: colorDialogButton.chooseColor("#4CAF50")
        }
        MenuItem {
            text: qsTr("Blue")
            onTriggered: colorDialogButton.chooseColor("#2196F3")
        }
        MenuItem {
            text: qsTr("Purple")
            onTriggered: colorDialogButton.chooseColor("#9C27B0")
        }
        MenuItem {
            text: qsTr("White")
            onTriggered: colorDialogButton.chooseColor("#FFFFFF")
        }
        MenuItem {
            text: qsTr("Black")
            onTriggered: colorDialogButton.chooseColor("#000000")
        }
    }
}
