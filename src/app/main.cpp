#include "AppBootstrap.hpp"

#include <QApplication>
#include <QQuickStyle>

int main(int argc, char *argv[])
{
    QQuickStyle::setStyle("Material");

    QApplication app(argc, argv);
    QApplication::setApplicationDisplayName(QStringLiteral("ProShottr"));
    QApplication::setOrganizationName(QStringLiteral("ProShottr"));
    QApplication::setOrganizationDomain(QStringLiteral("app.proshottr"));

    AppBootstrap bootstrap;
    if (!bootstrap.initialize(&app)) {
        return EXIT_FAILURE;
    }

    return app.exec();
}
