#include "flutter_window.h"

#include <algorithm>
#include <cwchar>
#include <iterator>
#include <limits>
#include <optional>
#include <string>

#include <windows.h>
#include <dwmapi.h>
#include <shlobj.h>
#include <shobjidl.h>
#include <wrl/client.h>

#include <flutter/method_result_functions.h>

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
        } else if (call.method_name() == "pinImage" ||
                   call.method_name() == "savePngAs") {
          const auto* arguments = call.arguments()
              ? std::get_if<flutter::EncodableMap>(call.arguments()) : nullptr;
          const std::vector<uint8_t>* bytes = nullptr;
          if (arguments) {
            const auto value = arguments->find(flutter::EncodableValue("pngBytes"));
            if (value != arguments->end()) {
              bytes = std::get_if<std::vector<uint8_t>>(&value->second);
            }
          }
          constexpr uint8_t signature[] = {137, 80, 78, 71, 13, 10, 26, 10};
          if (!bytes || bytes->size() < sizeof(signature) ||
              !std::equal(std::begin(signature), std::end(signature),
                          bytes->begin())) {
            result->Error("invalid_arguments", "A PNG image in pngBytes is required.");
            return;
          }
          if (call.method_name() == "savePngAs") {
            SavePngAs(*bytes, result.get());
            return;
          }
          image_pins_.erase(
              std::remove_if(image_pins_.begin(), image_pins_.end(),
                             [](const auto& pin) { return !pin->IsOpen(); }),
              image_pins_.end());
          std::string error;
          auto pin = ImagePinWindow::Create(*bytes, &error);
          if (!pin) {
            result->Error("pin_failed", error);
            return;
          }
          image_pins_.push_back(std::move(pin));
          result->Success();
        } else if (call.method_name() == "windowAtPoint") {
          const auto* arguments = call.arguments()
              ? std::get_if<flutter::EncodableMap>(call.arguments()) : nullptr;
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
              if (*integer < std::numeric_limits<LONG>::min() ||
                  *integer > std::numeric_limits<LONG>::max()) return std::nullopt;
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
    if (editor_was_visible_ && !editor_window_saved_ && !exiting_) {
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
  image_pins_.clear();
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
      wparam == VK_ESCAPE && !save_dialog_active_) {
    RequestCaptureCancellation();
    return 0;
  }
  if (message == WM_ACTIVATEAPP && !wparam && capture_overlay_active_ &&
      !save_dialog_active_ && !exiting_) {
    // A user switching apps cancels selection. Owned Save As dialogs run in
    // this process and are additionally protected by save_dialog_active_.
    // Preserve the app the user just switched to instead of activating the
    // original capture target again on this particular exit path.
    previous_foreground_window_ = nullptr;
    previous_foreground_process_ = 0;
    RequestCaptureCancellation();
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
        if (editor_window_saved_) {
          if (save_dialog_active_) return 0;
          RequestCaptureCancellation();
          return 0;
        }
        HideEditorWindow();
        return 0;
      }
      break;
    case WM_HOTKEY:
      if (wparam == 1 && capture_window_channel_ &&
          !editor_window_saved_ && !capture_request_pending_ &&
          !save_dialog_active_ && !exiting_) {
        // Record synchronously at the hotkey, before Dart starts capture or
        // hiding our current window lets Windows activate a different app.
        RememberForegroundWindow();
        capture_request_pending_ = true;
        const auto finish_request = [this]() {
          capture_request_pending_ = false;
          // Dart can reject a hotkey while an export is busy. Do not keep that
          // rejected request's foreground HWND for a later button capture.
          if (!editor_window_saved_) {
            previous_foreground_window_ = nullptr;
            previous_foreground_process_ = 0;
          }
        };
        capture_window_channel_->InvokeMethod(
            "captureRequested",
            std::make_unique<flutter::EncodableValue>(),
            std::make_unique<flutter::MethodResultFunctions<>>(
                [finish_request](const auto*) { finish_request(); },
                [finish_request](const auto&, const auto&, const auto*) {
                  finish_request();
                },
                finish_request));
      }
      return 0;
    case WM_DPICHANGED:
      if (capture_overlay_active_) {
        // Flutter still receives the DPI message above, but the frozen desktop
        // surface must keep physical virtual-desktop bounds, not a monitor's
        // scaled suggested editor rectangle.
        SetWindowPos(hwnd, HWND_TOPMOST, GetSystemMetrics(SM_XVIRTUALSCREEN),
                       GetSystemMetrics(SM_YVIRTUALSCREEN),
                       GetSystemMetrics(SM_CXVIRTUALSCREEN),
                       GetSystemMetrics(SM_CYVIRTUALSCREEN), SWP_NOACTIVATE);
        return 0;
      }
      break;
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
  if (!hwnd || save_dialog_active_) return;
  if (editor_window_saved_) {
    RequestCaptureCancellation(true);
    return;
  }
  ShowWindow(hwnd, static_cast<int>(editor_show_command_));
  SetForegroundWindow(hwnd);
  if (flutter_controller_) {
    SetFocus(flutter_controller_->view()->GetNativeWindow());
  }
}

