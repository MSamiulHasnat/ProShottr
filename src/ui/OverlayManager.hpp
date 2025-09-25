#pragma once

#include <QObject>
#include <QPointer>
#include <QVariantMap>

class PlatformCaptureAdapter;
class QQuickWindow;

class OverlayManager : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool overlayVisible READ overlayVisible NOTIFY overlayVisibleChanged)

public:
    explicit OverlayManager(QObject *parent = nullptr);

    void setCaptureAdapter(PlatformCaptureAdapter *adapter);

    bool overlayVisible() const;

    Q_INVOKABLE void registerOverlayWindow(QObject *overlayRoot);
    Q_INVOKABLE QVariantMap windowInfoAtPoint(const QPointF &point) const;
    Q_INVOKABLE void hideOverlay();
    Q_INVOKABLE QPointF overlayToGlobal(const QPointF &point) const;
    Q_INVOKABLE QPointF globalToOverlay(const QPointF &point) const;

public slots:
    void showOverlay();

signals:
    void overlayVisibleChanged();
    void windowHoverChanged(const QVariantMap &info) const;

private:
    PlatformCaptureAdapter *m_captureAdapter = nullptr;
    QPointer<QQuickWindow> m_overlayWindow;
    bool m_overlayVisible = false;
};
