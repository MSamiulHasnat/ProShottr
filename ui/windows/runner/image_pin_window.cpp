#include "image_pin_window.h"

#include <windowsx.h>
#include <wincodec.h>
#include <wrl/client.h>

#include <algorithm>
#include <cmath>
#include <limits>

namespace {
constexpr wchar_t kPinWindowClass[] = L"ProShottrImagePin";
constexpr size_t kMaxDecodedBytes = 256 * 1024 * 1024;
using Microsoft::WRL::ComPtr;
}  // namespace

std::unique_ptr<ImagePinWindow> ImagePinWindow::Create(
    const std::vector<uint8_t>& png_bytes, std::string* error) {
  auto pin = std::unique_ptr<ImagePinWindow>(new ImagePinWindow());
  if (!pin->DecodePng(png_bytes, error)) return nullptr;

  WNDCLASSEXW window_class{};
  window_class.cbSize = sizeof(window_class);
  window_class.hInstance = GetModuleHandle(nullptr);
  window_class.lpszClassName = kPinWindowClass;
  window_class.lpfnWndProc = WindowProc;
  window_class.hCursor = LoadCursor(nullptr, IDC_ARROW);
  window_class.style = CS_DBLCLKS;
  if (!RegisterClassExW(&window_class) &&
      GetLastError() != ERROR_CLASS_ALREADY_EXISTS) {
    *error = "The pin window class could not be registered.";
    return nullptr;
  }

  POINT cursor{};
  GetCursorPos(&cursor);
  MONITORINFO monitor{sizeof(MONITORINFO)};
  GetMonitorInfo(MonitorFromPoint(cursor, MONITOR_DEFAULTTONEAREST), &monitor);
  const int available_width = monitor.rcWork.right - monitor.rcWork.left;
  const int available_height = monitor.rcWork.bottom - monitor.rcWork.top;
  pin->scale_ = std::min(
      {1.0, available_width * .65 / pin->image_width_,
       available_height * .65 / pin->image_height_});
  const int width = std::max(160, static_cast<int>(
                                      pin->image_width_ * pin->scale_) + 2);
  const int height = static_cast<int>(pin->image_height_ * pin->scale_) +
                     pin->HeaderHeight() + 2;
  const int left = std::max(monitor.rcWork.left,
                           std::min(cursor.x, monitor.rcWork.right - width));
  const int top = std::max(monitor.rcWork.top,
                          std::min(cursor.y, monitor.rcWork.bottom - height));
  // Deliberately unowned at the Win32 level: hiding the capture HWND must not
  // hide its pins. FlutterWindow's collection provides lifetime ownership.
  pin->window_ = CreateWindowExW(
      WS_EX_TOOLWINDOW | WS_EX_TOPMOST, kPinWindowClass,
      L"ProShottr pinned capture", WS_POPUP, left, top, width, height, nullptr,
      nullptr, GetModuleHandle(nullptr), pin.get());
  if (!pin->window_) {
    *error = "The pinned image window could not be created.";
    return nullptr;
  }
  pin->dpi_ = GetDpiForWindow(pin->window_);
  pin->Resize(pin->scale_, POINT{left, top});
  ShowWindow(pin->window_, SW_SHOWNOACTIVATE);
  UpdateWindow(pin->window_);
  return pin;
}

ImagePinWindow::~ImagePinWindow() {
  if (window_) DestroyWindow(window_);
}

bool ImagePinWindow::DecodePng(const std::vector<uint8_t>& bytes,
                               std::string* error) {
  if (bytes.empty() || bytes.size() > std::numeric_limits<DWORD>::max()) {
    *error = "The PNG image is empty or too large.";
    return false;
  }
  ComPtr<IWICImagingFactory> factory;
  ComPtr<IWICStream> stream;
  ComPtr<IWICBitmapDecoder> decoder;
  ComPtr<IWICBitmapFrameDecode> frame;
  ComPtr<IWICFormatConverter> converter;
  GUID format{};
  if (FAILED(CoCreateInstance(CLSID_WICImagingFactory, nullptr,
                              CLSCTX_INPROC_SERVER, IID_PPV_ARGS(&factory))) ||
      FAILED(factory->CreateStream(&stream)) ||
      FAILED(stream->InitializeFromMemory(const_cast<BYTE*>(bytes.data()),
                                           static_cast<DWORD>(bytes.size()))) ||
      FAILED(factory->CreateDecoderFromStream(
          stream.Get(), nullptr, WICDecodeMetadataCacheOnLoad, &decoder)) ||
      FAILED(decoder->GetContainerFormat(&format)) ||
      format != GUID_ContainerFormatPng ||
      FAILED(decoder->GetFrame(0, &frame)) ||
      FAILED(frame->GetSize(&image_width_, &image_height_)) ||
      image_width_ == 0 || image_height_ == 0 ||
      static_cast<uint64_t>(image_width_) * image_height_ * 4 >
          kMaxDecodedBytes) {
    *error = "The PNG could not be decoded, or exceeds the 64-megapixel pin limit.";
    return false;
  }
  const UINT stride = image_width_ * 4;
  const UINT size = stride * image_height_;
  pixels_.resize(size);
  if (FAILED(factory->CreateFormatConverter(&converter)) ||
      FAILED(converter->Initialize(
          frame.Get(), GUID_WICPixelFormat32bppBGRA, WICBitmapDitherTypeNone,
          nullptr, 0, WICBitmapPaletteTypeCustom)) ||
      FAILED(converter->CopyPixels(nullptr, stride, size, pixels_.data()))) {
    *error = "The PNG pixels could not be read.";
    return false;
  }
  // GDI's StretchDIBits does not blend alpha. Composite transparency against
  // white once so transparent PNGs do not display black fringes.
  for (size_t index = 0; index < pixels_.size(); index += 4) {
    const unsigned alpha = pixels_[index + 3];
    for (size_t channel = 0; channel < 3; ++channel) {
      pixels_[index + channel] = static_cast<uint8_t>(
          (pixels_[index + channel] * alpha + 255 * (255 - alpha) + 127) / 255);
    }
    pixels_[index + 3] = 255;
  }
  return true;
}

