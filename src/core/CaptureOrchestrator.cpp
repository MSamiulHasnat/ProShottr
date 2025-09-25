#include "CaptureOrchestrator.hpp"

#include "ClipboardExportService.hpp"
#include "SettingsStore.hpp"
#include "../platform/common/PermissionHelper.hpp"
#include "PlatformCaptureAdapter.hpp"
#include "../ui/AnnotationHistory.hpp"
#include "../ui/OverlayManager.hpp"

#include <QBuffer>
#include <QGuiApplication>
#include <QImageWriter>
#include <QRegularExpression>
#include <QtMath>

CaptureOrchestrator::CaptureOrchestrator(SettingsStore *settings,
                                         ClipboardExportService *clipboard,
                                         DepthStyler *styler,
                                         PlatformCaptureAdapter *adapter,
                                         PermissionHelper *permissionHelper,
                                         QObject *parent)
    : QObject(parent)
    , m_settings(settings)
    , m_clipboard(clipboard)
    , m_styler(styler)
    , m_adapter(adapter)
    , m_permissionHelper(permissionHelper)
{
}

void CaptureOrchestrator::setOverlayManager(OverlayManager *overlayManager)
{
    m_overlayManager = overlayManager;
}

void CaptureOrchestrator::setAnnotationHistory(AnnotationHistory *history)
{
    m_annotationHistory = history;
}

CaptureOrchestrator::State CaptureOrchestrator::state() const
{
    return m_state;
}

QString CaptureOrchestrator::capturedImageUrl() const
{
    return m_capturedImageUrl;
}

bool CaptureOrchestrator::hasCapture() const
{
    return !m_capturedImageUrl.isEmpty();
}

QString CaptureOrchestrator::statusMessage() const
{
    return m_statusMessage;
}

void CaptureOrchestrator::startWindowCapture()
{
    if (!ensurePermission()) {
        emit captureFailed(tr("Screen capture permission required."));
        return;
    }

    resetCaptureState();
    transitionTo(State::TargetWindow);
    updateStatus(tr("Hover a window and click to capture"));
    if (m_overlayManager) {
        m_overlayManager->showOverlay();
    }
}

void CaptureOrchestrator::startRegionCapture()
{
    if (!ensurePermission()) {
        emit captureFailed(tr("Screen capture permission required."));
        return;
    }

    resetCaptureState();
    transitionTo(State::TargetRegion);
    updateStatus(tr("Drag a region to capture"));
    if (m_overlayManager) {
        m_overlayManager->showOverlay();
    }
}

void CaptureOrchestrator::cancelCapture()
{
    if (m_overlayManager) {
        m_overlayManager->hideOverlay();
    }
    resetCaptureState();
    transitionTo(State::Idle);
    updateStatus(QString());
}

void CaptureOrchestrator::confirmWindowCapture(qulonglong handle)
{
    if (!m_adapter) {
        return;
    }

    const auto result = m_adapter->captureWindowHandle(static_cast<quintptr>(handle));
    if (!result.isValid()) {
        emit captureFailed(tr("Unable to capture window"));
        return;
    }

    prepareAnnotation(result.image, result);
}

void CaptureOrchestrator::confirmRegionCapture(const QRectF &region, qreal devicePixelRatio)
{
    if (!m_adapter || region.isEmpty()) {
        return;
    }

    const QRect pixelRect = QRect(QPoint(qRound(region.x()), qRound(region.y())), QSize(qRound(region.width()), qRound(region.height())));
    const auto result = m_adapter->captureRegion(pixelRect, devicePixelRatio);
    if (!result.isValid()) {
        emit captureFailed(tr("Unable to capture region"));
        return;
    }

    prepareAnnotation(result.image, result);
}

void CaptureOrchestrator::finalizeCapture(const QString &dataUrl, bool hasAnnotations)
{
    QImage finalImage = hasAnnotations ? decodeDataUrl(dataUrl) : m_lastImage;
    if (finalImage.isNull()) {
        emit captureFailed(tr("No image produced from annotation"));
        cancelCapture();
        return;
    }

    if (!m_lastWindowTitle.isEmpty()) {
        finalImage.setText(QStringLiteral("windowTitle"), m_lastWindowTitle);
    }

    if (m_clipboard && (!m_settings || m_settings->autoCopyToClipboard())) {
        m_clipboard->copyToClipboard(finalImage);
    }

    if (m_clipboard && m_settings && m_settings->autoSaveSnapshots()) {
        QString exportedPath;
        m_clipboard->saveSnapshot(finalImage, &exportedPath);
    }

    if (m_annotationHistory) {
        m_annotationHistory->clear();
    }

    cancelCapture();
}

void CaptureOrchestrator::resetCaptureState()
{
    m_capturedImageUrl.clear();
    m_lastImage = QImage();
    m_lastWindowTitle.clear();
    emit capturedImageChanged();
}

void CaptureOrchestrator::transitionTo(State state)
{
    if (m_state == state) {
        return;
    }
    m_state = state;
    emit stateChanged();
}

bool CaptureOrchestrator::ensurePermission()
{
    if (!m_permissionHelper) {
        return true;
    }
    if (m_permissionHelper->hasScreenCapturePermission()) {
        return true;
    }
    return m_permissionHelper->ensureScreenCapturePermission();
}

void CaptureOrchestrator::updateStatus(const QString &message)
{
    if (m_statusMessage == message) {
        return;
    }
    m_statusMessage = message;
    emit statusMessageChanged(message);
}

void CaptureOrchestrator::prepareAnnotation(const QImage &image, const PlatformCaptureAdapter::CaptureResult &metadata)
{
    if (m_overlayManager) {
        m_overlayManager->hideOverlay();
    }

    DepthOptions options = depthOptionsFromSettings();
    QImage styled = m_styler ? m_styler->apply(image, options) : image;
    m_lastImage = styled;
    m_lastWindowTitle = metadata.windowTitle;
    m_lastImage.setText(QStringLiteral("windowTitle"), m_lastWindowTitle);

    QByteArray buffer;
    QBuffer device(&buffer);
    device.open(QIODevice::WriteOnly);
    QImageWriter writer(&device, "png");
    writer.setQuality(100);
    writer.write(styled);
    device.close();

    m_capturedImageUrl = QStringLiteral("data:image/png;base64,%1").arg(QString::fromLatin1(buffer.toBase64()));
    emit capturedImageChanged();

    transitionTo(State::Annotating);
    emit showAnnotationRequested();
    updateStatus(tr("Annotate your capture"));
}

DepthOptions CaptureOrchestrator::depthOptionsFromSettings() const
{
    DepthOptions options;
    if (!m_settings) {
        return options;
    }
    options.shadowRadius = m_settings->depthShadowRadius();
    options.shadowOpacity = m_settings->depthShadowOpacity();
    options.blurRadius = m_settings->depthBlurRadius();
    options.cornerRadius = m_settings->depthCornerRadius();
    return options;
}

QImage CaptureOrchestrator::decodeDataUrl(const QString &dataUrl) const
{
    static const QRegularExpression dataUrlExpression(QStringLiteral(R"(data:image/(png|jpeg|jpg|bmp|webp|tiff);base64,(.*))"));
    const auto match = dataUrlExpression.match(dataUrl);
    if (!match.hasMatch()) {
        return {};
    }
    const QByteArray base64 = match.captured(2).toLatin1();
    const QByteArray raw = QByteArray::fromBase64(base64);
    QImage image;
    image.loadFromData(raw);
    return image;
}
