#pragma once

#include "../../core/GlobalHotkeyService.hpp"

#include <QAbstractNativeEventFilter>
#include <QHash>

class WindowsHotkeyService : public GlobalHotkeyService, public QAbstractNativeEventFilter
{
    Q_OBJECT
public:
    explicit WindowsHotkeyService(QObject *parent = nullptr);
    ~WindowsHotkeyService() override;

    bool registerHotkey(const QString &identifier, const Hotkey &hotkey) override;
    void unregisterHotkey(const QString &identifier) override;
    void reset() override;

    bool nativeEventFilter(const QByteArray &eventType, void *message, qintptr *result) override;

    static Hotkey hotkeyFromSequence(const QString &sequence);

private:
    UINT toNativeModifiers(Qt::KeyboardModifiers modifiers) const;
    UINT toNativeKey(int key) const;
    void unregisterAll();

    QHash<QString, int> m_identifierToId;
    QHash<int, QString> m_idToIdentifier;
    int m_nextId = 1;
};