int ImagePinWindow::HeaderHeight() const {
  return MulDiv(30, static_cast<int>(dpi_), 96);
}

int ImagePinWindow::ButtonWidth() const { return HeaderHeight(); }

int ImagePinWindow::ButtonAt(POINT point) const {
  RECT client{};
  GetClientRect(window_, &client);
  if (point.y < 0 || point.y >= HeaderHeight() || point.x >= client.right) {
    return 0;
  }
  if (point.x >= client.right - ButtonWidth()) return 2;
  if (point.x >= client.right - 2 * ButtonWidth()) return 1;
  return 0;
}

LRESULT CALLBACK ImagePinWindow::WindowProc(HWND window, UINT message,
                                           WPARAM wparam, LPARAM lparam) {
  ImagePinWindow* pin = reinterpret_cast<ImagePinWindow*>(
      GetWindowLongPtr(window, GWLP_USERDATA));
  if (message == WM_NCCREATE) {
    auto* create = reinterpret_cast<CREATESTRUCTW*>(lparam);
    pin = static_cast<ImagePinWindow*>(create->lpCreateParams);
    pin->window_ = window;
    SetWindowLongPtr(window, GWLP_USERDATA, reinterpret_cast<LONG_PTR>(pin));
  }
  if (!pin) return DefWindowProc(window, message, wparam, lparam);
  if (message == WM_NCDESTROY) {
    SetWindowLongPtr(window, GWLP_USERDATA, 0);
    pin->window_ = nullptr;
    // Closing a pin immediately frees its image, even before the manager next
    // prunes the small closed-window object from its collection.
    std::vector<uint8_t>().swap(pin->pixels_);
    return DefWindowProc(window, message, wparam, lparam);
  }
  return pin->HandleMessage(message, wparam, lparam);
}

LRESULT ImagePinWindow::HandleMessage(UINT message, WPARAM wparam,
                                      LPARAM lparam) {
  switch (message) {
    case WM_PAINT:
      Paint();
      return 0;
    case WM_ERASEBKGND:
      return 1;
    case WM_NCHITTEST: {
      POINT point{GET_X_LPARAM(lparam), GET_Y_LPARAM(lparam)};
      ScreenToClient(window_, &point);
      return ButtonAt(point) ? HTCLIENT : HTCAPTION;
    }
    case WM_NCLBUTTONDBLCLK:
      if (wparam == HTCAPTION) {
        RECT bounds{};
        GetWindowRect(window_, &bounds);
        collapsed_ = false;
        Resize(1, POINT{bounds.left, bounds.top});
        return 0;
      }
      break;
    case WM_LBUTTONDOWN:
      pressed_button_ = ButtonAt(POINT{GET_X_LPARAM(lparam), GET_Y_LPARAM(lparam)});
      if (pressed_button_) SetCapture(window_);
      return 0;
    case WM_LBUTTONUP: {
      const int button = pressed_button_;
      pressed_button_ = 0;
      if (GetCapture() == window_) ReleaseCapture();
      if (button != ButtonAt(POINT{GET_X_LPARAM(lparam), GET_Y_LPARAM(lparam)})) {
        return 0;
      }
      if (button == 2) {
        DestroyWindow(window_);
      } else if (button == 1) {
        RECT bounds{};
        GetWindowRect(window_, &bounds);
        collapsed_ = !collapsed_;
        Resize(scale_, POINT{bounds.left, bounds.top});
      }
      return 0;
    }
    case WM_CAPTURECHANGED:
      pressed_button_ = 0;
      return 0;
    case WM_MOUSEWHEEL:
      if (!collapsed_) {
        Resize(scale_ * std::pow(1.1, GET_WHEEL_DELTA_WPARAM(wparam) / 120.0),
               POINT{GET_X_LPARAM(lparam), GET_Y_LPARAM(lparam)});
      }
      return 0;
    case WM_KEYDOWN:
      if (wparam == VK_ESCAPE) {
        DestroyWindow(window_);
        return 0;
      }
      break;
    case WM_DPICHANGED: {
      dpi_ = HIWORD(wparam);
      const auto* suggested = reinterpret_cast<RECT*>(lparam);
      Resize(scale_, POINT{suggested->left, suggested->top});
      return 0;
    }
    case WM_SIZE:
      InvalidateRect(window_, nullptr, FALSE);
      return 0;
    case WM_CLOSE:
      DestroyWindow(window_);
      return 0;
  }
  return DefWindowProc(window_, message, wparam, lparam);
}

