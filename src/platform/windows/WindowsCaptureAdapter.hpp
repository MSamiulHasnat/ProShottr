#pragma once

#include "../../core/PlatformCaptureAdapter.hpp"

#ifdef Q_OS_WIN
#    include <windows.h>
#endif

class WindowsCaptureAdapter : public PlatformCaptureAdapter
{
    Q_OBJECT
public:
    explicit WindowsCaptureAdapter(QObject *parent = nullptr);

    bool initialize() override;
    CaptureResult captureWindowAt(const QPoint &cursorPosition) override;
    CaptureResult captureWindowHandle(quintptr handle) override;
    CaptureResult captureRegion(const QRect &region, qreal devicePixelRatio) override;
    QRect windowGeometryAt(const QPoint &cursorPosition) const override;
    QString windowTitleAt(const QPoint &cursorPosition) const override;
    quintptr windowHandleAt(const QPoint &cursorPosition) const override;

private:
#ifdef Q_OS_WIN
    static HWND windowFromGlobalPoint(const POINT &point);
    static QRect fromRECT(const RECT &rect);
    static CaptureResult captureFromWindow(HWND hwnd);
    static CaptureResult captureFromRegion(const QRect &region);
    static QString windowTitle(HWND hwnd);
    static QRect windowFrameGeometry(HWND hwnd);
#endif
};
