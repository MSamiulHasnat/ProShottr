# ProShottr architecture

This document describes the implemented Windows-first foundation. The broader target architecture and roadmap remain in [`plan.md`](../plan.md).

## Current data flow

```text
Windows global hotkey / EditorScreen
  -> native runner hides the editor window
  -> CaptureService (testable Dart boundary)
  -> generated flutter_rust_bridge API
  -> Rust capture facade
  -> WindowsCapturer (Win32 GDI compatibility backend)
  -> frozen virtual-desktop PNG frame
  -> native runner presents a borderless top-most overlay
  -> Flutter region selector (coordinates, color, dimensions, resize/move)
  -> Rust crop operation
  -> Quick HUD / Pro editor + vector annotation painter
  -> clipboard or native Save As service
```

The UI depends on `CaptureService`, not directly on generated FFI calls. Tests replace that service with an in-memory fake, while production uses `NativeCaptureService`.

## Rust core

`core/src/capture` owns the platform-neutral `ScreenCapturer` contract, capability reporting, captured-frame metadata, validated crop, and export validation. `core/src/capture/windows.rs` is the first adapter. It captures Windows' virtual-screen coordinates so negative monitor origins and multi-monitor desktop sizes survive the platform seam, and owns the native timestamped Save As dialog.

`core/src/scene.rs` establishes version 1 of the serializable, non-destructive document model and its undo/redo semantics. The Flutter editor currently keeps lightweight immutable display objects for 60 fps interaction. Persisted `.proshot` documents will converge on the Rust schema as document open/save work lands.

## Flutter editor

The canvas retains the source screenshot as the base layer. Shapes, stickers, text, and mosaic regions are painted separately, and rasterization happens only through the export `RepaintBoundary`. `EditorController` stores immutable annotation snapshots, which makes undo and redo predictable and clears redo history after a divergent edit.

The Quick HUD implements the verified WeChat order and defaults: filled rectangle, outline ellipse, sticker picker, straight arrow, smoothed brush, manual mosaic, and three-size text. Its style controls use the specified blue/green/yellow/grey/white/red palette and thin/medium/thick presets. The Pro editor uses the same scene controller and can be opened without rasterizing those annotations.

## Windows host

The Flutter runner registers `Alt+Shift+S` with `RegisterHotKey`. It preserves the normal editor placement and styles, hides the editor before capture, and then turns the same Flutter host into a `WS_POPUP` top-most window spanning the virtual screen. Finishing, cancelling, saving, or opening the Pro editor restores the original placement and window styles.

The runner also owns the Windows notification-area icon. Closing the editor hides it to the tray, tray Show/Exit commands control its lifetime, and a named process mutex makes a second Start Menu launch show the existing editor instead of creating a duplicate process.

## Windows progression

1. Add Windows Graphics Capture as the primary GPU path; retain GDI as fallback.
2. Extend top-level window detection to child/UI edge detection and snapping.
3. Add AI-assisted sensitive-region masking alongside manual mosaic.
4. Add pin-to-screen as a lightweight always-on-top image window.
5. Add delayed/repeat capture and configurable hotkeys before expanding to macOS.
