#pragma once

#include <QObject>

class PermissionHelper : public QObject
{
    Q_OBJECT
public:
    explicit PermissionHelper(QObject *parent = nullptr)
        : QObject(parent)
    {
    }

    ~PermissionHelper() override = default;

    virtual bool hasScreenCapturePermission() const = 0;
    virtual bool ensureScreenCapturePermission() = 0;
};
