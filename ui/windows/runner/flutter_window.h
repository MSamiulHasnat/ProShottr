#ifndef RUNNER_FLUTTER_WINDOW_H_
#define RUNNER_FLUTTER_WINDOW_H_

#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include <memory>

#include "win32_window.h"

// A window that does nothing but host a Flutter view.
class FlutterWindow : public Win32Window {
 public:
  // Creates a new FlutterWindow hosting a Flutter view running |project|.
  explicit FlutterWindow(const flutter::DartProject& project);
  virtual ~FlutterWindow();

 protected:
  // Win32Window:
  bool OnCreate() override;
  void OnDestroy() override;
  LRESULT MessageHandler(HWND window, UINT const message, WPARAM const wparam,
                         LPARAM const lparam) noexcept override;

 private:
  static constexpr UINT kTrayMessage = WM_APP + 1;
  static constexpr UINT kShowEditorMessage = WM_APP + 2;
  static constexpr UINT kExitMessage = WM_APP + 3;
  static constexpr UINT kShowCommand = 1001;
  static constexpr UINT kExitCommand = 1002;

  void InstallTrayIcon();
  void RemoveTrayIcon();
  void ShowTrayMenu();
  void ShowEditorWindow();
  void HideEditorWindow();
  void ExitApplication();
  void PrepareCaptureWindow();
  void ShowCaptureOverlay();
  void RestoreEditorWindow();
  flutter::EncodableValue WindowAtPoint(LONG x, LONG y);

  // The project to run.
  flutter::DartProject project_;

  // The Flutter instance hosted by this window.
  std::unique_ptr<flutter::FlutterViewController> flutter_controller_;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
      capture_window_channel_;
  WINDOWPLACEMENT editor_placement_{sizeof(WINDOWPLACEMENT)};
  LONG_PTR editor_style_ = 0;
  LONG_PTR editor_extended_style_ = 0;
  bool editor_window_saved_ = false;
  bool editor_was_visible_ = true;
  bool tray_icon_installed_ = false;
  bool capture_overlay_active_ = false;
  bool exiting_ = false;
};

#endif  // RUNNER_FLUTTER_WINDOW_H_
