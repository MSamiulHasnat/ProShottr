import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Window 2.15
import ProShottr 1.0

Window {
    id: root
    visible: false
    width: 400
    height: 300
    color: "transparent"
    flags: Qt.Tool

    Overlay {
        id: captureOverlay
    }

    PreferencesWindow {
        id: preferencesWindow
        visible: appCoordinator.preferencesVisible
        onVisibleChanged: appCoordinator.setPreferencesVisible(visible)
    }
}
