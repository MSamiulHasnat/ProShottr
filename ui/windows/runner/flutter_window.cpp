#include "flutter_window.h"

#include <optional>
#include <string>

#include <windows.h>

#include "flutter/generated_plugin_registrant.h"
#include "resource.h"

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  capture_window_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(),
          "proshottr/windows_capture_window",
          &flutter::StandardMethodCodec::GetInstance());
  capture_window_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
                 result) {
        if (call.method_name() == "prepareCapture") {
          PrepareCaptureWindow();
          result->Success();
        } else if (call.method_name() == "showCaptureOverlay") {
          ShowCaptureOverlay();
          result->Success();
        } else if (call.method_name() == "restoreEditor") {
          RestoreEditorWindow();
          result->Success();
        } else if (call.method_name() == "showEditor") {
          ShowEditorWindow();
          result->Success();
        } else if (call.method_name() == "windowAtPoint") {
          const auto* arguments = std::get_if<flutter::EncodableMap>(call.arguments());
          if (!arguments) {
            result->Error("invalid_arguments", "windowAtPoint expects x and y");
            return;
          }
          const auto read_coordinate = [&](const char* key) -> std::optional<LONG> {
            const auto value = arguments->find(flutter::EncodableValue(key));
            if (value == arguments->end()) return std::nullopt;
            if (const auto* integer = std::get_if<int32_t>(&value->second)) {
              return static_cast<LONG>(*integer);
            }
            if (const auto* integer = std::get_if<int64_t>(&value->second)) {
              return static_cast<LONG>(*integer);
            }
            return std::nullopt;
          };
          const auto x = read_coordinate("x");
          const auto y = read_coordinate("y");
          if (!x || !y) {
            result->Error("invalid_arguments", "windowAtPoint requires x and y");
            return;
          }
          result->Success(WindowAtPoint(*x, *y));
        } else {
          result->NotImplemented();
        }
      });

  RegisterHotKey(GetHandle(), 1, MOD_ALT | MOD_SHIFT | MOD_NOREPEAT, 'S');
  InstallTrayIcon();

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    if (editor_was_visible_) {
      this->ShowEditorWindow();
    }
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  UnregisterHotKey(GetHandle(), 1);
  RemoveTrayIcon();
  capture_window_channel_.reset();
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  if (capture_overlay_active_ &&
      (message == WM_KEYDOWN || message == WM_SYSKEYDOWN) &&
      wparam == VK_ESCAPE) {
    capture_overlay_active_ = false;
    if (capture_window_channel_) {
      capture_window_channel_->InvokeMethod(
          "captureCancelled",
          std::make_unique<flutter::EncodableValue>());
    }
    return 0;
  }

  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case kTrayMessage:
      if (lparam == WM_LBUTTONDBLCLK) {
        ShowEditorWindow();
      } else if (lparam == WM_RBUTTONUP) {
        ShowTrayMenu();
      }
      return 0;
    case kShowEditorMessage:
      ShowEditorWindow();
      return 0;
    case kExitMessage:
      ExitApplication();
      return 0;
    case WM_CLOSE:
      if (!exiting_) {
        HideEditorWindow();
        return 0;
      }
      break;
    case WM_HOTKEY:
      if (wparam == 1 && capture_window_channel_) {
        capture_window_channel_->InvokeMethod(
            "captureRequested",
            std::make_unique<flutter::EncodableValue>());
      }
      return 0;
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}

void FlutterWindow::InstallTrayIcon() {
  if (tray_icon_installed_ || !GetHandle()) return;

  NOTIFYICONDATAW tray{};
  tray.cbSize = sizeof(tray);
  tray.hWnd = GetHandle();
  tray.uID = 1;
  tray.uFlags = NIF_MESSAGE | NIF_ICON | NIF_TIP;
  tray.uCallbackMessage = kTrayMessage;
  tray.hIcon = LoadIcon(GetModuleHandle(nullptr), MAKEINTRESOURCE(IDI_APP_ICON));
  wcscpy_s(tray.szTip, L"ProShottr — Alt+Shift+S to capture");
  tray_icon_installed_ = Shell_NotifyIconW(NIM_ADD, &tray) == TRUE;
}

void FlutterWindow::RemoveTrayIcon() {
  if (!tray_icon_installed_ || !GetHandle()) return;

  NOTIFYICONDATAW tray{};
  tray.cbSize = sizeof(tray);
  tray.hWnd = GetHandle();
  tray.uID = 1;
  Shell_NotifyIconW(NIM_DELETE, &tray);
  tray_icon_installed_ = false;
}

void FlutterWindow::ShowTrayMenu() {
  HMENU menu = CreatePopupMenu();
  if (!menu) return;

  AppendMenuW(menu, MF_STRING, kShowCommand, L"Show ProShottr");
  AppendMenuW(menu, MF_SEPARATOR, 0, nullptr);
  AppendMenuW(menu, MF_STRING, kExitCommand, L"Exit ProShottr");

  POINT cursor{};
  GetCursorPos(&cursor);
  SetForegroundWindow(GetHandle());
  const UINT command = TrackPopupMenu(
      menu, TPM_RETURNCMD | TPM_NONOTIFY | TPM_RIGHTBUTTON, cursor.x,
      cursor.y, 0, GetHandle(), nullptr);
  DestroyMenu(menu);
  PostMessage(GetHandle(), WM_NULL, 0, 0);

  if (command == kShowCommand) {
    ShowEditorWindow();
  } else if (command == kExitCommand) {
    ExitApplication();
  }
}

