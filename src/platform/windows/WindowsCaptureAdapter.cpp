#include "WindowsCaptureAdapter.hpp"

#include <QImage>
#include <QPoint>
#include <QRect>
#include <QString>

#ifdef Q_OS_WIN
#    include <dwmapi.h>
#    include <wingdi.h>
#    include <windowsx.h>
#endif

WindowsCaptureAdapter::WindowsCaptureAdapter(QObject *parent)
    : PlatformCaptureAdapter(parent)
{
}

bool WindowsCaptureAdapter::initialize()
{
    return true;
}

PlatformCaptureAdapter::CaptureResult WindowsCaptureAdapter::captureWindowAt(const QPoint &cursorPosition)
{
#ifdef Q_OS_WIN
    POINT point{cursorPosition.x(), cursorPosition.y()};
    HWND hwnd = windowFromGlobalPoint(point);
    if (!hwnd) {
        return {};
    }
    return captureFromWindow(hwnd);
#else
    Q_UNUSED(cursorPosition);
    return {};
#endif
}

PlatformCaptureAdapter::CaptureResult WindowsCaptureAdapter::captureWindowHandle(quintptr handle)
{
#ifdef Q_OS_WIN
    HWND hwnd = reinterpret_cast<HWND>(handle);
    if (!IsWindow(hwnd)) {
        return {};
    }
    return captureFromWindow(hwnd);
#else
    Q_UNUSED(handle);
    return {};
#endif
}

PlatformCaptureAdapter::CaptureResult WindowsCaptureAdapter::captureRegion(const QRect &region, qreal devicePixelRatio)
{
#ifdef Q_OS_WIN
    Q_UNUSED(devicePixelRatio);
    return captureFromRegion(region);
#else
    Q_UNUSED(region);
    Q_UNUSED(devicePixelRatio);
    return {};
#endif
}

QRect WindowsCaptureAdapter::windowGeometryAt(const QPoint &cursorPosition) const
{
#ifdef Q_OS_WIN
    POINT point{cursorPosition.x(), cursorPosition.y()};
    HWND hwnd = windowFromGlobalPoint(point);
    if (!hwnd) {
        return {};
    }
    return windowFrameGeometry(hwnd);
#else
    Q_UNUSED(cursorPosition);
    return {};
#endif
}

QString WindowsCaptureAdapter::windowTitleAt(const QPoint &cursorPosition) const
{
#ifdef Q_OS_WIN
    POINT point{cursorPosition.x(), cursorPosition.y()};
    HWND hwnd = windowFromGlobalPoint(point);
    if (!hwnd) {
        return {};
    }
    return windowTitle(hwnd);
#else
    Q_UNUSED(cursorPosition);
    return {};
#endif
}

quintptr WindowsCaptureAdapter::windowHandleAt(const QPoint &cursorPosition) const
{
#ifdef Q_OS_WIN
    POINT point{cursorPosition.x(), cursorPosition.y()};
    HWND hwnd = windowFromGlobalPoint(point);
    return reinterpret_cast<quintptr>(hwnd);
#else
    Q_UNUSED(cursorPosition);
    return 0;
#endif
}

#ifdef Q_OS_WIN

namespace
{

QImage imageFromBitmap(HBITMAP hBitmap, int width, int height)
{
    QImage image(width, height, QImage::Format_ARGB32);
    if (image.isNull()) {
        return {};
    }

    HDC hdc = GetDC(nullptr);
    BITMAPINFO bmi;
    ZeroMemory(&bmi, sizeof(bmi));
    bmi.bmiHeader.biSize = sizeof(BITMAPINFOHEADER);
    bmi.bmiHeader.biWidth = width;
    bmi.bmiHeader.biHeight = -height;
    bmi.bmiHeader.biPlanes = 1;
    bmi.bmiHeader.biBitCount = 32;
    bmi.bmiHeader.biCompression = BI_RGB;

    if (!GetDIBits(hdc, hBitmap, 0, static_cast<UINT>(height), image.bits(), &bmi, DIB_RGB_COLORS)) {
        ReleaseDC(nullptr, hdc);
        return {};
    }
    ReleaseDC(nullptr, hdc);
    return image;
}

}

