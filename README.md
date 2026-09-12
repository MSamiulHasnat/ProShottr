# ProShottr

ProShottr is a local-first screenshot capture and annotation app inspired by WeChat's fast share flow and Shottr's precision tools. Development is following [plan.md](plan.md), with Windows as the first supported platform.

## Current Windows slice

The runnable Windows vertical slice now includes:

- Native capture of the complete Windows virtual desktop, including multi-monitor bounds.
- A real process-wide `Alt+Shift+S` capture hotkey and native capture-session window handling.
- A Windows tray icon with Show/Exit actions, close-to-tray behavior, and single-instance Start Menu reuse.
- A frozen, borderless, top-most region selector with live `LOC`/`HEX`/`RGB` sampling, color-copy shortcuts, dimensions, move, and eight resize handles.
- A WeChat-style Quick HUD with filled rectangle, outline ellipse, categorized/recent stickers, arrow, brush, manual mosaic, and text tools.
- The verified six-color palette, three stroke presets, three text-size presets, and undo/redo.
- Non-destructive annotations and pixelated mosaic preview over the original source image.
- Done-to-clipboard and native Save As export with a timestamp-based PNG filename and Desktop default.
- A one-click transition from the Quick HUD into the full Pro editor.
- A four-group Quick HUD with a narrow-selection overflow menu, expanded sticker picker, and explicit explanations for unavailable content tools.
- Native movable, always-on-top image pins, with scroll resizing and collapse/close controls.
- An overlay-owned Save As dialog that preserves the capture, plus a local share chooser for copying or saving.
- A non-destructive crop tool with undo, redo, and reset in the Quick HUD and the Pro editor; every export is exactly the crop's physical pixels.
- Per-monitor DPI metadata from the Windows capture, so the probe box, size label, and resolution badge report the scale of the display they are on.
- A Rust capability boundary, serializable scene document, and Flutter/Rust FFI bridge.
- Rust unit tests plus Flutter controller and capture-workflow widget tests.

The capture backend uses GDI/`BitBlt` as the compatibility path. Top-level window detection uses DWM visible bounds. OCR, translation, scrolling capture, and AI-assisted masking remain unavailable and their controls explain that state. Windows Graphics Capture, child/UI detection, and the other platform adapters remain roadmap work.

The latest source implements the overlay/windowing specs in `plan.md` §§8.8–8.10 plus the crop tool and per-monitor DPI metadata. Flutter 3.47.3 analysis is clean and all 37 behavioral tests pass; the Rust core's 10 tests, `cargo fmt`, and `cargo clippy -D warnings` pass when built for the `x86_64-pc-windows-gnu` target with MSYS2's MinGW-w64, because the validation host lacks Visual Studio C++ Build Tools and Developer Mode for plugin symlinks. With Visual Studio 2022 Build Tools installed, `flutter build windows --release` compiles the native runner and the Rust core, and the installer in `dist/` was rebuilt from this source. The manual desktop acceptance checks have not been run yet. See [Windows QA](docs/windows-qa.md).

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
- Windows Developer Mode (Flutter desktop plugins require symlink support)
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

Without Visual Studio, the Rust core can still be tested with MSYS2's UCRT64 MinGW-w64 on `PATH` (the `dart-sys` build script needs a C compiler), after `rustup target add x86_64-pc-windows-gnu`:

```powershell
cargo test --manifest-path core/Cargo.toml --all-targets --target x86_64-pc-windows-gnu
```

The Flutter Windows build itself still requires Visual Studio. Changing the Rust API also requires `cargo-expand` for `flutter_rust_bridge_codegen generate`.

## Keyboard shortcuts

| Shortcut | Action |
|---|---|
| `Alt+Shift+S` | Start capture globally while ProShottr is running |
| `Ctrl+Z` / `Ctrl+Y` | Undo / redo |
| `Ctrl+Shift+Z` | Redo |
| `Ctrl+C` | Copy composited image |
| `Ctrl+S` | Open Save As for the composited PNG |
| `C` / `Shift+C` | Copy HEX / RGB from the selection probe and dismiss |
| `R` / `E` / `A` / `P` / `T` / `M` / `S` | Rectangle / ellipse / arrow / brush / text / mosaic / sticker in Quick capture |
| `C` / `Shift+C` | Crop tool / reset the crop in Quick capture |
| `Ctrl+P` / `Ctrl+Enter` | Pin / share chooser in Quick capture |
| `Tab` | Open Pro editor from Quick capture |
| `Enter` | Confirm a region selection; copy and finish Quick capture |
| `Esc` | Cancel capture; clear markup in the Pro editor |

ProShottr is licensed under the [MIT License](LICENSE).
