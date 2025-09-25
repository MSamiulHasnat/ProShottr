# ProShottr

ProShottr is an open source, cross-platform screenshot toolkit inspired by Shottr. The initial milestone targets Windows with fast window/region capture, lightweight annotation tools, automatic clipboard hand-off, and depth styling for share-ready snaps. macOS and Linux adapters will follow the same architecture once the Windows flow is battle-tested.

## ✨ Feature highlights

- **One-tap capture** – Global hotkeys (default `Win` + `Shift` + `3/4`) or a tray menu trigger either window or region capture. Hover feedback locks to the window under the cursor; click-drag selects custom regions.
- **Annotation workspace** – After capture, an overlay hosts arrow, rectangle, ellipse, text, pencil, eraser, undo/redo, and exit controls. Everything renders at native resolution, with adjustable stroke width and palette.
- **Depth polish** – Window shadows, blur, and corner rounding are applied through a configurable depth styler for a subtle, professional finish.
- **Clipboard & autosave** – Final images copy straight to the clipboard. Optional autosave writes to a user-defined folder with timestamp + window-title naming.
- **Configurable preferences** – Live settings dialog for hotkeys, output format (PNG/JPEG/BMP/WebP/TIFF), clipboard/autosave toggles, and depth effect tweaks.
- **System tray companion** – A tray icon exposes quick actions (capture window/region, preferences, quit) while keeping the main UI invisible until needed.

## 🏗️ Architecture at a glance

- **Qt 6 + CMake** foundation with QML/Qt Quick for UI overlays and C++ back-end services.
- **Platform adapters** – `WindowsCaptureAdapter`, `WindowsHotkeyService`, and `WindowsPermissionHelper` wrap Win32 APIs. Abstract interfaces pave the way for macOS (CoreGraphics/EventTap) and Linux (X11/Wayland) ports.
- **Capture pipeline** – `CaptureOrchestrator` coordinates permissions, overlay state, and post-processing via `DepthStyler` and `ClipboardExportService`.
- **Annotation state** – A dedicated `AnnotationHistory` object tracks commands for redo/undo and integrates with the QML canvas.

## 📦 Requirements

- **Windows development environment** (PowerShell or cmd shell) with:
	- Microsoft Visual C++ 2022 toolchain (or compatible) with C++20 support.
	- Qt 6.5+ installed (Desktop `msvc` kit) and `Qt6_DIR`/`CMAKE_PREFIX_PATH` pointing to the Qt CMake packages.
- **CMake 3.26+** and **Ninja** (or `nmake`/`jom`) recommended for builds.

> ℹ️ The dev-container used for authoring does not bundle Qt, so `cmake` configuration fails here by design. Run the build locally on a Windows machine with Qt installed.

## 🚀 Build & run (Windows)

```powershell
# From a Visual Studio Developer PowerShell
cmake -S . -B build -G "Ninja" `
	-DCMAKE_BUILD_TYPE=Release `
	-DCMAKE_PREFIX_PATH="C:/Qt/6.5.3/msvc2019_64"

cmake --build build

# Launch the app
build/bin/ProShottr.exe
```

### Hotkey configuration

- Default window capture hotkey: `Win + Shift + 3`.
- Default region capture hotkey: `Win + Shift + 4`.
- Use **Preferences → Hotkeys** to record new combinations (conflicts with reserved system shortcuts will be rejected).

### Annotation workflow

1. Trigger a capture via hotkey or tray menu.
2. Hover/select your target; click (window) or drag (region).
3. Annotate using the floating toolbar; the canvas maintains native resolution while scaling to fit on screen.
4. Click **Done** to copy the annotated image (and optionally autosave). Close with **✕** to abort.

## 🧭 Roadmap

- [ ] macOS adapter using CoreGraphics + EventTap, with notarised build pipeline.
- [ ] Linux adapter for X11/Wayland (XCB + xdg-desktop-portal integration).
- [ ] In-app tutorial overlays and quick measurement tools.
- [ ] Cloud export integrations (OneDrive, iCloud, etc.).

## 🤝 Contributing

1. Fork and clone the repo.
2. Install Qt 6.5+ and toolchain for your platform.
3. Run `cmake --build` as above; add the `-DCMAKE_BUILD_TYPE=Debug` flag for development builds.
4. Submit PRs targeting the `main` branch. Please include screenshots/GIFs for UI changes and mention any new dependencies.

## 📄 License

ProShottr is released under the MIT License (see `LICENSE`).