HWND WindowsCaptureAdapter::windowFromGlobalPoint(const POINT &point)
{
    HWND hwnd = WindowFromPoint(point);
    while (hwnd && GetAncestor(hwnd, GA_ROOT) != hwnd) {
        hwnd = GetAncestor(hwnd, GA_ROOT);
    }
    return hwnd;
}

QRect WindowsCaptureAdapter::fromRECT(const RECT &rect)
{
    return QRect(QPoint(rect.left, rect.top), QPoint(rect.right, rect.bottom));
}

PlatformCaptureAdapter::CaptureResult WindowsCaptureAdapter::captureFromWindow(HWND hwnd)
{
    RECT rect{};
    if (!GetWindowRect(hwnd, &rect)) {
        return {};
    }
    const QRect geometry = windowFrameGeometry(hwnd);
    const int width = geometry.width();
    const int height = geometry.height();

    HDC windowDC = GetWindowDC(hwnd);
    HDC memoryDC = CreateCompatibleDC(windowDC);
    HBITMAP bitmap = CreateCompatibleBitmap(windowDC, width, height);
    HGDIOBJ oldBitmap = SelectObject(memoryDC, bitmap);

    BOOL printResult = PrintWindow(hwnd, memoryDC, PW_RENDERFULLCONTENT);
    if (!printResult) {
        BitBlt(memoryDC, 0, 0, width, height, windowDC, geometry.left() - rect.left, geometry.top() - rect.top, SRCCOPY);
    }

    SelectObject(memoryDC, oldBitmap);
    ReleaseDC(hwnd, windowDC);
    DeleteDC(memoryDC);

    QImage image = imageFromBitmap(bitmap, width, height);
    DeleteObject(bitmap);

    CaptureResult result;
    result.image = image;
    result.captureRect = geometry;
    result.windowTitle = windowTitle(hwnd);
    result.windowHandle = reinterpret_cast<quintptr>(hwnd);
    return result;
}

PlatformCaptureAdapter::CaptureResult WindowsCaptureAdapter::captureFromRegion(const QRect &region)
{
    HDC screenDC = GetDC(nullptr);
    HDC memoryDC = CreateCompatibleDC(screenDC);
    HBITMAP bitmap = CreateCompatibleBitmap(screenDC, region.width(), region.height());
    HGDIOBJ old = SelectObject(memoryDC, bitmap);

    BitBlt(memoryDC, 0, 0, region.width(), region.height(), screenDC, region.left(), region.top(), SRCCOPY);

    SelectObject(memoryDC, old);
    ReleaseDC(nullptr, screenDC);
    DeleteDC(memoryDC);

    QImage image = imageFromBitmap(bitmap, region.width(), region.height());
    DeleteObject(bitmap);

    CaptureResult result;
    result.image = image;
    result.captureRect = region;
    result.windowTitle = QStringLiteral("Region Capture");
    return result;
}

QString WindowsCaptureAdapter::windowTitle(HWND hwnd)
{
    wchar_t buffer[512] = {0};
    const int length = GetWindowTextW(hwnd, buffer, 511);
    if (length <= 0) {
        return QStringLiteral("Untitled Window");
    }
    return QString::fromWCharArray(buffer, length);
}

QRect WindowsCaptureAdapter::windowFrameGeometry(HWND hwnd)
{
    RECT rect{};
    if (!GetWindowRect(hwnd, &rect)) {
        return {};
    }

    RECT extendedRect = rect;
    if (SUCCEEDED(DwmGetWindowAttribute(hwnd, DWMWA_EXTENDED_FRAME_BOUNDS, &extendedRect, sizeof(extendedRect)))) {
        rect = extendedRect;
    }
    return fromRECT(rect);
}

#endif
