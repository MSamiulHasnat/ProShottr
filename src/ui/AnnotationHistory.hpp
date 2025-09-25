#pragma once

#include <QObject>
#include <QVariantList>
#include <QVariantMap>
#include <QList>

class AnnotationHistory : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QVariantList commands READ commands NOTIFY commandsChanged)

public:
    explicit AnnotationHistory(QObject *parent = nullptr);

    QVariantList commands() const;

    Q_INVOKABLE void push(const QVariantMap &command);
    Q_INVOKABLE QVariantMap undo();
    Q_INVOKABLE QVariantMap redo();
    Q_INVOKABLE void clear();
    Q_INVOKABLE void removeAt(int index);

signals:
    void commandsChanged();

private:
    void updateCommands();

    QList<QVariantMap> m_commands;
    QList<QVariantMap> m_redoStack;
    QVariantList m_cachedCommands;
};
