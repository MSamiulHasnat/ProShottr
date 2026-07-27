# Graph Report - ProShottr  (2026-07-26)

## Corpus Check
- 70 files · ~38,337 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 1166 nodes · 1634 edges · 69 communities (56 shown, 13 thin omitted)
- Extraction: 96% EXTRACTED · 4% INFERRED · 0% AMBIGUOUS · INFERRED: 61 edges (avg confidence: 0.82)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `776763f4`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- FRB Generated Dart Bindings
- Product Vision & Design Concepts
- Capture Selection Overlay (Flutter)
- FRB SSE Serialization (Rust)
- Rust Capture & Image API
- Cargokit Android/Target Build
- Cargokit Utilities & Errors
- FRB IO/FFI Codec (Dart)
- Editor Screen Composition
- Quick Capture View UI
- FRB Web/WASM Codec
- Editor Controller State
- Capture Service & Tests
- Cargokit Builder Core
- Cargokit Options/YAML
- Binary Artifacts & Signing
- Build Tool CLI Commands
- Editor Canvas Rendering
- Rust Scene Model
- Windows Flutter Host Window
- Cargokit Environment Config
- Cargokit Platform Build Steps
- Editor Annotation Models
- Windows Capture Window Controller
- Precompiled Binary Publishing
- Rust Capture Dart API
- Native Window Controller (C++)
- Win32 Window Base (C++)
- Annotation Painter
- Win32 Window Scaffolding
- Annotation Object Types
- FRB Rust Wire Layer
- Windows App Entrypoint (C++)
- Cargo Manifest Loading
- Cargokit Pod Build Script
- Flutter App Bootstrap
- Cargokit Logging
- Cargokit Gradle Plugin
- Capture/Editor Widgets (Stateful)
- Editor UI Widgets (Stateless)
- Rust API Dart Facade
- Win32 Message Handling
- RustLib API Interface
- Win32 Message Types
- RustLib Platform Impl
- Custom Painters
- Flutter Plugin Registrant
- WASM JS Interop
- RustLib Wire Base
- Build Tool Entry
- Build Tool Library Main
- Editor Controller Base
- Build Tool Runner Script
- CapturedFrame Optional
- Platform Capabilities
- Size Type
- ClipboardService Trait
- Local-First Principle
- ui/README.md
- capture_service.dart
- installer/README.md

## God Nodes (most connected - your core abstractions)
1. `FlutterWindow` - 39 edges
2. `Win32Window` - 19 edges
3. `String` - 16 edges
4. `GetHandle` - 15 edges
5. `CaptureError` - 14 edges
6. `OnCreate` - 14 edges
7. `MessageHandler` - 12 edges
8. `MessageHandler` - 12 edges
9. `crate::capture::CapturedFrame` - 10 edges
10. `crate::capture::PlatformCapabilities` - 10 edges

## Surprising Connections (you probably didn't know these)
- `EditorController` --semantically_similar_to--> `Annotation scene graph (non-destructive)`  [INFERRED] [semantically similar]
  docs/architecture.md → plan.md
- `Flutter region selector overlay` --semantically_similar_to--> `OverlayHost trait`  [INFERRED] [semantically similar]
  docs/architecture.md → plan.md
- `Flutter Windows runner / native host` --semantically_similar_to--> `HotkeyManager trait`  [INFERRED] [semantically similar]
  docs/architecture.md → plan.md
- `ProShottr (product)` --references--> `ProShottr architecture (implemented)`  [EXTRACTED]
  README.md → docs/architecture.md
- `Windows CI workflow` --conceptually_related_to--> `Windows vertical slice`  [INFERRED]
  .github/workflows/windows-ci.yml → README.md

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **Cross-platform capability layer (OS-seam traits)** — plan_screencapturer, plan_overlayhost, plan_hotkeymanager, plan_textrecognizer, plan_clipboardservice, plan_permissionbroker [EXTRACTED 1.00]
- **Five ScreenCapturer platform backends** — plan_windows_adapter, plan_macos_adapter, plan_x11_adapter, plan_wayland_adapter, plan_android_adapter [EXTRACTED 1.00]
- **Implemented Windows capture data flow** — docs_architecture_windows_runner, docs_architecture_captureservice, docs_architecture_windowscapturer, docs_architecture_region_selector, plan_quick_hud [EXTRACTED 1.00]

## Communities (69 total, 13 thin omitted)

### Community 0 - "FRB Generated Dart Bindings"
Cohesion: 0.03
Nodes (67): ApiImplConstructor, ExternalLibraryLoaderConfig get, frb_generated.io.dart, TaskConstMeta get, apiImplConstructor, codegenVersion, crateApiSimpleCapabilities, crateApiSimpleCaptureDesktop (+59 more)

