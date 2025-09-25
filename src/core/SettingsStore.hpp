#pragma once

#include <QKeySequence>
#include <QMutex>
#include <QObject>
#include <QSettings>
#include <QString>

class SettingsStore : public QObject
{
    Q_OBJECT
    Q_PROPERTY(ImageFormat outputFormat READ outputFormat WRITE setOutputFormat NOTIFY outputFormatChanged)
    Q_PROPERTY(bool autoCopyToClipboard READ autoCopyToClipboard WRITE setAutoCopyToClipboard NOTIFY autoCopyToClipboardChanged)
    Q_PROPERTY(bool autoSaveSnapshots READ autoSaveSnapshots WRITE setAutoSaveSnapshots NOTIFY autoSaveSnapshotsChanged)
    Q_PROPERTY(QString saveDirectory READ saveDirectory WRITE setSaveDirectory NOTIFY saveDirectoryChanged)
    Q_PROPERTY(QString windowCaptureHotkey READ windowCaptureHotkey WRITE setWindowCaptureHotkey NOTIFY windowCaptureHotkeyChanged)
    Q_PROPERTY(QString regionCaptureHotkey READ regionCaptureHotkey WRITE setRegionCaptureHotkey NOTIFY regionCaptureHotkeyChanged)
    Q_PROPERTY(int depthShadowRadius READ depthShadowRadius WRITE setDepthShadowRadius NOTIFY depthShadowRadiusChanged)
    Q_PROPERTY(double depthShadowOpacity READ depthShadowOpacity WRITE setDepthShadowOpacity NOTIFY depthShadowOpacityChanged)
    Q_PROPERTY(int depthBlurRadius READ depthBlurRadius WRITE setDepthBlurRadius NOTIFY depthBlurRadiusChanged)
    Q_PROPERTY(int depthCornerRadius READ depthCornerRadius WRITE setDepthCornerRadius NOTIFY depthCornerRadiusChanged)

public:
    enum class ImageFormat {
        Png,
        Jpeg,
        Bmp,
        Webp,
        Tiff
    };
    Q_ENUM(ImageFormat)

    explicit SettingsStore(QObject *parent = nullptr);

    ImageFormat outputFormat() const;
    void setOutputFormat(ImageFormat format);

    bool autoCopyToClipboard() const;
    void setAutoCopyToClipboard(bool value);

    bool autoSaveSnapshots() const;
    void setAutoSaveSnapshots(bool value);

    QString saveDirectory() const;
    void setSaveDirectory(const QString &directory);

    QString windowCaptureHotkey() const;
    void setWindowCaptureHotkey(const QString &sequence);

    QString regionCaptureHotkey() const;
    void setRegionCaptureHotkey(const QString &sequence);

    int depthShadowRadius() const;
    void setDepthShadowRadius(int radius);

    double depthShadowOpacity() const;
    void setDepthShadowOpacity(double opacity);

    int depthBlurRadius() const;
    void setDepthBlurRadius(int radius);

    int depthCornerRadius() const;
    void setDepthCornerRadius(int radius);

signals:
    void outputFormatChanged();
    void autoCopyToClipboardChanged();
    void autoSaveSnapshotsChanged();
    void saveDirectoryChanged();
    void windowCaptureHotkeyChanged(const QString &sequence);
    void regionCaptureHotkeyChanged(const QString &sequence);
    void depthShadowRadiusChanged();
    void depthShadowOpacityChanged();
    void depthBlurRadiusChanged();
    void depthCornerRadiusChanged();

private:
    void syncImmediate(const QString &key, const QVariant &value);
    template <typename T>
    T valueOrDefault(const QString &key, const T &defaultValue) const
    {
        return m_settings.value(key, QVariant::fromValue(defaultValue)).template value<T>();
    }

    static QString formatKey(ImageFormat format);

    mutable QMutex m_mutex;
    QSettings m_settings;
};
