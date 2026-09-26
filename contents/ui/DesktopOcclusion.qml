import QtQuick
import org.kde.taskmanager as TaskManager
import org.kde.kwindowsystem

Item {
    id: root
    property rect screenGeometry
    property bool covered: false
    function refresh() {
        let blocked = false
        for (let i = 0; i < windows.count; ++i) {
            const item = windows.objectAt(i)
            if (item && item.blocks) blocked = true
        }
        covered = blocked && !KWindowSystem.showingDesktop
    }
    Connections {
        target: KWindowSystem
        function onShowingDesktopChanged() { root.refresh() }
    }
    TaskManager.VirtualDesktopInfo { id: desktops }
    TaskManager.ActivityInfo { id: activities }
    TaskManager.TasksModel {
        id: tasks
        groupMode: TaskManager.TasksModel.GroupDisabled
        filterByScreen: true
        screenGeometry: root.screenGeometry
        filterByVirtualDesktop: true
        virtualDesktop: desktops.currentDesktop
        filterByActivity: true
        activity: activities.currentActivity
    }
    Instantiator {
        id: windows
        model: tasks
        delegate: QtObject {
            required property var model
            // Conservative: never sleep for a small, inactive or minimized window.
            property bool blocks: model.IsWindow && model.IsActive && !model.IsMinimized
                                  && (model.IsMaximized || model.IsFullScreen)
            onBlocksChanged: Qt.callLater(root.refresh)
        }
        onObjectAdded: Qt.callLater(root.refresh)
        onObjectRemoved: Qt.callLater(root.refresh)
    }
}
