#pragma once

#include <QObject>
#include <memory>

class QGuiApplication;
class QQmlApplicationEngine;
class QSystemTrayIcon;

class SettingsStore;
class CaptureOrchestrator;
class ClipboardExportService;
class DepthStyler;
class GlobalHotkeyService;
class PlatformCaptureAdapter;
class PermissionHelper;
class OverlayManager;
class AnnotationHistory;

class AppCoordinator : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool preferencesVisible READ preferencesVisible WRITE setPreferencesVisible NOTIFY preferencesVisibleChanged)
public:
    explicit AppCoordinator(QObject *parent = nullptr);
    ~AppCoordinator() override;

    bool initialize(QGuiApplication *app, QQmlApplicationEngine *engine);

    SettingsStore *settings() const;
    CaptureOrchestrator *captureOrchestrator() const;
    OverlayManager *overlayManager() const;
    AnnotationHistory *annotationHistory() const;
    bool preferencesVisible() const;

    Q_INVOKABLE void openPreferences();
    Q_INVOKABLE void quit();

public slots:
    void setPreferencesVisible(bool visible);

signals:
    void fatalErrorOccurred(const QString &message);
    void preferencesVisibleChanged();

private:
    bool setupServices(QGuiApplication *app);
    void registerQmlSingletons(QQmlApplicationEngine *engine);
    void setupSystemTray(QGuiApplication *app);
    void connectHotkeys();
    std::unique_ptr<SettingsStore> m_settings;
    std::unique_ptr<ClipboardExportService> m_clipboardService;
    std::unique_ptr<DepthStyler> m_depthStyler;
    std::unique_ptr<PermissionHelper> m_permissionHelper;
    std::unique_ptr<PlatformCaptureAdapter> m_captureAdapter;
    std::unique_ptr<GlobalHotkeyService> m_hotkeyService;
    std::unique_ptr<CaptureOrchestrator> m_captureOrchestrator;
    std::unique_ptr<OverlayManager> m_overlayManager;
    std::unique_ptr<AnnotationHistory> m_annotationHistory;

    std::unique_ptr<QSystemTrayIcon> m_trayIcon;
    bool m_preferencesVisible = false;
};