### Community 1 - "Product Vision & Design Concepts"
Cohesion: 0.05
Nodes (54): ProShottr architecture (implemented), CaptureService (Dart boundary), EditorController, NativeCaptureService, Flutter region selector overlay, scene.rs document model (v1), Flutter Windows runner / native host, WindowsCapturer (Win32 GDI backend) (+46 more)

### Community 2 - "Capture Selection Overlay (Flutter)"
Cohesion: 0.04
Nodes (49): bottom,
  topLeft,
  topRight,
  bottomLeft,, ../editor/annotation_painter.dart, Timer?, adjustsBottom, adjustsLeft, adjustsRight, adjustsTop, bottomRight (+41 more)

### Community 3 - "FRB SSE Serialization (Rust)"
Cohesion: 0.09
Nodes (21): (), bool, crate::capture::CapturedFrame, crate::capture::PlatformCapabilities, f64, i32, Option<String>, CapturedFrame (+13 more)

### Community 4 - "Rust Capture & Image API"
Cohesion: 0.09
Nodes (40): capabilities(), capture_desktop(), crop_frame(), CapturedFrame, Option, PlatformCapabilities, Result, Vec (+32 more)

### Community 5 - "Cargokit Android/Target Build"
Cohesion: 0.04
Nodes (44): dart:convert, dart:isolate, dart:math, dart:typed_data, Digest, File, int?, package:collection/collection.dart (+36 more)

### Community 6 - "Cargokit Utilities & Errors"
Cohesion: 0.04
Nodes (45): Encoding?, Exception, List, Map, ProcessResult, BuildException, SourceSpanException, _didInstallRustSrcForNightly (+37 more)

### Community 7 - "FRB IO/FFI Codec (Dart)"
Cohesion: 0.04
Nodes (44): api/simple.dart, dart:async, dart:ffi, package:flutter_rust_bridge/flutter_rust_bridge_for_generated_io.dart, dco_decode_bool, dco_decode_box_autoadd_captured_frame, dco_decode_captured_frame, dco_decode_f_64 (+36 more)

### Community 8 - "Editor Screen Composition"
Cohesion: 0.04
Nodes (44): ../capture/capture_selection_overlay.dart, ../capture/quick_capture_view.dart, editor_canvas.dart, package:flutter/rendering.dart, package:super_clipboard/super_clipboard.dart, ../../services/capture_service.dart, ../../services/windows_capture_window.dart, build (+36 more)

### Community 9 - "Quick Capture View UI"
Cohesion: 0.04
Nodes (44): ../editor/editor_canvas.dart, ../editor/editor_controller.dart, ../editor/editor_models.dart, build, _buildColors, _buildQuickHud, _buildStickerControl, _buildStrokeWidths (+36 more)

### Community 10 - "FRB Web/WASM Codec"
Cohesion: 0.05
Nodes (43): _, external RustLibWasmModule get, package:flutter_rust_bridge/flutter_rust_bridge_for_generated_web.dart, dco_decode_bool, dco_decode_box_autoadd_captured_frame, dco_decode_captured_frame, dco_decode_f_64, dco_decode_i_32 (+35 more)

### Community 11 - "Editor Controller State"
Cohesion: 0.05
Nodes (37): AnnotationObject? get, AnnotationStyle get, Color get, dart:collection, double get, EditorTool get, package:flutter/foundation.dart, addSticker (+29 more)

### Community 12 - "Capture Service & Tests"
Cohesion: 0.08
Nodes (23): IconButton, package:flutter/gestures.dart, package:proshottr/features/editor/editor_screen.dart, package:proshottr/services/capture_service.dart, package:proshottr/services/windows_capture_window.dart, capabilities, captureCount, captureDesktop (+15 more)

### Community 13 - "Cargokit Builder Core"
Cohesion: 0.07
Nodes (28): bool get, CargoBuildOptions? get, androidMinSdkVersion, androidNdkVersion, androidSdkPath, build, BuildConfiguration, _buildOptions (+20 more)

### Community 14 - "Cargokit Options/YAML"
Cohesion: 0.07
Nodes (27): package:source_span/source_span.dart, package:yaml/yaml.dart, PublicKey, SourceSpan?, SourceSpan? get, String get, Toolchain, cargo (+19 more)

### Community 15 - "Binary Artifacts & Signing"
Cohesion: 0.09
Nodes (24): cargo.dart, crate_hash.dart, package:ed25519_edwards/ed25519_edwards.dart, package:http/http.dart, precompile_binaries.dart, rustup.dart, AritifactType, Artifact (+16 more)

