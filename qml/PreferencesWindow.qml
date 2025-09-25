import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Dialogs 1.3 as Dialogs
import Qt.labs.platform 1.1 as Platform
import ProShottr 1.0

Dialog {
    id: preferences
    modal: true
    title: qsTr("Preferences")
    standardButtons: Dialog.Ok

    width: 420
    height: 520
    closePolicy: Popup.CloseOnPressOutside | Popup.CloseOnEscape

    contentItem: Flickable {
        contentWidth: preferences.width
        contentHeight: column.implicitHeight
        clip: true

        ColumnLayout {
            id: column
            width: parent.width
            spacing: 16
            anchors.margins: 16

            GroupBox {
                title: qsTr("Capture")
                Layout.fillWidth: true
                ColumnLayout {
                    anchors.fill: parent
                    spacing: 12

                    Label {
                        text: qsTr("Output format")
                    }

                    ComboBox {
                        id: formatCombo
                        Layout.fillWidth: true
                        model: [
                            { text: qsTr("PNG"), value: 0 },
                            { text: qsTr("JPEG"), value: 1 },
                            { text: qsTr("BMP"), value: 2 },
                            { text: qsTr("WebP"), value: 3 },
                            { text: qsTr("TIFF"), value: 4 }
                        ]
                        textRole: "text"
                        valueRole: "value"
                        Component.onCompleted: updateIndex()
                        onActivated: settingsStore.outputFormat = model[index].value
                        function updateIndex() {
                            for (var i = 0; i < model.length; ++i) {
                                if (model[i].value === settingsStore.outputFormat) {
                                    currentIndex = i
                                    break
                                }
                            }
                        }
                        label: qsTr("Output format")
                    }

                    Connections {
                        target: settingsStore
                        function onOutputFormatChanged() { formatCombo.updateIndex() }
                    }

                    SwitchDelegate {
                        text: qsTr("Copy captures to clipboard automatically")
                        checked: settingsStore.autoCopyToClipboard
                        onToggled: settingsStore.autoCopyToClipboard = checked
                    }

                    SwitchDelegate {
                        text: qsTr("Auto-save captures to folder")
                        checked: settingsStore.autoSaveSnapshots
                        onToggled: settingsStore.autoSaveSnapshots = checked
                    }

                    RowLayout {
                        spacing: 8
                        visible: settingsStore.autoSaveSnapshots

                        Label {
                            text: qsTr("Save location:")
                        }

                        TextField {
                            Layout.fillWidth: true
                            text: settingsStore.saveDirectory
                            onEditingFinished: settingsStore.saveDirectory = text
                        }

                        Button {
                            text: qsTr("Browse")
                            onClicked: directoryDialog.open()
                        }
                    }
                }
            }

            GroupBox {
                title: qsTr("Hotkeys")
                Layout.fillWidth: true
                ColumnLayout {
                    anchors.fill: parent
                    spacing: 12

                    TextField {
                        Layout.fillWidth: true
                        text: settingsStore.windowCaptureHotkey
                        placeholderText: qsTr("Window capture hotkey")
                        onEditingFinished: settingsStore.windowCaptureHotkey = text
                    }

                    TextField {
                        Layout.fillWidth: true
                        text: settingsStore.regionCaptureHotkey
                        placeholderText: qsTr("Region capture hotkey")
                        onEditingFinished: settingsStore.regionCaptureHotkey = text
                    }
                }
            }

            GroupBox {
                title: qsTr("Depth effect")
                Layout.fillWidth: true
                ColumnLayout {
                    anchors.fill: parent
                    spacing: 12

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4
                        Label { text: qsTr("Shadow radius: %1").arg(Math.round(shadowSlider.value)) }
                        Slider {
                            id: shadowSlider
                            from: 0
                            to: 80
                            value: settingsStore.depthShadowRadius
                            Layout.fillWidth: true
                            onValueChanged: settingsStore.depthShadowRadius = Math.round(value)
                            ToolTip.visible: pressed
                            ToolTip.text: Math.round(value)
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4
                        Label { text: qsTr("Blur radius: %1").arg(Math.round(blurSlider.value)) }
                        Slider {
                            id: blurSlider
                            from: 0
                            to: 30
                            value: settingsStore.depthBlurRadius
                            Layout.fillWidth: true
                            onValueChanged: settingsStore.depthBlurRadius = Math.round(value)
                            ToolTip.visible: pressed
                            ToolTip.text: Math.round(value)
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4
                        Label { text: qsTr("Shadow opacity: %1").arg(opacitySlider.value.toFixed(2)) }
                        Slider {
                            id: opacitySlider
                            from: 0
                            to: 1
                            stepSize: 0.05
                            value: settingsStore.depthShadowOpacity
                            Layout.fillWidth: true
                            onValueChanged: settingsStore.depthShadowOpacity = value
                            ToolTip.visible: pressed
                            ToolTip.text: value.toFixed(2)
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4
                        Label { text: qsTr("Corner radius: %1").arg(Math.round(cornerSlider.value)) }
                        Slider {
                            id: cornerSlider
                            from: 0
                            to: 64
                            value: settingsStore.depthCornerRadius
                            Layout.fillWidth: true
                            onValueChanged: settingsStore.depthCornerRadius = Math.round(value)
                            ToolTip.visible: pressed
                            ToolTip.text: Math.round(value)
                        }
                    }
                }
            }
        }
    }

    Platform.FolderDialog {
        id: directoryDialog
        currentFolder: Platform.StandardPaths.writableLocation(Platform.StandardPaths.PicturesLocation)
        onAccepted: settingsStore.saveDirectory = file.toLocalFile()
    }

    onAccepted: preferences.visible = false
    onRejected: preferences.visible = false
}
