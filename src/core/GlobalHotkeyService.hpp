#pragma once

#include <QObject>
#include <QString>

class GlobalHotkeyService : public QObject
{
    Q_OBJECT
public:
    struct Hotkey
    {
        Qt::KeyboardModifiers modifiers;
        int key;

        bool isValid() const
        {
            return key != 0;
        }
    };

    explicit GlobalHotkeyService(QObject *parent = nullptr)
        : QObject(parent)
    {
    }

    ~GlobalHotkeyService() override = default;

    virtual bool registerHotkey(const QString &identifier, const Hotkey &hotkey) = 0;
    virtual void unregisterHotkey(const QString &identifier) = 0;
    virtual void reset() = 0;

signals:
    void captureWindowRequested();
    void captureRegionRequested();
    void openPreferencesRequested();
};