### Community 16 - "Build Tool CLI Commands"
Cohesion: 0.11
Nodes (23): android_environment.dart, build_cmake.dart, build_gradle.dart, build_pod.dart, Command, logging.dart, package:args/command_runner.dart, package:github/github.dart (+15 more)

### Community 17 - "Editor Canvas Rendering"
Cohesion: 0.08
Nodes (25): annotation_painter.dart, ChangeNotifier, EdgeInsetsGeometry, editor_controller.dart, GlobalKey, _activePointer, backgroundColor, build (+17 more)

### Community 18 - "Rust Scene Model"
Cohesion: 0.18
Nodes (15): Annotation, new_edit_clears_redo_history(), Point, Rect, rectangle(), RgbaColor, Error, Result (+7 more)

### Community 19 - "Windows Flutter Host Window"
Cohesion: 0.08
Nodes (25): FlutterViewController, LONG_PTR, MethodChannel, FlutterWindow, capture_overlay_active_, capture_window_channel_, editor_extended_style_, editor_placement_ (+17 more)

### Community 20 - "Cargokit Environment Config"
Cohesion: 0.09
Nodes (22): static bool get, static List, static String get, configuration, darwinArchs, darwinPlatformName, Environment, _getEnv (+14 more)

### Community 21 - "Cargokit Platform Build Steps"
Cohesion: 0.14
Nodes (18): artifacts_provider.dart, builder.dart, environment.dart, options.dart, package:logging/logging.dart, target.dart, build, BuildCMake (+10 more)

### Community 22 - "Editor Annotation Models"
Cohesion: 0.10
Nodes (19): Color, dart:ui, AnnotationStyle, blockSize, bounds, center, color, copyWith (+11 more)

### Community 23 - "Windows Capture Window Controller"
Cohesion: 0.11
Nodes (17): package:flutter/services.dart, static const, bottom, _channel, _installMethodHandler, left, prepareCapture, restoreEditor (+9 more)

### Community 24 - "Precompiled Binary Publishing"
Cohesion: 0.11
Nodes (18): PrivateKey, RepositorySlug, androidMinSdkVersion, androidNdkVersion, androidSdkLocation, fileName, _getOrCreateRelease, githubToken (+10 more)

### Community 25 - "Rust Capture Dart API"
Cohesion: 0.11
Nodes (17): int get, CapturedFrame, desktopCapture, globalHotkey, hashCode, height, operator, originX (+9 more)

### Community 26 - "Native Window Controller (C++)"
Cohesion: 0.21
Nodes (21): LONG, EncodableValue, HWND, LPARAM, LRESULT, UINT, WPARAM, ExitApplication (+13 more)

### Community 27 - "Win32 Window Base (C++)"
Cohesion: 0.11
Nodes (25): RECT, Size, wchar_t, HWND, Scale(), Win32Window, child_content_, Create (+17 more)

### Community 28 - "Annotation Painter"
Cohesion: 0.12
Nodes (15): ByteData?, editor_models.dart, Offset, annotations, draft, imagePixels, imageSize, paint (+7 more)

### Community 29 - "Win32 Window Scaffolding"
Cohesion: 0.67
Nodes (3): CaptureWindowController, WindowsCaptureWindowController, _FakeCaptureWindowController

### Community 30 - "Annotation Object Types"
Cohesion: 0.18
Nodes (12): package:flutter_test/flutter_test.dart, package:proshottr/features/editor/editor_controller.dart, package:proshottr/features/editor/editor_models.dart, AnnotationObject, ArrowAnnotation, EllipseAnnotation, MosaicAnnotation, PenAnnotation (+4 more)

### Community 31 - "FRB Rust Wire Layer"
Cohesion: 0.45
Nodes (11): pde_ffi_dispatcher_primary_impl(), pde_ffi_dispatcher_sync_impl(), wire__crate__api__simple__capabilities_impl(), wire__crate__api__simple__capture_desktop_impl(), wire__crate__api__simple__crop_frame_impl(), wire__crate__api__simple__init_app_impl(), wire__crate__api__simple__save_png_as_impl(), wire__crate__api__simple__save_png_impl() (+3 more)

### Community 32 - "Windows App Entrypoint (C++)"
Cohesion: 0.24
Nodes (9): _In_, _In_opt_, wWinMain(), string, wchar_t, CreateAndAttachConsole(), GetCommandLineArguments(), Utf8FromUtf16() (+1 more)

### Community 33 - "Cargo Manifest Loading"
Cohesion: 0.18
Nodes (10): package:path/path.dart, package:toml/toml.dart, CrateInfo, fileName, load, ManifestException, message, packageName (+2 more)