void FlutterWindow::HideEditorWindow() {
  const HWND hwnd = GetHandle();
  if (hwnd) ShowWindow(hwnd, SW_HIDE);
}

void FlutterWindow::ExitApplication() {
  exiting_ = true;
  if (active_save_dialog_) {
    // Let the modal method call return its result before tearing down the
    // Flutter messenger that owns it.
    active_save_dialog_->Close(HRESULT_FROM_WIN32(ERROR_CANCELLED));
    return;
  }
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

        DWORD cloaked = 0;
        if (SUCCEEDED(DwmGetWindowAttribute(window, DWMWA_CLOAKED, &cloaked,
                                            sizeof(cloaked))) && cloaked != 0) {
          return TRUE;
        }
        RECT bounds{};
        // DWM reports visible pixels; GetWindowRect also includes invisible
        // resize borders, which otherwise produce a shifted window selection.
        if (FAILED(DwmGetWindowAttribute(window, DWMWA_EXTENDED_FRAME_BOUNDS,
                                          &bounds, sizeof(bounds))) &&
            !GetWindowRect(window, &bounds)) {
          return TRUE;
        }
        if (!PtInRect(&bounds, context->point) ||
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
  if (!hwnd || editor_window_saved_ || save_dialog_active_) {
    return;
  }

  editor_style_ = GetWindowLongPtr(hwnd, GWL_STYLE);
  editor_extended_style_ = GetWindowLongPtr(hwnd, GWL_EXSTYLE);
  if (!previous_foreground_window_) RememberForegroundWindow();
  editor_was_visible_ = IsWindowVisible(hwnd) != FALSE;
  editor_placement_.length = sizeof(WINDOWPLACEMENT);
  editor_placement_saved_ = GetWindowPlacement(hwnd, &editor_placement_) != FALSE;
  if (editor_placement_saved_) {
    editor_show_command_ = editor_placement_.showCmd == SW_SHOWMAXIMIZED
                               ? SW_SHOWMAXIMIZED : SW_SHOWNORMAL;
  }
  editor_window_saved_ = true;
  ShowWindow(hwnd, SW_HIDE);
}

void FlutterWindow::ShowCaptureOverlay() {
  const HWND hwnd = GetHandle();
  if (!hwnd || !editor_window_saved_ || save_dialog_active_) {
    return;
  }

  const int left = GetSystemMetrics(SM_XVIRTUALSCREEN);
  const int top = GetSystemMetrics(SM_YVIRTUALSCREEN);
  const int width = GetSystemMetrics(SM_CXVIRTUALSCREEN);
  const int height = GetSystemMetrics(SM_CYVIRTUALSCREEN);

  // Hide before changing shell visibility flags. TOOLWINDOW suppresses both
  // the taskbar button and Alt-Tab entry; APPWINDOW would force an entry.
  SetWindowLongPtr(hwnd, GWL_STYLE, WS_POPUP);
  SetWindowLongPtr(hwnd, GWL_EXSTYLE, WS_EX_TOOLWINDOW | WS_EX_TOPMOST);
  capture_overlay_active_ = true;
  SetWindowPos(hwnd, HWND_TOPMOST, left, top, width, height,
               SWP_FRAMECHANGED | SWP_SHOWWINDOW);
  ShowWindow(hwnd, SW_SHOW);
  SetForegroundWindow(hwnd);
  if (flutter_controller_) {
    SetFocus(flutter_controller_->view()->GetNativeWindow());
  }
}

void FlutterWindow::RestoreEditorWindow() {
  const HWND hwnd = GetHandle();
  if (!hwnd || !editor_window_saved_ || save_dialog_active_) {
    return;
  }

  capture_overlay_active_ = false;
  // Restore the typing target while we still own foreground permission. Never
  // force an app which has closed or changed process since the capture began.
  DWORD process = 0;
  if (previous_foreground_window_) {
    GetWindowThreadProcessId(previous_foreground_window_, &process);
  }
  if (previous_foreground_window_ && previous_foreground_window_ != hwnd &&
      process == previous_foreground_process_ &&
      IsWindowVisible(previous_foreground_window_) &&
      !IsIconic(previous_foreground_window_)) {
    SetForegroundWindow(previous_foreground_window_);
  }
  previous_foreground_window_ = nullptr;
  previous_foreground_process_ = 0;
  // Both the style and WINDOWPLACEMENT carry visibility. Clearing only one
  // causes a brief editor/taskbar flash as the overlay is torn down.
  ShowWindow(hwnd, SW_HIDE);
  SetWindowLongPtr(hwnd, GWL_STYLE, editor_style_ & ~WS_VISIBLE);
  SetWindowLongPtr(hwnd, GWL_EXSTYLE, editor_extended_style_);
  if (editor_placement_saved_) {
    WINDOWPLACEMENT hidden_placement = editor_placement_;
    hidden_placement.showCmd = SW_HIDE;
    SetWindowPlacement(hwnd, &hidden_placement);
  }
  SetWindowPos(hwnd, HWND_NOTOPMOST, 0, 0, 0, 0,
               SWP_FRAMECHANGED | SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE);
  editor_window_saved_ = false;
  editor_placement_saved_ = false;
  editor_was_visible_ = false;
}

void FlutterWindow::RememberForegroundWindow() {
  previous_foreground_window_ = GetForegroundWindow();
  previous_foreground_process_ = 0;
  if (previous_foreground_window_) {
    GetWindowThreadProcessId(previous_foreground_window_,
                            &previous_foreground_process_);
  }
}

void FlutterWindow::RequestCaptureCancellation(bool show_editor_after) {
  if (!capture_window_channel_) return;
  // Dart owns busy copy/pin operations and can decline cancellation. Hiding
  // first would strand a still-active Quick session in an invisible window.
  capture_window_channel_->InvokeMethod(
      "captureCancelled", std::make_unique<flutter::EncodableValue>(),
      std::make_unique<flutter::MethodResultFunctions<>>(
          [this, show_editor_after](const auto*) {
            if (!show_editor_after || editor_window_saved_ || exiting_ ||
                !flutter_controller_) return;
            flutter_controller_->engine()->SetNextFrameCallback([this]() {
              if (!editor_window_saved_ && !exiting_) ShowEditorWindow();
            });
            flutter_controller_->ForceRedraw();
          },
          nullptr, nullptr));
}

void FlutterWindow::SavePngAs(
    const std::vector<uint8_t>& bytes,
    flutter::MethodResult<flutter::EncodableValue>* result) {
  if (save_dialog_active_ || exiting_) {
    result->Error("save_busy", "A Save As dialog is already open.");
    return;
  }
  Microsoft::WRL::ComPtr<IFileSaveDialog> dialog;
  HRESULT status = CoCreateInstance(CLSID_FileSaveDialog, nullptr,
                                     CLSCTX_INPROC_SERVER, IID_PPV_ARGS(&dialog));
  if (FAILED(status)) {
    result->Error("save_failed", "Windows could not open the Save As dialog.");
    return;
  }
  SYSTEMTIME now{};
  GetLocalTime(&now);
  wchar_t filename[96]{};
  swprintf_s(filename, L"ProShottr-%04u%02u%02u-%02u%02u%02u.png",
              static_cast<unsigned>(now.wYear),
              static_cast<unsigned>(now.wMonth),
              static_cast<unsigned>(now.wDay),
              static_cast<unsigned>(now.wHour),
              static_cast<unsigned>(now.wMinute),
              static_cast<unsigned>(now.wSecond));
  const COMDLG_FILTERSPEC types[] = {{L"PNG image", L"*.png"}};
  FILEOPENDIALOGOPTIONS options{};
  dialog->GetOptions(&options);
  dialog->SetOptions(options | FOS_FORCEFILESYSTEM | FOS_OVERWRITEPROMPT |
                       FOS_PATHMUSTEXIST | FOS_NOCHANGEDIR);
  dialog->SetFileTypes(1, types);
  dialog->SetDefaultExtension(L"png");
  dialog->SetFileName(filename);
  dialog->SetTitle(L"Save ProShottr capture");
  Microsoft::WRL::ComPtr<IShellItem> desktop;
  if (SUCCEEDED(SHGetKnownFolderItem(FOLDERID_Desktop, KF_FLAG_DEFAULT, nullptr,
                                      IID_PPV_ARGS(&desktop)))) {
    dialog->SetDefaultFolder(desktop.Get());
  }
  // Show() runs an owned modal loop on the Flutter platform thread. Retaining
  // the overlay keeps the selection and annotations available after cancel.
  save_dialog_active_ = true;
  active_save_dialog_ = dialog.Get();
  status = dialog->Show(GetHandle());
  active_save_dialog_ = nullptr;
  save_dialog_active_ = false;
  if (exiting_) {
    result->Success(flutter::EncodableValue());
    PostMessage(GetHandle(), kExitMessage, 0, 0);
    return;
  }
  if (status == HRESULT_FROM_WIN32(ERROR_CANCELLED)) {
    result->Success(flutter::EncodableValue());
    return;
  }
  Microsoft::WRL::ComPtr<IShellItem> file;
  PWSTR raw_path = nullptr;
  if (FAILED(status) || FAILED(dialog->GetResult(&file)) ||
      FAILED(file->GetDisplayName(SIGDN_FILESYSPATH, &raw_path))) {
    result->Error("save_failed", "Windows did not return a save location.");
    return;
  }
  const std::wstring path(raw_path);
  CoTaskMemFree(raw_path);
  HANDLE output = CreateFileW(path.c_str(), GENERIC_WRITE, 0, nullptr,
                               CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, nullptr);
  if (output == INVALID_HANDLE_VALUE) {
    result->Error("save_failed", "The selected file could not be written.");
    return;
  }
  size_t offset = 0;
  bool success = true;
  while (offset < bytes.size()) {
    DWORD written = 0;
    const DWORD count = static_cast<DWORD>(std::min<size_t>(
        bytes.size() - offset, std::numeric_limits<DWORD>::max()));
    if (!WriteFile(output, bytes.data() + offset, count, &written, nullptr) ||
        written == 0) {
      success = false;
      break;
    }
    offset += written;
  }
  if (!CloseHandle(output)) success = false;
  if (!success) {
    result->Error("save_failed", "The image could not be fully written to disk.");
    return;
  }
  const int length = WideCharToMultiByte(CP_UTF8, 0, path.data(),
                                         static_cast<int>(path.size()), nullptr,
                                         0, nullptr, nullptr);
  std::string utf8_path(static_cast<size_t>(length), '\0');
  WideCharToMultiByte(CP_UTF8, 0, path.data(), static_cast<int>(path.size()),
                      utf8_path.data(), length, nullptr, nullptr);
  result->Success(flutter::EncodableValue(utf8_path));
}
