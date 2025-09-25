#include "WindowsHotkeyService.hpp"

#include <QGuiApplication>
#include <QKeySequence>
#include <QKeyCombination>

#ifdef Q_OS_WIN
#    include <windows.h>
#endif

namespace
{
#ifdef Q_OS_WIN
UINT modifiersToNative(Qt::KeyboardModifiers modifiers)
{
    UINT native = 0;
    if (modifiers.testFlag(Qt::ShiftModifier)) {
        native |= MOD_SHIFT;
    }
    if (modifiers.testFlag(Qt::ControlModifier)) {
        native |= MOD_CONTROL;
    }
    if (modifiers.testFlag(Qt::AltModifier)) {
        native |= MOD_ALT;
    }
    if (modifiers.testFlag(Qt::MetaModifier)) {
        native |= MOD_WIN;
    }
    native |= MOD_NOREPEAT;
    return native;
}

UINT keyToNative(int key)
{
    if (key >= Qt::Key_A && key <= Qt::Key_Z) {
        return static_cast<UINT>('A' + (key - Qt::Key_A));
    }
    if (key >= Qt::Key_0 && key <= Qt::Key_9) {
        return static_cast<UINT>('0' + (key - Qt::Key_0));
    }
    if (key >= Qt::Key_F1 && key <= Qt::Key_F24) {
        return static_cast<UINT>(VK_F1 + (key - Qt::Key_F1));
    }
    switch (key) {
    case Qt::Key_Tab:
        return VK_TAB;
    case Qt::Key_Space:
        return VK_SPACE;
    case Qt::Key_Return:
    case Qt::Key_Enter:
        return VK_RETURN;
    case Qt::Key_Escape:
        return VK_ESCAPE;
    case Qt::Key_Insert:
        return VK_INSERT;
    case Qt::Key_Delete:
        return VK_DELETE;
    case Qt::Key_Home:
        return VK_HOME;
    case Qt::Key_End:
        return VK_END;
    case Qt::Key_PageUp:
        return VK_PRIOR;
    case Qt::Key_PageDown:
        return VK_NEXT;
    case Qt::Key_Left:
        return VK_LEFT;
    case Qt::Key_Right:
        return VK_RIGHT;
    case Qt::Key_Up:
        return VK_UP;
    case Qt::Key_Down:
        return VK_DOWN;
    default:
    {
        SHORT vk = VkKeyScanW(static_cast<WCHAR>(key));
        if (vk == -1) {
            return 0;
        }
        return LOBYTE(vk);
    }
    }
}
#endif

} // namespace

WindowsHotkeyService::WindowsHotkeyService(QObject *parent)
    : GlobalHotkeyService(parent)
{
#ifdef Q_OS_WIN
    if (auto *app = QGuiApplication::instance()) {
        app->installNativeEventFilter(this);
    }
#endif
}

WindowsHotkeyService::~WindowsHotkeyService()
{
    unregisterAll();
#ifdef Q_OS_WIN
    if (auto *app = QGuiApplication::instance()) {
        app->removeNativeEventFilter(this);
    }
#endif
}

bool WindowsHotkeyService::registerHotkey(const QString &identifier, const Hotkey &hotkey)
{
#ifdef Q_OS_WIN
    if (!hotkey.isValid()) {
        return false;
    }

    const int id = m_nextId++;
    const UINT modifiers = modifiersToNative(hotkey.modifiers);
    const UINT key = keyToNative(hotkey.key);
    if (key == 0) {
        return false;
    }
    if (!RegisterHotKey(nullptr, id, modifiers, key)) {
        return false;
    }

    m_identifierToId.insert(identifier, id);
    m_idToIdentifier.insert(id, identifier);
    return true;
#else
    Q_UNUSED(identifier);
    Q_UNUSED(hotkey);
    return false;
#endif
}

void WindowsHotkeyService::unregisterHotkey(const QString &identifier)
{
#ifdef Q_OS_WIN
    const int id = m_identifierToId.take(identifier);
    if (id != 0) {
        UnregisterHotKey(nullptr, id);
        m_idToIdentifier.remove(id);
    }
#else
    Q_UNUSED(identifier);
#endif
}

void WindowsHotkeyService::reset()
{
    unregisterAll();
}

bool WindowsHotkeyService::nativeEventFilter(const QByteArray &eventType, void *message, qintptr *result)
{
#ifdef Q_OS_WIN
    if (eventType != "windows_generic_MSG" && eventType != "windows_dispatcher_MSG") {
        return false;
    }

    MSG *msg = static_cast<MSG *>(message);
    if (msg->message == WM_HOTKEY) {
        const int id = static_cast<int>(msg->wParam);
        const QString identifier = m_idToIdentifier.value(id);
        if (identifier == QStringLiteral("capture.window")) {
            emit captureWindowRequested();
        } else if (identifier == QStringLiteral("capture.region")) {
            emit captureRegionRequested();
        } else if (identifier == QStringLiteral("open.preferences")) {
            emit openPreferencesRequested();
        }
        if (result) {
            *result = 1;
        }
        return true;
    }
#else
    Q_UNUSED(eventType);
    Q_UNUSED(message);
    Q_UNUSED(result);
#endif
    return false;
}

WindowsHotkeyService::Hotkey WindowsHotkeyService::hotkeyFromSequence(const QString &sequence)
{
    Hotkey hotkey{};
    if (sequence.isEmpty()) {
        return hotkey;
    }

    QKeySequence seq(sequence);
    if (seq.isEmpty()) {
        return hotkey;
    }

#if QT_VERSION >= QT_VERSION_CHECK(6, 0, 0)
    const QKeyCombination combination = seq[0];
    hotkey.modifiers = combination.keyboardModifiers();
    hotkey.key = combination.key();
#else
    const int keyInt = seq[0];
    hotkey.modifiers = Qt::KeyboardModifiers(keyInt & Qt::KeyboardModifierMask);
    hotkey.key = keyInt & ~Qt::KeyboardModifierMask;
#endif
    return hotkey;
}

void WindowsHotkeyService::unregisterAll()
{
#ifdef Q_OS_WIN
    for (auto it = m_idToIdentifier.cbegin(); it != m_idToIdentifier.cend(); ++it) {
        UnregisterHotKey(nullptr, it.key());
    }
    m_idToIdentifier.clear();
    m_identifierToId.clear();
#else
    m_idToIdentifier.clear();
    m_identifierToId.clear();
#endif
}
