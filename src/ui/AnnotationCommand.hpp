#pragma once

#include <QObject>
#include <QVariantMap>

class AnnotationEnums
{
    Q_GADGET
public:
    enum ToolType {
        Arrow,
        Rectangle,
        Ellipse,
        Text,
        Pencil,
        Eraser
    };
    Q_ENUM(ToolType)
};

inline QVariantMap createAnnotationCommand(AnnotationEnums::ToolType tool, const QVariantMap &payload)
{
    QVariantMap map = payload;
    map.insert(QStringLiteral("tool"), QVariant::fromValue(static_cast<int>(tool)));
    return map;
}