### Community 34 - "Cargokit Pod Build Script"
Cohesion: 0.18
Nodes (10): CARGOKIT_CONFIGURATION, CARGOKIT_DARWIN_ARCHS, CARGOKIT_DARWIN_PLATFORM_NAME, CARGOKIT_MANIFEST_DIR, CARGOKIT_OUTPUT_DIR, CARGOKIT_ROOT_PROJECT_DIR, CARGOKIT_TARGET_TEMP_DIR, CARGOKIT_TOOL_TEMP_DIR (+2 more)

### Community 35 - "Flutter App Bootstrap"
Cohesion: 0.20
Nodes (8): app.dart, features/editor/editor_screen.dart, package:flutter/material.dart, src/rust/frb_generated.dart, build, ProShottrApp, init, main

### Community 36 - "Cargokit Logging"
Cohesion: 0.20
Nodes (9): dart:io, enableVerboseLogging, initLogging, kDoubleSeparator, kSeparator, _lastMessageWasSeparator, _log, out (+1 more)

### Community 37 - "Cargokit Gradle Plugin"
Cohesion: 0.22
Nodes (6): DefaultTask, Plugin, Project, CargoKitBuildTask, CargoKitExtension, CargoKitPlugin

### Community 38 - "Capture/Editor Widgets (Stateful)"
Cohesion: 0.27
Nodes (10): State, StatefulWidget, QuickCaptureView, _QuickCaptureViewState, _StickerPickerDialog, _StickerPickerDialogState, EditorCanvas, _EditorCanvasState (+2 more)

### Community 39 - "Editor UI Widgets (Stateless)"
Cohesion: 0.20
Nodes (10): StatelessWidget, _SelectionHint, _DimensionLabel, _PresetButton, _StickerButton, _EmptyWorkspace, _Inspector, _StatusBar (+2 more)

### Community 40 - "Rust API Dart Facade"
Cohesion: 0.22
Nodes (8): capture.dart, frb_generated.dart, package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart, capabilities, captureDesktop, cropFrame, savePng, savePngAs

### Community 41 - "Win32 Message Handling"
Cohesion: 0.42
Nodes (9): HWND, LPARAM, LRESULT, UINT, WPARAM, EnableFullDpiSupportIfAvailable(), GetThisFromHandle, MessageHandler (+1 more)

### Community 42 - "RustLib API Interface"
Cohesion: 0.40
Nodes (6): BaseApi, BaseEntrypoint, RustLibApiImplPlatform, RustLib, RustLibApi, RustLibApiImpl

### Community 44 - "RustLib Platform Impl"
Cohesion: 0.67
Nodes (4): BaseApiImpl, RustLibWire, RustLibApiImplPlatform, RustLibApiImplPlatform

### Community 45 - "Custom Painters"
Cohesion: 0.50
Nodes (4): CustomPainter, _SelectionPainter, _FrozenSelectionPainter, AnnotationPainter

### Community 47 - "WASM JS Interop"
Cohesion: 0.67
Nodes (3): @anonymous, @JS, RustLibWasmModule

### Community 48 - "RustLib Wire Base"
Cohesion: 0.67
Nodes (3): BaseWire, RustLibWire, RustLibWire

### Community 68 - "capture_service.dart"
Cohesion: 0.20
Nodes (10): package:proshottr/src/rust/api/simple.dart, package:proshottr/src/rust/capture.dart, capabilities, captureDesktop, CaptureService, cropFrame, NativeCaptureService, savePng (+2 more)

## Knowledge Gaps
- **642 isolated node(s):** `build`, `_DragMode`, `frame`, `controller`, `windowController` (+637 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **13 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `String` connect `Rust Capture & Image API` to `Rust Scene Model`, `FRB SSE Serialization (Rust)`?**
  _High betweenness centrality (0.127) - this node is a cross-community bridge._
- **Why does `EditorController` connect `Editor Canvas Rendering` to `Editor Screen Composition`, `Quick Capture View UI`, `Capture Selection Overlay (Flutter)`, `Editor Controller State`?**
  _High betweenness centrality (0.023) - this node is a cross-community bridge._
- **Why does `Annotation` connect `Rust Scene Model` to `Rust Capture & Image API`?**
  _High betweenness centrality (0.023) - this node is a cross-community bridge._
- **Are the 12 inferred relationships involving `GetHandle` (e.g. with `ExitApplication` and `HideEditorWindow`) actually correct?**
  _`GetHandle` has 12 INFERRED edges - model-reasoned connections that need verification._
- **What connects `build`, `_DragMode`, `frame` to the rest of the system?**
  _642 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `FRB Generated Dart Bindings` be split into smaller, more focused modules?**
  _Cohesion score 0.029411764705882353 - nodes in this community are weakly interconnected._
- **Should `Product Vision & Design Concepts` be split into smaller, more focused modules?**
  _Cohesion score 0.05450733752620545 - nodes in this community are weakly interconnected._