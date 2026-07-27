use std::ffi::c_void;
use std::mem::size_of;
use std::os::windows::ffi::OsStrExt;
use std::path::PathBuf;
use std::time::{SystemTime, UNIX_EPOCH};
use std::{ffi::OsStr, fs};

use image::RgbaImage;
use windows::Win32::Graphics::Gdi::{
    BI_RGB, BITMAPINFO, BITMAPINFOHEADER, BitBlt, CAPTUREBLT, CreateCompatibleBitmap,
    CreateCompatibleDC, DIB_RGB_COLORS, DeleteDC, DeleteObject, GetDC, GetDIBits, ReleaseDC,
    SRCCOPY, SelectObject,
};
use windows::Win32::UI::Controls::Dialogs::{
    CommDlgExtendedError, GetSaveFileNameW, OFN_NOCHANGEDIR, OFN_OVERWRITEPROMPT,
    OFN_PATHMUSTEXIST, OPENFILENAMEW,
};
use windows::Win32::UI::WindowsAndMessaging::{
    GetSystemMetrics, SM_CXVIRTUALSCREEN, SM_CYVIRTUALSCREEN, SM_XVIRTUALSCREEN, SM_YVIRTUALSCREEN,
};
use windows::core::{PCWSTR, PWSTR};

use super::{CaptureError, CapturedFrame, DisplayInfo, ScreenCapturer};

pub struct WindowsCapturer;

impl ScreenCapturer for WindowsCapturer {
    fn displays(&self) -> Result<Vec<DisplayInfo>, CaptureError> {
        let bounds = virtual_screen_bounds()?;
        Ok(vec![DisplayInfo {
            id: "virtual-desktop".to_owned(),
            name: "Windows virtual desktop".to_owned(),
            origin_x: bounds.x,
            origin_y: bounds.y,
            width: bounds.width,
            height: bounds.height,
            is_primary: true,
        }])
    }

    fn capture_desktop(&self) -> Result<CapturedFrame, CaptureError> {
        let bounds = virtual_screen_bounds()?;
        let pixel_count = bounds.width as usize * bounds.height as usize;
        let mut bgra = vec![0_u8; pixel_count * 4];

        unsafe {
            let screen_dc = GetDC(None);
            if screen_dc.is_invalid() {
                return Err(last_error("GetDC"));
            }
            let memory_dc = CreateCompatibleDC(Some(screen_dc));
            if memory_dc.is_invalid() {
                let _ = ReleaseDC(None, screen_dc);
                return Err(last_error("CreateCompatibleDC"));
            }
            let bitmap =
                CreateCompatibleBitmap(screen_dc, bounds.width as i32, bounds.height as i32);
            if bitmap.is_invalid() {
                let _ = DeleteDC(memory_dc);
                let _ = ReleaseDC(None, screen_dc);
                return Err(last_error("CreateCompatibleBitmap"));
            }

            let previous = SelectObject(memory_dc, bitmap.into());
            let copied = BitBlt(
                memory_dc,
                0,
                0,
                bounds.width as i32,
                bounds.height as i32,
                Some(screen_dc),
                bounds.x,
                bounds.y,
                SRCCOPY | CAPTUREBLT,
            );

            let mut bitmap_info = BITMAPINFO {
                bmiHeader: BITMAPINFOHEADER {
                    biSize: size_of::<BITMAPINFOHEADER>() as u32,
                    biWidth: bounds.width as i32,
                    biHeight: -(bounds.height as i32),
                    biPlanes: 1,
                    biBitCount: 32,
                    biCompression: BI_RGB.0,
                    biSizeImage: (pixel_count * 4) as u32,
                    ..Default::default()
                },
                ..Default::default()
            };

            let scan_lines = if copied.is_ok() {
                GetDIBits(
                    memory_dc,
                    bitmap,
                    0,
                    bounds.height,
                    Some(bgra.as_mut_ptr().cast::<c_void>()),
                    &mut bitmap_info,
                    DIB_RGB_COLORS,
                )
            } else {
                0
            };

            let _ = SelectObject(memory_dc, previous);
            let _ = DeleteObject(bitmap.into());
            let _ = DeleteDC(memory_dc);
            let _ = ReleaseDC(None, screen_dc);

            if copied.is_err() {
                return Err(last_error("BitBlt"));
            }
            if scan_lines == 0 {
                return Err(last_error("GetDIBits"));
            }
        }

        for pixel in bgra.chunks_exact_mut(4) {
            pixel.swap(0, 2);
            pixel[3] = 255;
        }

        let rgba = RgbaImage::from_raw(bounds.width, bounds.height, bgra).ok_or_else(|| {
            CaptureError::InvalidFrame("pixel buffer size did not match capture bounds".to_owned())
        })?;
        let png_bytes = super::encode_png_fast(&rgba)?;

        Ok(CapturedFrame {
            png_bytes,
            width: bounds.width,
            height: bounds.height,
            origin_x: bounds.x,
            origin_y: bounds.y,
            scale_factor: 1.0,
        })
    }
}

