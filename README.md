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

## �️ Complete Setup Guide (Windows)

### Step 1: Install Visual Studio (C++ Compiler)

1. Download **Visual Studio 2022 Community** (free) from [visualstudio.microsoft.com](https://visualstudio.microsoft.com/downloads/)
2. During installation, select the **"Desktop development with C++"** workload
3. This installs the MSVC compiler and CMake automatically
4. Restart your computer after installation

### Step 2: Install Qt 6 with MSVC Support

1. Go to [qt.io/download-qt-installer](https://www.qt.io/download-qt-installer) and download the Qt Online Installer
2. Run the installer and create a Qt account (free)
3. In the installer, select **Custom Installation**
4. Expand **Qt 6.9.2** (or latest 6.x version)
5. **IMPORTANT**: Check **"MSVC 2022 64-bit"** (not MinGW) - this creates the required `msvc2022_64` folder
6. You can uncheck extras like Qt PDF, Qt WebEngine, Qt Insight Tracker - they're not needed
7. Install to the default location (`C:\Qt`)

### Step 3: Open the Developer Shell

1. Press **Windows key** and type **"Developer PowerShell for VS 2022"**
2. Click to open it (this loads the MSVC compiler environment)
3. Alternative: You can also use **"x64 Native Tools Command Prompt for VS 2022"** if you prefer cmd over PowerShell

### Step 4: Verify Your Environment

```powershell
# Check if CMake is available
cmake --version

# Check if MSVC compiler is available  
cl

# You should see version info for both. If either fails, reopen the Developer PowerShell.
```

### Step 5: Clone the ProShottr Repository

```powershell
# Navigate to your development folder
cd C:\Users\YourUsername\Documents

# Clone the repository
git clone https://github.com/MSamiulHasnat/ProShottr.git
cd ProShottr
```

### Step 6: Configure Qt Path

```powershell
# Set the Qt path (adjust version number if different)
$env:CMAKE_PREFIX_PATH = "C:/Qt/6.9.2/msvc2022_64"

# Alternative: If you have MSVC 2019 64-bit instead
# $env:CMAKE_PREFIX_PATH = "C:/Qt/6.9.2/msvc2019_64"
```

> **Note**: This environment variable only lasts for the current PowerShell session. You'll need to set it again each time you open a new shell.

### Step 7: Build the Project

```powershell
# Clean any previous build attempts
Remove-Item build -Recurse -Force -ErrorAction SilentlyContinue

# Configure the project
cmake -S . -B build -G "Ninja" -DCMAKE_BUILD_TYPE=Release -DCMAKE_PREFIX_PATH=$env:CMAKE_PREFIX_PATH

# Build the project
cmake --build build
```

### Step 8: Run ProShottr

```powershell
# Launch the application
build\bin\ProShottr.exe
```

## 🚀 Quick Build & Run (For Experienced Users)

```powershell
# From a Visual Studio Developer PowerShell
$env:CMAKE_PREFIX_PATH = "C:/Qt/6.9.2/msvc2022_64"
cmake -S . -B build -G "Ninja" -DCMAKE_BUILD_TYPE=Release -DCMAKE_PREFIX_PATH=$env:CMAKE_PREFIX_PATH
cmake --build build
build\bin\ProShottr.exe
```

## 🔧 Troubleshooting

### "Could not find Qt6Config.cmake" Error

This means Qt's MSVC kit isn't installed or CMAKE_PREFIX_PATH is wrong:

1. Open `C:\Qt\MaintenanceTool.exe`
2. Choose **"Add or remove components"**
3. Expand your Qt version (e.g., Qt 6.9.2)
4. Install **"MSVC 2022 64-bit"** or **"MSVC 2019 64-bit"**
5. Update your `CMAKE_PREFIX_PATH` to point to the new `msvc*_64` folder

### Alternative: Set Qt6_DIR Directly

```powershell
$env:Qt6_DIR = "C:/Qt/6.9.2/msvc2022_64/lib/cmake/Qt6"
cmake -S . -B build -G "Ninja" -DCMAKE_BUILD_TYPE=Release
```

### MinGW vs MSVC

If you only have `mingw_64` folders, you need to install the MSVC kit as described above. ProShottr requires MSVC for Windows-specific APIs.

### Missing Developer Shell

If you can't find "Developer PowerShell for VS 2022":
1. Reinstall Visual Studio 2022 with the "Desktop development with C++" workload
2. Or manually run: `"C:\Program Files\Microsoft Visual Studio\2022\Community\Common7\Tools\VsDevCmd.bat"`

### Permission Issues

If you get permission errors:
1. Run the Developer PowerShell as Administrator
2. Or choose a different build directory outside of restricted folders

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