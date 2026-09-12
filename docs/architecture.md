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

`core/src/capture` owns the platform-neutral `ScreenCapturer` contract, capability reporting, captured-frame metadata, validated crop, and export validation. `core/src/capture/windows.rs` is the first adapter. It captures Windows' virtual-screen coordinates so negative monitor origins and multi-monitor desktop sizes survive the platform seam. Every `CapturedFrame` also carries the display list: each `DisplayInfo` holds a monitor's physical bounds and its effective per-monitor scale (`GetDpiForMonitor` divided by 96, with the system DPI as fallback). A frame's `scale_factor` is the scale of the display that owns most of its pixels, so cropping a desktop capture onto another monitor re-resolves the scale in Rust rather than in the UI. Its original Save As API remains available through FFI, but the editor routes output through `CaptureOutputService`: the Windows runner owns the active Save As dialog and pins, and `super_clipboard` writes composited PNGs. Tests inject an output fake to exercise success, cancellation, failure, and exported pixel dimensions.

`core/src/scene.rs` establishes version 1 of the serializable, non-destructive document model and its undo/redo semantics, including an optional `crop` rectangle that defines the export size without touching the base image. The Flutter editor currently keeps lightweight immutable display objects for 60 fps interaction. Persisted `.proshot` documents will converge on the Rust schema as document open/save work lands.

## Flutter editor

The canvas retains the source screenshot as the base layer. Shapes, stickers, text, and mosaic regions are painted separately, and rasterization happens only through the export `RepaintBoundary`. `EditorController` stores immutable scene snapshots (annotations plus the crop), which makes undo and redo predictable and clears redo history after a divergent edit.

A crop is part of that scene, not a new raster. The canvas sizes the export boundary to the crop and shifts the full image and its annotations underneath it, so annotations keep their source-pixel coordinates, exports are exactly the crop's physical pixels, and a crop can be undone, redone, or reset like any other step. The crop tool only ever shrinks the visible region; growing it again is a reset or an undo.

The Quick HUD implements the verified WeChat order and defaults: filled rectangle, outline ellipse, sticker picker, straight arrow, smoothed brush, manual mosaic, and three-size text. Its style controls use the specified blue/green/yellow/grey/white/red palette and thin/medium/thick presets. The Pro editor uses the same scene controller and can be opened without rasterizing those annotations. A capture session retains a snapshot of the previous image and undo/redo state; cancellation restores that state. Generation checks reject late capture/crop replies after cancellation.

## Capture overlay and Quick HUD specs

Two surfaces have a literal target layout that this codebase is being built against, and one rule governs both. Read them before changing either widget or the runner's window styles.

- **Capture overlay** — [`plan.md` §8.8](../plan.md#88-capture-trigger-overlay--the-pre-selection-stage-spec) defines the dim wash, the drawn `+` crosshair, the cursor probe box, hover window detection, and the click-versus-drag contract. Implemented in `ui/lib/features/capture/capture_selection_overlay.dart`, with window hit-testing over the `proshottr/windows_capture_window` method channel. RGB/HEX sampling and copy-then-dismiss shortcuts are implemented and tested. The probe's `@2x`-style suffix and the logical-unit conversion use the scale of the display under the cursor, and the `w × h` label uses the display under the selection centre, from the frame's display list. Detection rejects stale asynchronous responses and refreshes within overlapping windows. The native runner trims highlights using DWM extended frame bounds; native runtime verification remains pending.
- **Quick HUD** — [`plan.md` §8.9](../plan.md#89-post-capture-editing-toolbar--the-quick-hud-layout-spec) defines the four button groups, style controls, anchoring, and overflow. `ui/lib/features/capture/quick_capture_view.dart` implements those groups, pin/share actions, a category/recents sticker panel, and a passive resolution badge. Content and AI-masking controls remain disabled with explanations until their engines exist. The badge shows the pending or committed crop size, updates when its frame changes, and supports logical units from the frame's dominant per-monitor scale. The crop tool (overflow menu, `C`) shrinks the un-dimmed region and re-anchors the badge and toolbar; `Shift+C` or **Reset crop** restores the full capture. Tall selections with no space above or below use the same reduced-opacity inset fallback as full-screen captures.
- **Windowing model** — [`plan.md` §8.10](../plan.md#810-windowing-model--the-capture-session-is-an-overlay-never-an-app-window) is the rule that a capture session presents no application window: no taskbar button, no Alt-Tab entry, no visible main window, until the user explicitly opens the Pro editor, the OCR window, or a pin. It constrains `ui/windows/runner/flutter_window.cpp`, not the Dart layer.

Each spec section carries its own status table, which is the authoritative list of what is built versus outstanding.

## Windows host

The Flutter runner registers `Alt+Shift+S` with `RegisterHotKey`. It preserves the normal editor placement and styles, hides the editor before capture, and then turns the same Flutter host into a `WS_POPUP` top-most window spanning the virtual screen. Finishing or cancelling restores placement and styles while keeping the editor hidden. Explicitly opening the Pro editor promotes it after its Flutter content is ready. Save As is owned by the overlay and leaves the session available afterwards.

The overlay uses `WS_EX_TOOLWINDOW | WS_EX_TOPMOST`, without `WS_EX_APPWINDOW`. The runner remembers the prior foreground window and restores it on normal exit; focus-loss cancellation preserves the user's newly selected foreground app. Native PNG pin windows are independent of the Flutter host, so hiding the capture leaves pins visible. Their decoded image buffers are freed on close. These native behaviors require the pending checks in [Windows QA](windows-qa.md).

The runner also owns the Windows notification-area icon. Closing the editor hides it to the tray, tray Show/Exit commands control its lifetime, and a named process mutex makes a second Start Menu launch show the existing editor instead of creating a duplicate process.

## Windows progression

1. Compile and run the native acceptance matrix on a configured Windows host, including the mixed-DPI probe, badge, and crop-export checks, then rebuild the installer.
2. Implement OCR/content probing and scrolling capture behind the existing disabled content actions.
3. Add Windows Graphics Capture as the primary GPU path; retain GDI as fallback.
4. Extend top-level window detection to child/UI edge detection and snapping.
5. Add AI-assisted sensitive-region masking alongside manual mosaic.
6. Validate native pins across mixed-DPI monitors and add further pin preferences.
7. Add delayed/repeat capture and configurable hotkeys before expanding to macOS.
