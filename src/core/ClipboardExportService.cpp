#include "ClipboardExportService.hpp"

#include "SettingsStore.hpp"

#include <QClipboard>
#include <QDateTime>
#include <QDir>
#include <QGuiApplication>
#include <QImage>
#include <QMimeData>
#include <QRegularExpression>

ClipboardExportService::ClipboardExportService(SettingsStore *settings, QObject *parent)
    : QObject(parent)
    , m_settings(settings)
{
}

void ClipboardExportService::copyToClipboard(const QImage &image)
{
    if (image.isNull()) {
        return;
    }

    if (QClipboard *cb = clipboard()) {
        cb->setImage(image);
    }
}

bool ClipboardExportService::saveSnapshot(const QImage &image, QString *exportedPath)
{
    if (image.isNull() || !m_settings || !m_settings->autoSaveSnapshots()) {
        return false;
    }

    const QString directoryPath = m_settings->saveDirectory();
    QDir dir(directoryPath);
    if (!dir.exists()) {
        dir.mkpath(QStringLiteral("."));
    }

    const QString fileName = buildFileName(image.text(QStringLiteral("windowTitle")));
    const QString fullPath = dir.filePath(fileName);

    const QString format = imageFormatExtension();
    const bool ok = image.save(fullPath, format.toUtf8().constData());
    if (ok && exportedPath) {
        *exportedPath = fullPath;
    }
    return ok;
}

QClipboard *ClipboardExportService::clipboard() const
{
    return QGuiApplication::clipboard();
}

QString ClipboardExportService::buildFileName(const QString &windowTitle) const
{
    const QString sanitized = windowTitle.isEmpty() ? QStringLiteral("Snapshot") : windowTitle;
    const QString timestamp = QDateTime::currentDateTime().toString(QStringLiteral("yyyyMMdd_HHmmss"));
    QString base = sanitized;
    base.replace(QRegularExpression(QStringLiteral("[^A-Za-z0-9-_]")), QStringLiteral("_"));
    return QStringLiteral("%1_%2.%3").arg(base, timestamp, imageFormatExtension());
}

QString ClipboardExportService::imageFormatExtension() const
{
    if (!m_settings) {
        return QStringLiteral("png");
    }

    switch (m_settings->outputFormat()) {
    case SettingsStore::ImageFormat::Png:
        return QStringLiteral("png");
    case SettingsStore::ImageFormat::Jpeg:
        return QStringLiteral("jpg");
    case SettingsStore::ImageFormat::Bmp:
        return QStringLiteral("bmp");
    case SettingsStore::ImageFormat::Webp:
        return QStringLiteral("webp");
    case SettingsStore::ImageFormat::Tiff:
        return QStringLiteral("tiff");
    }
    return QStringLiteral("png");
}

QByteArray ClipboardExportService::formatMimeType() const
{
    if (!m_settings) {
        return QByteArrayLiteral("image/png");
    }
    switch (m_settings->outputFormat()) {
    case SettingsStore::ImageFormat::Png:
        return QByteArrayLiteral("image/png");
    case SettingsStore::ImageFormat::Jpeg:
        return QByteArrayLiteral("image/jpeg");
    case SettingsStore::ImageFormat::Bmp:
        return QByteArrayLiteral("image/bmp");
    case SettingsStore::ImageFormat::Webp:
        return QByteArrayLiteral("image/webp");
    case SettingsStore::ImageFormat::Tiff:
        return QByteArrayLiteral("image/tiff");
    }
    return QByteArrayLiteral("image/png");
}
