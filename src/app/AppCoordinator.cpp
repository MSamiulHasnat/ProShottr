#include "AppCoordinator.hpp"

#include "../core/CaptureOrchestrator.hpp"
#include "../core/ClipboardExportService.hpp"
#include "../core/SettingsStore.hpp"
#include "../core/DepthStyler.hpp"
#include "../core/PlatformCaptureAdapter.hpp"
#include "../ui/AnnotationCommand.hpp"
#include "../ui/AnnotationHistory.hpp"
#include "../ui/OverlayManager.hpp"
#include "../platform/windows/WindowsCaptureAdapter.hpp"
#include "../platform/windows/WindowsHotkeyService.hpp"
#include "../platform/windows/WindowsPermissionHelper.hpp"

#include <QAction>
#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QSystemTrayIcon>
#include <QMenu>
#include <QIcon>
#include <QPixmap>
#include <QPainter>
#include <QtQml>

AppCoordinator::AppCoordinator(QObject *parent)
    : QObject(parent)
{
}

AppCoordinator::~AppCoordinator() = default;

bool AppCoordinator::initialize(QGuiApplication *app, QQmlApplicationEngine *engine)
{
    if (!setupServices(app)) {
        return false;
    }

    registerQmlSingletons(engine);
    setupSystemTray(app);
    connectHotkeys();
    return true;
}

SettingsStore *AppCoordinator::settings() const
{
    return m_settings.get();
}

CaptureOrchestrator *AppCoordinator::captureOrchestrator() const
{
    return m_captureOrchestrator.get();
}

OverlayManager *AppCoordinator::overlayManager() const
{
    return m_overlayManager.get();
}

AnnotationHistory *AppCoordinator::annotationHistory() const
{
    return m_annotationHistory.get();
}

bool AppCoordinator::preferencesVisible() const
{
    return m_preferencesVisible;
}

void AppCoordinator::openPreferences()
{
    setPreferencesVisible(true);
}

void AppCoordinator::quit()
{
    QGuiApplication::quit();
}

void AppCoordinator::setPreferencesVisible(bool visible)
{
    if (m_preferencesVisible == visible) {
        return;
    }
    m_preferencesVisible = visible;
    emit preferencesVisibleChanged();
}

bool AppCoordinator::setupServices(QGuiApplication *app)
{
    Q_UNUSED(app);
    m_settings = std::make_unique<SettingsStore>();
    m_depthStyler = std::make_unique<DepthStyler>();
    m_clipboardService = std::make_unique<ClipboardExportService>(m_settings.get());
    m_permissionHelper = std::make_unique<WindowsPermissionHelper>();
    m_captureAdapter = std::make_unique<WindowsCaptureAdapter>();

    if (!m_captureAdapter->initialize()) {
        emit fatalErrorOccurred(tr("Failed to initialize capture subsystem"));
        return false;
    }

    m_hotkeyService = std::make_unique<WindowsHotkeyService>();
    m_overlayManager = std::make_unique<OverlayManager>();
    m_overlayManager->setCaptureAdapter(m_captureAdapter.get());
    m_annotationHistory = std::make_unique<AnnotationHistory>();

    m_captureOrchestrator = std::make_unique<CaptureOrchestrator>(
        m_settings.get(),
        m_clipboardService.get(),
        m_depthStyler.get(),
        m_captureAdapter.get(),
        m_permissionHelper.get());
    m_captureOrchestrator->setOverlayManager(m_overlayManager.get());
    m_captureOrchestrator->setAnnotationHistory(m_annotationHistory.get());

    connect(m_captureOrchestrator.get(), &CaptureOrchestrator::captureFailed, this, [this](const QString &message) {
        emit fatalErrorOccurred(message);
    });

    return true;
}

void AppCoordinator::registerQmlSingletons(QQmlApplicationEngine *engine)
{
    qmlRegisterSingletonInstance("ProShottr", 1, 0, "SettingsStore", m_settings.get());
    qmlRegisterSingletonInstance("ProShottr", 1, 0, "CaptureOrchestrator", m_captureOrchestrator.get());
    qmlRegisterSingletonInstance("ProShottr", 1, 0, "OverlayManager", m_overlayManager.get());
    qmlRegisterSingletonInstance("ProShottr", 1, 0, "AnnotationHistory", m_annotationHistory.get());
    qmlRegisterUncreatableType<AnnotationEnums>("ProShottr", 1, 0, "AnnotationEnums", "Enum container");

    engine->rootContext()->setContextProperty(QStringLiteral("appCoordinator"), this);
    engine->rootContext()->setContextProperty(QStringLiteral("settingsStore"), m_settings.get());
    engine->rootContext()->setContextProperty(QStringLiteral("captureOrchestrator"), m_captureOrchestrator.get());
    engine->rootContext()->setContextProperty(QStringLiteral("overlayManager"), m_overlayManager.get());
    engine->rootContext()->setContextProperty(QStringLiteral("annotationHistory"), m_annotationHistory.get());
}

