#ifndef RUNNER_IMAGE_PIN_WINDOW_H_
#define RUNNER_IMAGE_PIN_WINDOW_H_

#include <windows.h>

#include <cstdint>
#include <memory>
#include <string>
#include <vector>

// Independent native pins survive hiding the Flutter capture host. The runner
// owns the objects, and each object owns its window and decoded image pixels.
class ImagePinWindow {
 public:
  static std::unique_ptr<ImagePinWindow> Create(
      const std::vector<uint8_t>& png_bytes, std::string* error);
  ~ImagePinWindow();
  bool IsOpen() const { return window_ != nullptr; }

 private:
  ImagePinWindow() = default;
  bool DecodePng(const std::vector<uint8_t>& bytes, std::string* error);
  static LRESULT CALLBACK WindowProc(HWND window, UINT message, WPARAM wparam,
                                     LPARAM lparam);
  LRESULT HandleMessage(UINT message, WPARAM wparam, LPARAM lparam);
  void Paint();
  void Resize(double scale, POINT anchor);
  int HeaderHeight() const;
  int ButtonWidth() const;
  int ButtonAt(POINT point) const;

  HWND window_ = nullptr;
  UINT image_width_ = 0;
  UINT image_height_ = 0;
  UINT dpi_ = 96;
  double scale_ = 1;
  bool collapsed_ = false;
  int pressed_button_ = 0;
  std::vector<uint8_t> pixels_;
};

#endif  // RUNNER_IMAGE_PIN_WINDOW_H_
