#include "SettingsStore.hpp"

#include <QDir>
#include <QStandardPaths>
#include <QMutexLocker>

namespace
{
constexpr auto kOutputFormatKey = "capture/outputFormat";
constexpr auto kAutoCopyKey = "capture/autoCopyToClipboard";
constexpr auto kAutoSaveKey = "capture/autoSave";
constexpr auto kSaveDirectoryKey = "capture/saveDirectory";
constexpr auto kWindowHotkeyKey = "hotkeys/windowCapture";
constexpr auto kRegionHotkeyKey = "hotkeys/regionCapture";
constexpr auto kShadowRadiusKey = "depth/shadowRadius";
constexpr auto kShadowOpacityKey = "depth/shadowOpacity";
constexpr auto kBlurRadiusKey = "depth/blurRadius";
constexpr auto kCornerRadiusKey = "depth/cornerRadius";

QString defaultSaveDirectory()
{
    const QString pictures = QStandardPaths::writableLocation(QStandardPaths::PicturesLocation);
    if (!pictures.isEmpty()) {
        return pictures + QDir::separator() + QStringLiteral("ProShottr");
    }
    return QDir::homePath() + QDir::separator() + QStringLiteral("ProShottr");
}

} // namespace

SettingsStore::SettingsStore(QObject *parent)
    : QObject(parent)
    , m_settings(QStringLiteral("ProShottr"), QStringLiteral("ProShottr"))
{
    if (!m_settings.contains(kOutputFormatKey)) {
        syncImmediate(kOutputFormatKey, static_cast<int>(ImageFormat::Png));
    }
    if (!m_settings.contains(kAutoCopyKey)) {
        syncImmediate(kAutoCopyKey, true);
    }
    if (!m_settings.contains(kAutoSaveKey)) {
        syncImmediate(kAutoSaveKey, false);
    }
    if (!m_settings.contains(kSaveDirectoryKey)) {
        syncImmediate(kSaveDirectoryKey, defaultSaveDirectory());
    }
    if (!m_settings.contains(kWindowHotkeyKey)) {
        syncImmediate(kWindowHotkeyKey, QStringLiteral("Meta+Shift+3"));
    }
    if (!m_settings.contains(kRegionHotkeyKey)) {
        syncImmediate(kRegionHotkeyKey, QStringLiteral("Meta+Shift+4"));
    }
    if (!m_settings.contains(kShadowRadiusKey)) {
        syncImmediate(kShadowRadiusKey, 24);
    }
    if (!m_settings.contains(kShadowOpacityKey)) {
        syncImmediate(kShadowOpacityKey, 0.35);
    }
    if (!m_settings.contains(kBlurRadiusKey)) {
        syncImmediate(kBlurRadiusKey, 8);
    }
    if (!m_settings.contains(kCornerRadiusKey)) {
        syncImmediate(kCornerRadiusKey, 18);
    }
}

SettingsStore::ImageFormat SettingsStore::outputFormat() const
{
    const int value = m_settings.value(kOutputFormatKey, static_cast<int>(ImageFormat::Png)).toInt();
    return static_cast<ImageFormat>(value);
}

void SettingsStore::setOutputFormat(ImageFormat format)
{
    if (format == outputFormat()) {
        return;
    }
    syncImmediate(kOutputFormatKey, static_cast<int>(format));
    emit outputFormatChanged();
}

bool SettingsStore::autoCopyToClipboard() const
{
    return m_settings.value(kAutoCopyKey, true).toBool();
}

void SettingsStore::setAutoCopyToClipboard(bool value)
{
    if (value == autoCopyToClipboard()) {
        return;
    }
    syncImmediate(kAutoCopyKey, value);
    emit autoCopyToClipboardChanged();
}

bool SettingsStore::autoSaveSnapshots() const
{
    return m_settings.value(kAutoSaveKey, false).toBool();
}

void SettingsStore::setAutoSaveSnapshots(bool value)
{
    if (value == autoSaveSnapshots()) {
        return;
    }
    syncImmediate(kAutoSaveKey, value);
    emit autoSaveSnapshotsChanged();
}

QString SettingsStore::saveDirectory() const
{
    return m_settings.value(kSaveDirectoryKey, defaultSaveDirectory()).toString();
}

void SettingsStore::setSaveDirectory(const QString &directory)
{
    if (directory == saveDirectory()) {
        return;
    }
    syncImmediate(kSaveDirectoryKey, directory);
    emit saveDirectoryChanged();
}

QString SettingsStore::windowCaptureHotkey() const
{
    return m_settings.value(kWindowHotkeyKey).toString();
}

void SettingsStore::setWindowCaptureHotkey(const QString &sequence)
{
    if (sequence == windowCaptureHotkey()) {
        return;
    }
    syncImmediate(kWindowHotkeyKey, sequence);
    emit windowCaptureHotkeyChanged(sequence);
}

QString SettingsStore::regionCaptureHotkey() const
{
    return m_settings.value(kRegionHotkeyKey).toString();
}

void SettingsStore::setRegionCaptureHotkey(const QString &sequence)
{
    if (sequence == regionCaptureHotkey()) {
        return;
    }
    syncImmediate(kRegionHotkeyKey, sequence);
    emit regionCaptureHotkeyChanged(sequence);
}

int SettingsStore::depthShadowRadius() const
{
    return m_settings.value(kShadowRadiusKey, 24).toInt();
}

void SettingsStore::setDepthShadowRadius(int radius)
{
    if (radius == depthShadowRadius()) {
        return;
    }
    syncImmediate(kShadowRadiusKey, radius);
    emit depthShadowRadiusChanged();
}

double SettingsStore::depthShadowOpacity() const
{
    return m_settings.value(kShadowOpacityKey, 0.35).toDouble();
}

void SettingsStore::setDepthShadowOpacity(double opacity)
{
    if (qFuzzyCompare(opacity, depthShadowOpacity())) {
        return;
    }
    syncImmediate(kShadowOpacityKey, opacity);
    emit depthShadowOpacityChanged();
}

int SettingsStore::depthBlurRadius() const
{
    return m_settings.value(kBlurRadiusKey, 8).toInt();
}

void SettingsStore::setDepthBlurRadius(int radius)
{
    if (radius == depthBlurRadius()) {
        return;
    }
    syncImmediate(kBlurRadiusKey, radius);
    emit depthBlurRadiusChanged();
}

int SettingsStore::depthCornerRadius() const
{
    return m_settings.value(kCornerRadiusKey, 18).toInt();
}

void SettingsStore::setDepthCornerRadius(int radius)
{
    if (radius == depthCornerRadius()) {
        return;
    }
    syncImmediate(kCornerRadiusKey, radius);
    emit depthCornerRadiusChanged();
}

void SettingsStore::syncImmediate(const QString &key, const QVariant &value)
{
    const QMutexLocker locker(&m_mutex);
    m_settings.setValue(key, value);
    m_settings.sync();
}
