use crate::capture::{CapturedFrame, PlatformCapabilities, platform_capabilities};

#[flutter_rust_bridge::frb(sync)]
pub fn capabilities() -> PlatformCapabilities {
    platform_capabilities()
}

pub fn capture_desktop() -> Result<CapturedFrame, String> {
    crate::capture::capture_desktop().map_err(|error| error.to_string())
}

pub fn crop_frame(
    frame: CapturedFrame,
    left: u32,
    top: u32,
    width: u32,
    height: u32,
) -> Result<CapturedFrame, String> {
    crate::capture::crop_frame(frame, left, top, width, height).map_err(|error| error.to_string())
}

pub fn save_png(png_bytes: Vec<u8>) -> Result<String, String> {
    crate::capture::save_png(&png_bytes).map_err(|error| error.to_string())
}

pub fn save_png_as(png_bytes: Vec<u8>) -> Result<Option<String>, String> {
    crate::capture::save_png_as(&png_bytes).map_err(|error| error.to_string())
}

#[flutter_rust_bridge::frb(init)]
pub fn init_app() {
    flutter_rust_bridge::setup_default_user_utils();
}
