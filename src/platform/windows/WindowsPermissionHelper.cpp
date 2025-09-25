#include "WindowsPermissionHelper.hpp"

#ifdef Q_OS_WIN
#    include <windows.h>
#endif

WindowsPermissionHelper::WindowsPermissionHelper(QObject *parent)
    : PermissionHelper(parent)
{
}

bool WindowsPermissionHelper::hasScreenCapturePermission() const
{
#ifdef Q_OS_WIN
    // Windows currently does not expose explicit screen capture permission checks for desktop apps.
    // We optimistically assume permissions are available unless OS version enforces privacy settings.
    return true;
#else
    return true;
#endif
}

bool WindowsPermissionHelper::ensureScreenCapturePermission()
{
#ifdef Q_OS_WIN
    return hasScreenCapturePermission();
#else
    return true;
#endif
}
