#pragma once

#include "../../platform/common/PermissionHelper.hpp"

class WindowsPermissionHelper : public PermissionHelper
{
    Q_OBJECT
public:
    explicit WindowsPermissionHelper(QObject *parent = nullptr);

    bool hasScreenCapturePermission() const override;
    bool ensureScreenCapturePermission() override;
};
