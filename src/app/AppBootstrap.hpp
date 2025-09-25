#pragma once

#include <memory>

class QGuiApplication;
class QQmlApplicationEngine;

class AppCoordinator;

class AppBootstrap
{
public:
    AppBootstrap();
    ~AppBootstrap();

    bool initialize(QGuiApplication *app);

private:
    bool registerQmlTypes();
    bool initializeCoordinator(QGuiApplication *app);
    bool loadQml();

    std::unique_ptr<QQmlApplicationEngine> m_engine;
    std::unique_ptr<AppCoordinator> m_coordinator;
};
