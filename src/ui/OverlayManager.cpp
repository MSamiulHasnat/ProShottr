#include "OverlayManager.hpp"

#include "../core/PlatformCaptureAdapter.hpp"

#include <QGuiApplication>
#include <QPointer>
#include <QQuickWindow>

OverlayManager::OverlayManager(QObject *parent)
    : QObject(parent)
{
}

void OverlayManager::setCaptureAdapter(PlatformCaptureAdapter *adapter)
{
    m_captureAdapter = adapter;
}

bool OverlayManager::overlayVisible() const
{
    return m_overlayVisible;
}

void OverlayManager::registerOverlayWindow(QObject *overlayRoot)
{
    auto *window = qobject_cast<QQuickWindow *>(overlayRoot);
    if (window) {
        m_overlayWindow = window;
    }
}

QVariantMap OverlayManager::windowInfoAtPoint(const QPointF &point) const
{
    if (!m_captureAdapter || !m_overlayWindow) {
        return {};
    }

    const QPoint globalPoint = m_overlayWindow->mapToGlobal(point.toPoint());
    const QRect geometry = m_captureAdapter->windowGeometryAt(globalPoint);
    const QString title = m_captureAdapter->windowTitleAt(globalPoint);
    const quintptr handle = m_captureAdapter->windowHandleAt(globalPoint);

    QVariantMap info;
    info.insert(QStringLiteral("geometry"), QRectF(geometry));
    info.insert(QStringLiteral("title"), title);
    info.insert(QStringLiteral("handle"), static_cast<qulonglong>(handle));
    return info;
}

void OverlayManager::hideOverlay()
{
    if (m_overlayWindow) {
        m_overlayWindow->setVisible(false);
    }
    if (!m_overlayVisible) {
        return;
    }
    m_overlayVisible = false;
    emit overlayVisibleChanged();
}

void OverlayManager::showOverlay()
{
    if (m_overlayWindow) {
        m_overlayWindow->setVisible(true);
        m_overlayWindow->raise();
        m_overlayWindow->requestActivate();
    }
    if (m_overlayVisible) {
        return;
    }
    m_overlayVisible = true;
    emit overlayVisibleChanged();
}

QPointF OverlayManager::overlayToGlobal(const QPointF &point) const
{
    if (!m_overlayWindow) {
        return point;
    }
    return m_overlayWindow->mapToGlobal(point.toPoint());
}

QPointF OverlayManager::globalToOverlay(const QPointF &point) const
{
    if (!m_overlayWindow) {
        return point;
    }
    return m_overlayWindow->mapFromGlobal(point.toPoint());
}
