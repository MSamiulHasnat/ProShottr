# ProShottr

ProShottr is a local-first screenshot capture and annotation app inspired by WeChat's fast share flow and Shottr's precision tools. Development is following [plan.md](plan.md), with Windows as the first supported platform.

## Current Windows slice

The runnable Windows vertical slice now includes:

- Native capture of the complete Windows virtual desktop, including multi-monitor bounds.
- A real process-wide `Alt+Shift+S` capture hotkey and native capture-session window handling.
- A Windows tray icon with Show/Exit actions, close-to-tray behavior, and single-instance Start Menu reuse.
- A frozen, borderless, top-most region selector with live `LOC`/`HEX` sampling, dimensions, move, and eight resize handles.
- A WeChat-style Quick HUD with filled rectangle, outline ellipse, categorized/recent stickers, arrow, brush, manual mosaic, and text tools.
- The verified six-color palette, three stroke presets, three text-size presets, and undo/redo.
- Non-destructive annotations and pixelated mosaic preview over the original source image.
- Done-to-clipboard and native Save As export with a timestamp-based PNG filename and Desktop default.
- A one-click transition from the Quick HUD into the full Pro editor.
- A Rust capability boundary, serializable scene document, and Flutter/Rust FFI bridge.
- Rust unit tests plus Flutter controller and capture-workflow widget tests.

The current capture backend deliberately starts with GDI/`BitBlt` as the compatibility path. Top-level window hover detection is now included; Windows Graphics Capture, child/UI edge detection, AI-assisted masking, and pin-to-screen are the next Windows milestones.

Closing the editor window hides ProShottr to the Windows notification area instead of exiting. Double-click the tray icon or choose **Show ProShottr** to reopen it; **Exit ProShottr** shuts down the process. Starting ProShottr again from the Start Menu reuses the existing process and shows the editor.

## Install on Windows

The Windows release is distributed as `ProShottr-Setup-0.1.0.exe`. It installs per-user, adds ProShottr to the Start Menu, and includes an optional desktop shortcut. Build the installer with the instructions in [installer/README.md](installer/README.md).

## Repository layout

```text
core/                 Rust core, platform contracts, Windows capture, scene model
ui/                   Flutter desktop UI and generated Rust bridge
docs/architecture.md  Current architecture and near-term boundaries
feature.md             Product feature source of truth
plan.md                Cross-platform implementation roadmap
```

## Windows development

Prerequisites:

- Windows 10 or 11
- Flutter stable with Windows desktop support
- Rust stable with the MSVC target
- Visual Studio with Desktop development with C++ and a Windows SDK
- `flutter_rust_bridge_codegen` and `cargo-expand` when changing the Rust API

```powershell
cargo install flutter_rust_bridge_codegen cargo-expand

cd ui
flutter pub get
flutter_rust_bridge_codegen generate
flutter run -d windows
```

Validation:

```powershell
cargo test --manifest-path core/Cargo.toml --all-targets

cd ui
flutter analyze
flutter test
flutter build windows --debug
```

On Windows hosts where Cargokit cannot resolve Flutter's hidden `AppData` package cache, point `PUB_CACHE` at a non-hidden directory before `flutter pub get` and build:

```powershell
$env:PUB_CACHE = 'C:\dev-cache\proshottr-pub'
```

## Keyboard shortcuts

| Shortcut | Action |
|---|---|
| `Alt+Shift+S` | Start capture globally while ProShottr is running |
| `Ctrl+Z` / `Ctrl+Y` | Undo / redo |
| `Ctrl+C` | Copy composited image |
| `Ctrl+S` | Open Save As for the composited PNG |
| `Enter` | Confirm a region selection |
| `Esc` | Cancel capture; clear markup in the Pro editor |

ProShottr is licensed under the [MIT License](LICENSE).