void AppCoordinator::setupSystemTray(QGuiApplication *app)
{
    if (!QSystemTrayIcon::isSystemTrayAvailable()) {
        return;
    }

    auto menu = new QMenu();
    auto captureWindowAction = menu->addAction(tr("Capture Window"));
    auto captureRegionAction = menu->addAction(tr("Capture Region"));
    menu->addSeparator();
    auto preferencesAction = menu->addAction(tr("Preferences"));
    auto quitAction = menu->addAction(tr("Quit"));

    QIcon trayIcon = QIcon::fromTheme(QStringLiteral("camera-photo"));
    if (trayIcon.isNull()) {
        QPixmap pixmap(32, 32);
        pixmap.fill(Qt::transparent);
        QPainter painter(&pixmap);
        painter.setRenderHint(QPainter::Antialiasing, true);
        painter.setBrush(QColor(QStringLiteral("#33A1FF")));
        painter.setPen(Qt::NoPen);
        painter.drawEllipse(QRectF(4, 4, 24, 24));
        painter.setBrush(QColor(QStringLiteral("#1A237E")));
        painter.drawEllipse(QRectF(10, 10, 12, 12));
        painter.end();
        trayIcon.addPixmap(pixmap);
    }

    m_trayIcon = std::make_unique<QSystemTrayIcon>(trayIcon, app);
    m_trayIcon->setToolTip(QStringLiteral("ProShottr"));
    menu->setParent(m_trayIcon.get());
    m_trayIcon->setContextMenu(menu);
    m_trayIcon->show();

    QObject::connect(captureWindowAction, &QAction::triggered, m_captureOrchestrator.get(), &CaptureOrchestrator::startWindowCapture);
    QObject::connect(captureRegionAction, &QAction::triggered, m_captureOrchestrator.get(), &CaptureOrchestrator::startRegionCapture);
    QObject::connect(preferencesAction, &QAction::triggered, this, &AppCoordinator::openPreferences);
    QObject::connect(quitAction, &QAction::triggered, this, &AppCoordinator::quit);
}

void AppCoordinator::connectHotkeys()
{
    if (!m_hotkeyService || !m_settings) {
        return;
    }

    auto registerForSequence = [this](const QString &identifier, const QString &sequence) {
        auto hotkey = WindowsHotkeyService::hotkeyFromSequence(sequence);
        if (!hotkey.isValid()) {
            return;
        }
        m_hotkeyService->registerHotkey(identifier, hotkey);
    };

    m_hotkeyService->reset();
    registerForSequence(QStringLiteral("capture.window"), m_settings->windowCaptureHotkey());
    registerForSequence(QStringLiteral("capture.region"), m_settings->regionCaptureHotkey());

    connect(m_settings.get(), &SettingsStore::windowCaptureHotkeyChanged, this, [this](const QString &sequence) {
        m_hotkeyService->unregisterHotkey(QStringLiteral("capture.window"));
        auto hotkey = WindowsHotkeyService::hotkeyFromSequence(sequence);
        if (hotkey.isValid()) {
            m_hotkeyService->registerHotkey(QStringLiteral("capture.window"), hotkey);
        }
    });

    connect(m_settings.get(), &SettingsStore::regionCaptureHotkeyChanged, this, [this](const QString &sequence) {
        m_hotkeyService->unregisterHotkey(QStringLiteral("capture.region"));
        auto hotkey = WindowsHotkeyService::hotkeyFromSequence(sequence);
        if (hotkey.isValid()) {
            m_hotkeyService->registerHotkey(QStringLiteral("capture.region"), hotkey);
        }
    });

    connect(m_hotkeyService.get(), &GlobalHotkeyService::captureWindowRequested, m_captureOrchestrator.get(), &CaptureOrchestrator::startWindowCapture);
    connect(m_hotkeyService.get(), &GlobalHotkeyService::captureRegionRequested, m_captureOrchestrator.get(), &CaptureOrchestrator::startRegionCapture);
    connect(m_hotkeyService.get(), &GlobalHotkeyService::openPreferencesRequested, this, &AppCoordinator::openPreferences);
}
