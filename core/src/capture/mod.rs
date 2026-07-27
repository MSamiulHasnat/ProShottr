//! Platform capture contracts and the active platform adapter.

use std::fs;
use std::io::Cursor;
use std::path::PathBuf;
use std::time::{SystemTime, UNIX_EPOCH};

use image::codecs::png::{CompressionType, FilterType, PngEncoder};
use image::{ColorType, ImageEncoder, RgbaImage};
use serde::{Deserialize, Serialize};
use thiserror::Error;

#[cfg(windows)]
mod windows;

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct DisplayInfo {
    pub id: String,
    pub name: String,
    pub origin_x: i32,
    pub origin_y: i32,
    pub width: u32,
    pub height: u32,
    pub is_primary: bool,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct CapturedFrame {
    pub png_bytes: Vec<u8>,
    pub width: u32,
    pub height: u32,
    pub origin_x: i32,
    pub origin_y: i32,
    pub scale_factor: f64,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct PlatformCapabilities {
    pub platform: String,
    pub desktop_capture: bool,
    pub region_overlay: bool,
    pub global_hotkey: bool,
    pub pin_window: bool,
}

#[derive(Debug, Error)]
pub enum CaptureError {
    #[error("screen capture is not supported on this platform yet")]
    Unsupported,
    #[error("Win32 capture operation failed: {0}")]
    Windows(String),
    #[error("captured frame was invalid: {0}")]
    InvalidFrame(String),
    #[error("could not save capture: {0}")]
    Save(#[from] std::io::Error),
}

pub trait ScreenCapturer {
    fn displays(&self) -> Result<Vec<DisplayInfo>, CaptureError>;
    fn capture_desktop(&self) -> Result<CapturedFrame, CaptureError>;
}

pub fn platform_capabilities() -> PlatformCapabilities {
    PlatformCapabilities {
        platform: std::env::consts::OS.to_owned(),
        desktop_capture: cfg!(windows),
        region_overlay: cfg!(windows),
        global_hotkey: cfg!(windows),
        pin_window: false,
    }
}

pub fn capture_desktop() -> Result<CapturedFrame, CaptureError> {
    #[cfg(windows)]
    {
        windows::WindowsCapturer.capture_desktop()
    }

    #[cfg(not(windows))]
    {
        Err(CaptureError::Unsupported)
    }
}

pub fn crop_frame(
    frame: CapturedFrame,
    left: u32,
    top: u32,
    width: u32,
    height: u32,
) -> Result<CapturedFrame, CaptureError> {
    if width == 0 || height == 0 {
        return Err(CaptureError::InvalidFrame(
            "crop dimensions must be greater than zero".to_owned(),
        ));
    }
    let right = left.checked_add(width).ok_or_else(|| {
        CaptureError::InvalidFrame("crop horizontal bounds overflowed".to_owned())
    })?;
    let bottom = top
        .checked_add(height)
        .ok_or_else(|| CaptureError::InvalidFrame("crop vertical bounds overflowed".to_owned()))?;
    if right > frame.width || bottom > frame.height {
        return Err(CaptureError::InvalidFrame(format!(
            "crop {left},{top} {width}x{height} exceeds frame {}x{}",
            frame.width, frame.height
        )));
    }

    let source = image::load_from_memory(&frame.png_bytes)
        .map_err(|error| CaptureError::InvalidFrame(error.to_string()))?;
    let cropped = source.crop_imm(left, top, width, height).to_rgba8();
    let png_bytes = encode_png_fast(&cropped)?;

    Ok(CapturedFrame {
        png_bytes,
        width,
        height,
        origin_x: frame.origin_x.saturating_add(left as i32),
        origin_y: frame.origin_y.saturating_add(top as i32),
        scale_factor: frame.scale_factor,
    })
}

pub(super) fn encode_png_fast(image: &RgbaImage) -> Result<Vec<u8>, CaptureError> {
    let mut png_bytes = Vec::new();
    PngEncoder::new_with_quality(
        Cursor::new(&mut png_bytes),
        CompressionType::Fast,
        FilterType::NoFilter,
    )
    .write_image(
        image.as_raw(),
        image.width(),
        image.height(),
        ColorType::Rgba8.into(),
    )
    .map_err(|error| CaptureError::InvalidFrame(error.to_string()))?;
    Ok(png_bytes)
}

pub fn save_png(png_bytes: &[u8]) -> Result<String, CaptureError> {
    validate_png(png_bytes)?;

    let root = std::env::var_os("USERPROFILE")
        .map(PathBuf::from)
        .unwrap_or_else(std::env::temp_dir)
        .join("Pictures")
        .join("ProShottr");
    fs::create_dir_all(&root)?;

    let timestamp = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default()
        .as_millis();
    let path = root.join(format!("ProShottr-{timestamp}.png"));
    fs::write(&path, png_bytes)?;
    Ok(path.to_string_lossy().into_owned())
}

pub fn save_png_as(png_bytes: &[u8]) -> Result<Option<String>, CaptureError> {
    validate_png(png_bytes)?;

    #[cfg(windows)]
    {
        windows::save_png_as(png_bytes)
    }

    #[cfg(not(windows))]
    {
        save_png(png_bytes).map(Some)
    }
}

fn validate_png(png_bytes: &[u8]) -> Result<(), CaptureError> {
    if png_bytes.len() < 8 || &png_bytes[..8] != b"\x89PNG\r\n\x1a\n" {
        return Err(CaptureError::InvalidFrame(
            "export data is not a PNG image".to_owned(),
        ));
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn rejects_non_png_export_data() {
        let error = save_png(b"not a png").expect_err("invalid bytes must fail");
        assert!(matches!(error, CaptureError::InvalidFrame(_)));
    }

    #[test]
    fn capability_platform_is_populated() {
        assert!(!platform_capabilities().platform.is_empty());
    }

    #[test]
    fn crops_a_frame_and_updates_its_origin() {
        let source = image::RgbaImage::from_pixel(4, 3, image::Rgba([1, 2, 3, 255]));
        let mut png_bytes = Vec::new();
        image::DynamicImage::ImageRgba8(source)
            .write_to(&mut Cursor::new(&mut png_bytes), image::ImageFormat::Png)
            .unwrap();
        let frame = CapturedFrame {
            png_bytes,
            width: 4,
            height: 3,
            origin_x: -10,
            origin_y: 20,
            scale_factor: 1.0,
        };

        let cropped = crop_frame(frame, 1, 1, 2, 2).unwrap();
        assert_eq!((cropped.width, cropped.height), (2, 2));
        assert_eq!((cropped.origin_x, cropped.origin_y), (-9, 21));
    }
}
