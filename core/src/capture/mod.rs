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

/// One physical display, in virtual-desktop pixels.
///
/// `scale_factor` is the display's effective DPI divided by 96, so a 200%
/// monitor reports 2.0. Every geometry value stays physical; the UI divides by
/// the scale only when the user asks for logical units.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct DisplayInfo {
    pub id: String,
    pub name: String,
    pub origin_x: i32,
    pub origin_y: i32,
    pub width: u32,
    pub height: u32,
    pub scale_factor: f64,
    pub is_primary: bool,
}

impl DisplayInfo {
    /// Physical pixels of this display inside a virtual-desktop rectangle.
    fn overlap_area(&self, left: i32, top: i32, width: u32, height: u32) -> u64 {
        let overlap_left = i64::from(self.origin_x).max(i64::from(left));
        let overlap_top = i64::from(self.origin_y).max(i64::from(top));
        let overlap_right = (i64::from(self.origin_x) + i64::from(self.width))
            .min(i64::from(left) + i64::from(width));
        let overlap_bottom = (i64::from(self.origin_y) + i64::from(self.height))
            .min(i64::from(top) + i64::from(height));
        if overlap_right <= overlap_left || overlap_bottom <= overlap_top {
            return 0;
        }
        ((overlap_right - overlap_left) * (overlap_bottom - overlap_top)) as u64
    }
}

/// Scale factor of the display that owns the largest part of a rectangle.
///
/// Ties prefer the primary display, then enumeration order. `default` is
/// returned when no display is known or the rectangle touches none of them.
pub fn dominant_scale_factor(
    displays: &[DisplayInfo],
    left: i32,
    top: i32,
    width: u32,
    height: u32,
    default: f64,
) -> f64 {
    let mut best: Option<(&DisplayInfo, u64)> = None;
    for display in displays {
        let area = display.overlap_area(left, top, width, height);
        if area == 0 {
            continue;
        }
        let better = match best {
            None => true,
            Some((current, current_area)) => {
                area > current_area
                    || (area == current_area && display.is_primary && !current.is_primary)
            }
        };
        if better {
            best = Some((display, area));
        }
    }
    best.map_or(default, |(display, _)| display.scale_factor)
}

/// A frozen raster plus the metadata needed to place it on the desktop.
///
/// `scale_factor` belongs to the display that owns most of the frame (see
/// [`dominant_scale_factor`]); `displays` lists every display so the UI can
/// resolve the scale under any point of a multi-monitor capture.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct CapturedFrame {
    pub png_bytes: Vec<u8>,
    pub width: u32,
    pub height: u32,
    pub origin_x: i32,
    pub origin_y: i32,
    pub scale_factor: f64,
    pub displays: Vec<DisplayInfo>,
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
        pin_window: cfg!(windows),
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

    let origin_x = frame.origin_x.saturating_add(left as i32);
    let origin_y = frame.origin_y.saturating_add(top as i32);
    // A crop can move entirely onto another monitor, so its scale is resolved
    // again from the display list rather than inherited from the desktop.
    let scale_factor = dominant_scale_factor(
        &frame.displays,
        origin_x,
        origin_y,
        width,
        height,
        frame.scale_factor,
    );

    Ok(CapturedFrame {
        png_bytes,
        width,
        height,
        origin_x,
        origin_y,
        scale_factor,
        displays: frame.displays,
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

    fn display(
        id: &str,
        origin_x: i32,
        width: u32,
        scale_factor: f64,
        primary: bool,
    ) -> DisplayInfo {
        DisplayInfo {
            id: id.to_owned(),
            name: id.to_owned(),
            origin_x,
            origin_y: 0,
            width,
            height: 100,
            scale_factor,
            is_primary: primary,
        }
    }

    fn frame(width: u32, height: u32, displays: Vec<DisplayInfo>) -> CapturedFrame {
        let source = image::RgbaImage::from_pixel(width, height, image::Rgba([1, 2, 3, 255]));
        let mut png_bytes = Vec::new();
        image::DynamicImage::ImageRgba8(source)
            .write_to(&mut Cursor::new(&mut png_bytes), image::ImageFormat::Png)
            .unwrap();
        CapturedFrame {
            png_bytes,
            width,
            height,
            origin_x: -10,
            origin_y: 20,
            scale_factor: 1.0,
            displays,
        }
    }

    #[test]
    fn crops_a_frame_and_updates_its_origin() {
        let cropped = crop_frame(frame(4, 3, Vec::new()), 1, 1, 2, 2).unwrap();
        assert_eq!((cropped.width, cropped.height), (2, 2));
        assert_eq!((cropped.origin_x, cropped.origin_y), (-9, 21));
        assert_eq!(cropped.scale_factor, 1.0);
        assert!(cropped.displays.is_empty());
    }

    #[test]
    fn dominant_scale_follows_the_display_owning_most_of_the_rectangle() {
        let displays = vec![
            display("left", -200, 200, 1.0, false),
            display("primary", 0, 300, 2.0, true),
        ];
        assert_eq!(
            dominant_scale_factor(&displays, -150, 10, 100, 10, 9.0),
            1.0
        );
        assert_eq!(dominant_scale_factor(&displays, 10, 10, 100, 10, 9.0), 2.0);
        // Mostly on the left display, even though it also touches the primary.
        assert_eq!(dominant_scale_factor(&displays, -90, 10, 100, 10, 9.0), 1.0);
        // An even split prefers the primary display.
        assert_eq!(dominant_scale_factor(&displays, -50, 10, 100, 10, 9.0), 2.0);
        // Off every display, or with no displays known, keeps the default.
        assert_eq!(dominant_scale_factor(&displays, 500, 500, 10, 10, 9.0), 9.0);
        assert_eq!(dominant_scale_factor(&[], 10, 10, 10, 10, 9.0), 9.0);
    }

    #[test]
    fn cropping_onto_another_display_resolves_that_display_scale() {
        // The frame spans x = -10..=5 in virtual coordinates: the left display
        // at 1x owns -10..0 and the right display at 2.5x owns 0..15.
        let displays = vec![
            display("left", -10, 10, 1.0, true),
            display("right", 0, 15, 2.5, false),
        ];
        let source = frame(15, 3, displays.clone());
        let left = crop_frame(source.clone(), 0, 0, 8, 3).unwrap();
        assert_eq!(left.scale_factor, 1.0);
        let right = crop_frame(source, 11, 0, 4, 3).unwrap();
        assert_eq!(right.scale_factor, 2.5);
        assert_eq!(right.displays, displays);
    }
}
