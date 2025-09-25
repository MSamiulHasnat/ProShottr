#pragma once

#include "DepthStyler.hpp"

#include <QObject>
#include <QPointF>
#include <QRectF>
#include <QString>

class SettingsStore;
class ClipboardExportService;
class PlatformCaptureAdapter;
class OverlayManager;
class AnnotationHistory;
class PermissionHelper;

class CaptureOrchestrator : public QObject
{
    Q_OBJECT
    Q_PROPERTY(State state READ state NOTIFY stateChanged)
    Q_PROPERTY(QString capturedImageUrl READ capturedImageUrl NOTIFY capturedImageChanged)
    Q_PROPERTY(bool hasCapture READ hasCapture NOTIFY capturedImageChanged)
    Q_PROPERTY(QString statusMessage READ statusMessage NOTIFY statusMessageChanged)

public:
    enum class State {
        Idle,
        TargetWindow,
        TargetRegion,
        Annotating
    };
    Q_ENUM(State)

    CaptureOrchestrator(SettingsStore *settings,
                        ClipboardExportService *clipboard,
                        DepthStyler *styler,
                        PlatformCaptureAdapter *adapter,
                        PermissionHelper *permissionHelper,
                        QObject *parent = nullptr);

    void setOverlayManager(OverlayManager *overlayManager);
    void setAnnotationHistory(AnnotationHistory *history);

    State state() const;
    QString capturedImageUrl() const;
    bool hasCapture() const;
    QString statusMessage() const;

    Q_INVOKABLE void startWindowCapture();
    Q_INVOKABLE void startRegionCapture();
    Q_INVOKABLE void cancelCapture();
    Q_INVOKABLE void confirmWindowCapture(qulonglong handle);
    Q_INVOKABLE void confirmRegionCapture(const QRectF &region, qreal devicePixelRatio);
    Q_INVOKABLE void finalizeCapture(const QString &dataUrl, bool hasAnnotations);

signals:
    void stateChanged();
    void capturedImageChanged();
    void statusMessageChanged(const QString &message);
    void showAnnotationRequested();
    void captureFailed(const QString &reason);

private:
    void resetCaptureState();
    void transitionTo(State state);
    bool ensurePermission();
    void updateStatus(const QString &message);
    void prepareAnnotation(const QImage &image, const PlatformCaptureAdapter::CaptureResult &metadata);
    DepthOptions depthOptionsFromSettings() const;
    QImage decodeDataUrl(const QString &dataUrl) const;

    SettingsStore *m_settings = nullptr;
    ClipboardExportService *m_clipboard = nullptr;
    DepthStyler *m_styler = nullptr;
    PlatformCaptureAdapter *m_adapter = nullptr;
    PermissionHelper *m_permissionHelper = nullptr;
    OverlayManager *m_overlayManager = nullptr;
    AnnotationHistory *m_annotationHistory = nullptr;

    State m_state = State::Idle;
    QString m_capturedImageUrl;
    QString m_statusMessage;
    QImage m_lastImage;
    QString m_lastWindowTitle;
};