void ImagePinWindow::Resize(double scale, POINT anchor) {
  RECT bounds{};
  GetWindowRect(window_, &bounds);
  // Bound extreme scroll sizes without forbidding large captures from being
  // reduced enough to fit a monitor.
  const double maximum = std::min(
      4.0, 16384.0 / std::max(image_width_, image_height_));
  const double minimum = std::min(
      .05, 1.0 / std::max(image_width_, image_height_));
  scale_ = std::clamp(scale, minimum, maximum);
  const int width = std::max(MulDiv(160, static_cast<int>(dpi_), 96),
                            static_cast<int>(image_width_ * scale_) + 2);
  const int height = HeaderHeight() + 2 +
                     (collapsed_ ? 0 : std::max(1, static_cast<int>(
                                                       image_height_ * scale_)));
  const double x_fraction = (anchor.x - bounds.left) /
                            static_cast<double>(std::max(1L, bounds.right - bounds.left));
  const double y_fraction = (anchor.y - bounds.top) /
                            static_cast<double>(std::max(1L, bounds.bottom - bounds.top));
  SetWindowPos(window_, HWND_TOPMOST,
               anchor.x - static_cast<int>(x_fraction * width),
               anchor.y - static_cast<int>(y_fraction * height), width, height,
               SWP_NOACTIVATE);
  InvalidateRect(window_, nullptr, FALSE);
}

void ImagePinWindow::Paint() {
  PAINTSTRUCT paint{};
  HDC device = BeginPaint(window_, &paint);
  RECT client{};
  GetClientRect(window_, &client);
  const HBRUSH background = CreateSolidBrush(RGB(27, 33, 44));
  FillRect(device, &client, background);
  DeleteObject(background);
  if (!collapsed_ && !pixels_.empty()) {
    BITMAPINFO bitmap{};
    bitmap.bmiHeader.biSize = sizeof(BITMAPINFOHEADER);
    bitmap.bmiHeader.biWidth = static_cast<LONG>(image_width_);
    bitmap.bmiHeader.biHeight = -static_cast<LONG>(image_height_);
    bitmap.bmiHeader.biPlanes = 1;
    bitmap.bmiHeader.biBitCount = 32;
    bitmap.bmiHeader.biCompression = BI_RGB;
    const int image_width = std::max(1, static_cast<int>(image_width_ * scale_));
    const int image_height = std::max(1, static_cast<int>(image_height_ * scale_));
    SetStretchBltMode(device, HALFTONE);
    SetBrushOrgEx(device, 0, 0, nullptr);
    StretchDIBits(device, (client.right - image_width) / 2, HeaderHeight(),
                  image_width, image_height, 0, 0,
                  static_cast<int>(image_width_), static_cast<int>(image_height_),
                  pixels_.data(), &bitmap, DIB_RGB_COLORS, SRCCOPY);
  }
  SetBkMode(device, TRANSPARENT);
  SetTextColor(device, RGB(233, 238, 247));
  const auto old_font = SelectObject(device, GetStockObject(DEFAULT_GUI_FONT));
  const std::wstring title = L"Pinned  " +
                            std::to_wstring(static_cast<int>(scale_ * 100)) +
                            L"%  \u00b7 Scroll to resize";
  RECT title_bounds{8, 0, client.right - 2 * ButtonWidth(), HeaderHeight()};
  DrawTextW(device, title.c_str(), -1, &title_bounds,
             DT_SINGLELINE | DT_VCENTER | DT_END_ELLIPSIS);
  RECT collapse{client.right - 2 * ButtonWidth(), 0,
                client.right - ButtonWidth(), HeaderHeight()};
  RECT close{client.right - ButtonWidth(), 0, client.right, HeaderHeight()};
  DrawTextW(device, collapsed_ ? L"+" : L"\u2212", -1, &collapse,
             DT_SINGLELINE | DT_CENTER | DT_VCENTER);
  DrawTextW(device, L"\u00d7", -1, &close,
             DT_SINGLELINE | DT_CENTER | DT_VCENTER);
  SelectObject(device, old_font);
  EndPaint(window_, &paint);
}
