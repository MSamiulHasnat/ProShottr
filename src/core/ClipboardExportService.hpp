#pragma once

#include <QObject>
#include <QPointer>
#include <QString>

class QClipboard;
class QImage;
class SettingsStore;

class ClipboardExportService : public QObject
{
    Q_OBJECT
public:
    explicit ClipboardExportService(SettingsStore *settings, QObject *parent = nullptr);

    void copyToClipboard(const QImage &image);
    bool saveSnapshot(const QImage &image, QString *exportedPath = nullptr);

private:
    QString buildFileName(const QString &windowTitle) const;
    QString imageFormatExtension() const;
    QByteArray formatMimeType() const;

    SettingsStore *m_settings = nullptr;
    QClipboard *clipboard() const;
};
