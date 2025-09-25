#include "AppBootstrap.hpp"

#include "AppCoordinator.hpp"

#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QUrl>
#include <QtQml>

AppBootstrap::AppBootstrap() = default;
AppBootstrap::~AppBootstrap() = default;

bool AppBootstrap::initialize(QGuiApplication *app)
{
    if (!registerQmlTypes()) {
        return false;
    }

    m_engine = std::make_unique<QQmlApplicationEngine>();
    m_coordinator = std::make_unique<AppCoordinator>();

    if (!m_coordinator->initialize(app, m_engine.get())) {
        return false;
    }

    return loadQml();
}

bool AppBootstrap::registerQmlTypes()
{
    qRegisterMetaType<QImage>("QImage");
    qRegisterMetaType<QRectF>("QRectF");
    qRegisterMetaType<QVector<QRectF>>("QVector<QRectF>");
    return true;
}

bool AppBootstrap::loadQml()
{
    const QUrl url(QStringLiteral("qrc:/Main.qml"));
    QObject::connect(
        m_engine.get(),
        &QQmlApplicationEngine::objectCreated,
        m_engine.get(),
        [url](QObject *obj, const QUrl &objUrl) {
            if (!obj && url == objUrl) {
                QCoreApplication::exit(EXIT_FAILURE);
            }
        },
        Qt::QueuedConnection);

    m_engine->load(url);
    return !m_engine->rootObjects().isEmpty();
}