struct ScreenBounds {
    x: i32,
    y: i32,
    width: u32,
    height: u32,
}

fn virtual_screen_bounds() -> Result<ScreenBounds, CaptureError> {
    let x = unsafe { GetSystemMetrics(SM_XVIRTUALSCREEN) };
    let y = unsafe { GetSystemMetrics(SM_YVIRTUALSCREEN) };
    let width = unsafe { GetSystemMetrics(SM_CXVIRTUALSCREEN) };
    let height = unsafe { GetSystemMetrics(SM_CYVIRTUALSCREEN) };
    if width <= 0 || height <= 0 {
        return Err(CaptureError::InvalidFrame(format!(
            "virtual desktop dimensions were {width}x{height}"
        )));
    }
    Ok(ScreenBounds {
        x,
        y,
        width: width as u32,
        height: height as u32,
    })
}

fn last_error(operation: &str) -> CaptureError {
    CaptureError::Windows(format!(
        "{operation}: {}",
        windows::core::Error::from_thread()
    ))
}

pub fn save_png_as(png_bytes: &[u8]) -> Result<Option<String>, CaptureError> {
    let timestamp = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default()
        .as_millis();
    let suggested = format!("ProShottr-{timestamp}.png");
    let mut file_buffer = vec![0_u16; 32_768];
    let suggested_wide: Vec<u16> = OsStr::new(&suggested).encode_wide().collect();
    file_buffer[..suggested_wide.len()].copy_from_slice(&suggested_wide);

    let filter: Vec<u16> = OsStr::new("PNG image (*.png)\0*.png\0All files (*.*)\0*.*\0\0")
        .encode_wide()
        .collect();
    let title: Vec<u16> = OsStr::new("Save ProShottr capture\0")
        .encode_wide()
        .collect();
    let extension: Vec<u16> = OsStr::new("png\0").encode_wide().collect();
    let initial_directory = std::env::var_os("USERPROFILE")
        .map(PathBuf::from)
        .unwrap_or_else(std::env::temp_dir)
        .join("Desktop");
    let mut initial_wide: Vec<u16> = initial_directory.as_os_str().encode_wide().collect();
    initial_wide.push(0);

    let mut dialog = OPENFILENAMEW {
        lStructSize: size_of::<OPENFILENAMEW>() as u32,
        lpstrFilter: PCWSTR(filter.as_ptr()),
        nFilterIndex: 1,
        lpstrFile: PWSTR(file_buffer.as_mut_ptr()),
        nMaxFile: file_buffer.len() as u32,
        lpstrInitialDir: PCWSTR(initial_wide.as_ptr()),
        lpstrTitle: PCWSTR(title.as_ptr()),
        Flags: OFN_OVERWRITEPROMPT | OFN_PATHMUSTEXIST | OFN_NOCHANGEDIR,
        lpstrDefExt: PCWSTR(extension.as_ptr()),
        ..Default::default()
    };

    let accepted = unsafe { GetSaveFileNameW(&mut dialog).as_bool() };
    if !accepted {
        let code = unsafe { CommDlgExtendedError() };
        if code.0 == 0 {
            return Ok(None);
        }
        return Err(CaptureError::Windows(format!(
            "Save As dialog failed with code {}",
            code.0
        )));
    }

    let length = file_buffer
        .iter()
        .position(|value| *value == 0)
        .unwrap_or(file_buffer.len());
    let path = PathBuf::from(String::from_utf16_lossy(&file_buffer[..length]));
    fs::write(&path, png_bytes)?;
    Ok(Some(path.to_string_lossy().into_owned()))
}
