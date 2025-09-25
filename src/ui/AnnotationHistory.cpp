#include "AnnotationHistory.hpp"

AnnotationHistory::AnnotationHistory(QObject *parent)
    : QObject(parent)
{
}

QVariantList AnnotationHistory::commands() const
{
    return m_cachedCommands;
}

void AnnotationHistory::push(const QVariantMap &command)
{
    m_commands.append(command);
    m_redoStack.clear();
    updateCommands();
}

QVariantMap AnnotationHistory::undo()
{
    if (m_commands.isEmpty()) {
        return {};
    }
    const QVariantMap command = m_commands.takeLast();
    m_redoStack.append(command);
    updateCommands();
    return command;
}

QVariantMap AnnotationHistory::redo()
{
    if (m_redoStack.isEmpty()) {
        return {};
    }
    const QVariantMap command = m_redoStack.takeLast();
    m_commands.append(command);
    updateCommands();
    return command;
}

void AnnotationHistory::clear()
{
    m_commands.clear();
    m_redoStack.clear();
    updateCommands();
}

void AnnotationHistory::removeAt(int index)
{
    if (index < 0 || index >= m_commands.count()) {
        return;
    }
    m_commands.removeAt(index);
    updateCommands();
}

void AnnotationHistory::updateCommands()
{
    m_cachedCommands = QVariantList();
    for (const auto &command : m_commands) {
        m_cachedCommands.append(command);
    }
    emit commandsChanged();
}
