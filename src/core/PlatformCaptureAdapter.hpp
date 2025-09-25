#pragma once

#include <QImage>
#include <QObject>
#include <QPoint>
#include <QRect>
#include <QString>

class PlatformCaptureAdapter : public QObject
{
    Q_OBJECT
public:
    struct CaptureResult
    {
        QImage image;
        QRect captureRect;
        QString windowTitle;
        quintptr windowHandle = 0;

        bool isValid() const
        {
            return !image.isNull() && captureRect.isValid();
        }
    };

    explicit PlatformCaptureAdapter(QObject *parent = nullptr)
        : QObject(parent)
    {
    }

    ~PlatformCaptureAdapter() override = default;

    virtual bool initialize() = 0;
    virtual CaptureResult captureWindowAt(const QPoint &cursorPosition) = 0;
    virtual CaptureResult captureWindowHandle(quintptr handle) = 0;
    virtual CaptureResult captureRegion(const QRect &region, qreal devicePixelRatio) = 0;
    virtual QRect windowGeometryAt(const QPoint &cursorPosition) const = 0;
    virtual QString windowTitleAt(const QPoint &cursorPosition) const = 0;
    virtual quintptr windowHandleAt(const QPoint &cursorPosition) const = 0;
};