void FlutterWindow::ShowEditorWindow() {
  const HWND hwnd = GetHandle();
  if (!hwnd) return;
  ShowWindow(hwnd, SW_SHOWNORMAL);
  SetForegroundWindow(hwnd);
  SetFocus(hwnd);
}

void FlutterWindow::HideEditorWindow() {
  const HWND hwnd = GetHandle();
  if (hwnd) ShowWindow(hwnd, SW_HIDE);
}

void FlutterWindow::ExitApplication() {
  exiting_ = true;
  const HWND hwnd = GetHandle();
  if (hwnd) DestroyWindow(hwnd);
}

flutter::EncodableValue FlutterWindow::WindowAtPoint(LONG x, LONG y) {
  struct SearchContext {
    HWND excluded_window;
    POINT point;
    RECT bounds;
    std::wstring title;
    bool found = false;
  } context{GetHandle(), POINT{x, y}, RECT{}, L"", false};

  EnumWindows(
      [](HWND window, LPARAM raw_context) -> BOOL {
        auto* context = reinterpret_cast<SearchContext*>(raw_context);
        DWORD process_id = 0;
        GetWindowThreadProcessId(window, &process_id);
        if (window == context->excluded_window ||
            process_id == GetCurrentProcessId() ||
            !IsWindowVisible(window) || IsIconic(window)) {
          return TRUE;
        }

        RECT bounds{};
        if (!GetWindowRect(window, &bounds) ||
            !PtInRect(&bounds, context->point) ||
            bounds.right <= bounds.left || bounds.bottom <= bounds.top) {
          return TRUE;
        }

        const int title_length = GetWindowTextLengthW(window);
        std::wstring title(static_cast<size_t>(title_length) + 1, L'\0');
        if (title_length > 0) {
          GetWindowTextW(window, title.data(), title_length + 1);
        }
        title.resize(wcslen(title.c_str()));
        context->bounds = bounds;
        context->title = std::move(title);
        context->found = true;
        return FALSE;
      },
      reinterpret_cast<LPARAM>(&context));

  if (!context.found) return flutter::EncodableValue();

  flutter::EncodableMap bounds;
  bounds[flutter::EncodableValue("left")] =
      flutter::EncodableValue(static_cast<int32_t>(context.bounds.left));
  bounds[flutter::EncodableValue("top")] =
      flutter::EncodableValue(static_cast<int32_t>(context.bounds.top));
  bounds[flutter::EncodableValue("right")] =
      flutter::EncodableValue(static_cast<int32_t>(context.bounds.right));
  bounds[flutter::EncodableValue("bottom")] =
      flutter::EncodableValue(static_cast<int32_t>(context.bounds.bottom));
  return flutter::EncodableValue(bounds);
}

void FlutterWindow::PrepareCaptureWindow() {
  const HWND hwnd = GetHandle();
  if (!hwnd) {
    return;
  }

  editor_style_ = GetWindowLongPtr(hwnd, GWL_STYLE);
  editor_extended_style_ = GetWindowLongPtr(hwnd, GWL_EXSTYLE);
  editor_was_visible_ = IsWindowVisible(hwnd) != FALSE;
  editor_placement_.length = sizeof(WINDOWPLACEMENT);
  editor_window_saved_ = GetWindowPlacement(hwnd, &editor_placement_) != FALSE;
  ShowWindow(hwnd, SW_HIDE);
}

void FlutterWindow::ShowCaptureOverlay() {
  const HWND hwnd = GetHandle();
  if (!hwnd) {
    return;
  }

  const int left = GetSystemMetrics(SM_XVIRTUALSCREEN);
  const int top = GetSystemMetrics(SM_YVIRTUALSCREEN);
  const int width = GetSystemMetrics(SM_CXVIRTUALSCREEN);
  const int height = GetSystemMetrics(SM_CYVIRTUALSCREEN);

  SetWindowLongPtr(hwnd, GWL_STYLE, WS_POPUP | WS_VISIBLE);
  SetWindowLongPtr(hwnd, GWL_EXSTYLE, WS_EX_APPWINDOW);
  SetWindowPos(hwnd, HWND_TOPMOST, left, top, width, height,
               SWP_FRAMECHANGED | SWP_SHOWWINDOW);
  capture_overlay_active_ = true;
  ShowWindow(hwnd, SW_SHOW);
  SetForegroundWindow(hwnd);
  SetFocus(hwnd);
}

void FlutterWindow::RestoreEditorWindow() {
  const HWND hwnd = GetHandle();
  if (!hwnd || !editor_window_saved_) {
    return;
  }

  capture_overlay_active_ = false;

  SetWindowLongPtr(hwnd, GWL_STYLE, editor_style_);
  SetWindowLongPtr(hwnd, GWL_EXSTYLE, editor_extended_style_);
  SetWindowPlacement(hwnd, &editor_placement_);
  SetWindowPos(hwnd, HWND_NOTOPMOST, 0, 0, 0, 0,
               SWP_FRAMECHANGED | SWP_NOMOVE | SWP_NOSIZE);
  if (editor_was_visible_) {
    ShowEditorWindow();
  } else {
    HideEditorWindow();
  }
  editor_window_saved_ = false;
}
