set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)
set(CMAKE_AUTOUIC ON)

find_package(Qt6 6.5 REQUIRED COMPONENTS Quick Gui Qml QuickControls2 Widgets)

set(PROSHOTTR_SOURCES
    app/main.cpp
    app/AppBootstrap.cpp
    app/AppBootstrap.hpp
    app/AppCoordinator.cpp
    app/AppCoordinator.hpp
    core/SettingsStore.cpp
    core/SettingsStore.hpp
    core/CaptureOrchestrator.cpp
    core/CaptureOrchestrator.hpp
    core/ClipboardExportService.cpp
    core/ClipboardExportService.hpp
    core/DepthStyler.cpp
    core/DepthStyler.hpp
    core/GlobalHotkeyService.hpp
    core/PlatformCaptureAdapter.hpp
    platform/common/PermissionHelper.hpp
    platform/windows/WindowsCaptureAdapter.cpp
    platform/windows/WindowsCaptureAdapter.hpp
    platform/windows/WindowsHotkeyService.cpp
    platform/windows/WindowsHotkeyService.hpp
    platform/windows/WindowsPermissionHelper.cpp
    platform/windows/WindowsPermissionHelper.hpp
    ui/OverlayManager.cpp
    ui/OverlayManager.hpp
    ui/AnnotationCommand.hpp
    ui/AnnotationHistory.cpp
    ui/AnnotationHistory.hpp
)

qt_add_executable(ProShottr WIN32 MACOSX_BUNDLE
    ${PROSHOTTR_SOURCES}
    resources/proshottr.qrc
)

qt_add_qml_module(ProShottr
    URI ProShottr
    VERSION 1.0
    QML_FILES
        ../qml/Main.qml
        ../qml/Overlay.qml
        ../qml/AnnotationCanvas.qml
    ../qml/PreferencesWindow.qml
        ../qml/Toolbar.qml
)

target_include_directories(ProShottr PRIVATE ${CMAKE_CURRENT_SOURCE_DIR})

if(WIN32)
    target_link_libraries(ProShottr
        PRIVATE
            Qt6::Quick
            Qt6::Gui
            Qt6::Qml
            Qt6::QuickControls2
            Qt6::Widgets
            d3d11
            dxgi
            dwmapi
            gdi32
            user32
    )
else()
    target_link_libraries(ProShottr
        PRIVATE
            Qt6::Quick
            Qt6::Gui
            Qt6::Qml
            Qt6::QuickControls2
            Qt6::Widgets
    )
endif()

if(MSVC)
    target_compile_options(ProShottr PRIVATE /W4 /permissive-)
else()
    target_compile_options(ProShottr PRIVATE -Wall -Wextra -Wpedantic)
endif()
