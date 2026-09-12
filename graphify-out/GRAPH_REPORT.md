# Graph Report - ProShottr  (2026-09-11)

## Corpus Check
- 77 files · ~55,402 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 1451 nodes · 2058 edges · 73 communities (51 shown, 14 thin omitted)
- Extraction: 96% EXTRACTED · 4% INFERRED · 0% AMBIGUOUS · INFERRED: 78 edges (avg confidence: 0.85)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `2dafd658`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- frb_generated.dart
- Product Vision & Design Concepts
- capture_selection_overlay.dart
- Self
- capture/mod.rs
- Cargokit Android/Target Build
- util.dart
- frb_generated.io.dart
- editor_screen.dart
- quick_capture_view.dart
- _
- editor_controller.dart
- Capture Service & Tests
- Cargokit Builder Core
- Cargokit Options/YAML
- Binary Artifacts & Signing
- Build Tool CLI Commands
- editor_canvas.dart
- scene.rs
- Windows Flutter Host Window
- Cargokit Environment Config
- Cargokit Platform Build Steps
- editor_models.dart
- Windows Capture Window Controller
- Precompiled Binary Publishing
- capture.dart
- Native Window Controller (C++)
- Win32 Window Base (C++)
- Annotation Painter
- Win32 Window Scaffolding
- editor_controller_test.dart
- capture_selection_overlay_test.dart
- Windows App Entrypoint (C++)
- Cargo Manifest Loading
- Cargokit Pod Build Script
- quick_capture_view_test.dart
- Cargokit Logging
- Cargokit Gradle Plugin
- State
- Editor UI Widgets (Stateless)
- Rust API Dart Facade
- Win32 Message Handling
- RustLib API Interface
- rustup.dart
- RustLib Platform Impl
- CustomPainter
- Flutter Plugin Registrant
- WASM JS Interop
- RustLib Wire Base
- Build Tool Entry
- Build Tool Library Main
- Editor Controller Base
- flutter_window.h
- Build Tool Runner Script
- CapturedFrame Optional
- Platform Capabilities
- Size Type
- ClipboardService Trait
- Local-First Principle
- ui/README.md
- capture_service.dart
- installer/README.md
- proshottr_core
- package:flutter/material.dart
- EditorController

## God Nodes (most connected - your core abstractions)
1. `_` - 58 edges
2. `FlutterWindow` - 55 edges
3. `ImagePinWindow` - 24 edges
4. `Win32Window` - 21 edges
5. `CaptureError` - 16 edges
6. `OnCreate` - 16 edges
7. `GetHandle` - 16 edges
8. `MessageHandler` - 14 edges
9. `()` - 12 edges
10. `SceneDocument` - 12 edges

## Surprising Connections (you probably didn't know these)
- `EditorController` --semantically_similar_to--> `Annotation scene graph (non-destructive)`  [INFERRED] [semantically similar]
  docs/architecture.md → plan.md
- `Flutter region selector overlay` --semantically_similar_to--> `OverlayHost trait`  [INFERRED] [semantically similar]
  docs/architecture.md → plan.md
- `Flutter Windows runner / native host` --semantically_similar_to--> `HotkeyManager trait`  [INFERRED] [semantically similar]
  docs/architecture.md → plan.md
- `Windows CI workflow` --conceptually_related_to--> `Windows vertical slice`  [INFERRED]
  .github/workflows/windows-ci.yml → README.md
- `Windows CI workflow` --references--> `proshottr Flutter app package`  [INFERRED]
  .github/workflows/windows-ci.yml → ui/pubspec.yaml

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **Cross-platform capability layer (OS-seam traits)** — plan_screencapturer, plan_overlayhost, plan_hotkeymanager, plan_textrecognizer, plan_clipboardservice, plan_permissionbroker [EXTRACTED 1.00]
- **Five ScreenCapturer platform backends** — plan_windows_adapter, plan_macos_adapter, plan_x11_adapter, plan_wayland_adapter, plan_android_adapter [EXTRACTED 1.00]
- **Implemented Windows capture data flow** — docs_architecture_windows_runner, docs_architecture_captureservice, docs_architecture_windowscapturer, docs_architecture_region_selector, plan_quick_hud [EXTRACTED 1.00]

## Communities (73 total, 14 thin omitted)

### Community 0 - "frb_generated.dart"
Cohesion: 0.03
Nodes (73): ApiImplConstructor, ExternalLibraryLoaderConfig get, frb_generated.io.dart, TaskConstMeta get, apiImplConstructor, codegenVersion, crateApiSimpleCapabilities, crateApiSimpleCaptureDesktop (+65 more)

### Community 1 - "Product Vision & Design Concepts"
Cohesion: 0.05
Nodes (55): ProShottr architecture (implemented), CaptureService (Dart boundary), EditorController, NativeCaptureService, Flutter region selector overlay, scene.rs document model (v1), Flutter Windows runner / native host, WindowsCapturer (Win32 GDI backend) (+47 more)

### Community 2 - "capture_selection_overlay.dart"
Cohesion: 0.03
Nodes (69): bottom,
  topLeft,
  topRight,
  bottomLeft,, ../editor/annotation_painter.dart, Timer?, adjustsBottom, adjustsLeft, adjustsRight, adjustsTop, alpha (+61 more)

### Community 3 - "Self"
Cohesion: 0.07
Nodes (35): (), bool, crate::capture::CapturedFrame, crate::capture::DisplayInfo, crate::capture::PlatformCapabilities, f64, i32, Option<String> (+27 more)

### Community 4 - "capture/mod.rs"
Cohesion: 0.11
Nodes (37): capture_desktop(), CapturedFrame, CaptureError, crop_frame(), cropping_onto_another_display_resolves_that_display_scale(), crops_a_frame_and_updates_its_origin(), display(), DisplayInfo (+29 more)

### Community 5 - "Cargokit Android/Target Build"
Cohesion: 0.04
Nodes (44): dart:convert, dart:isolate, dart:math, dart:typed_data, Digest, File, int?, package:collection/collection.dart (+36 more)

### Community 6 - "util.dart"
Cohesion: 0.07
Nodes (29): Encoding?, Exception, Map, ProcessResult, BuildException, SourceSpanException, arguments, CommandFailedException (+21 more)

### Community 7 - "frb_generated.io.dart"
Cohesion: 0.04
Nodes (49): api/simple.dart, dart:ffi, package:flutter_rust_bridge/flutter_rust_bridge_for_generated_io.dart, dco_decode_bool, dco_decode_box_autoadd_captured_frame, dco_decode_captured_frame, dco_decode_display_info, dco_decode_f_64 (+41 more)

### Community 8 - "editor_screen.dart"
Cohesion: 0.04
Nodes (56): ../capture/capture_selection_overlay.dart, ../capture/quick_capture_view.dart, editor_canvas.dart, package:flutter/rendering.dart, ../../services/capture_output_service.dart, ../../services/capture_service.dart, ../../services/windows_capture_window.dart, build (+48 more)

### Community 9 - "quick_capture_view.dart"
Cohesion: 0.03
Nodes (69): ../editor/editor_canvas.dart, ../editor/editor_controller.dart, ../editor/editor_models.dart, IconData, _actionButton, bounds, build, _buildColors (+61 more)

### Community 10 - "_"
Cohesion: 0.04
Nodes (49): external RustLibWasmModule get, package:flutter_rust_bridge/flutter_rust_bridge_for_generated_web.dart, _, dco_decode_bool, dco_decode_box_autoadd_captured_frame, dco_decode_captured_frame, dco_decode_display_info, dco_decode_f_64 (+41 more)

### Community 11 - "editor_controller.dart"
Cohesion: 0.04
Nodes (51): AnnotationObject? get, AnnotationStyle get, Color get, dart:collection, double get, EditorTool get, package:flutter/foundation.dart, _SceneState get (+43 more)

### Community 12 - "Capture Service & Tests"
Cohesion: 0.04
Nodes (46): Future, Object?, package:proshottr/features/editor/editor_screen.dart, package:proshottr/services/capture_output_service.dart, package:proshottr/services/capture_service.dart, called, capabilities, captureCount (+38 more)

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

### Community 17 - "editor_canvas.dart"
Cohesion: 0.06
Nodes (32): annotation_painter.dart, EdgeInsetsGeometry, editor_controller.dart, GlobalKey, Image?, Rect? get, _activePointer, backgroundColor (+24 more)

### Community 18 - "scene.rs"
Cohesion: 0.16
Nodes (18): Annotation, crop_is_an_undoable_document_step_that_sets_the_export_size(), documents_without_a_crop_still_load(), new_edit_clears_redo_history(), Point, Rect, rectangle(), RgbaColor (+10 more)

### Community 19 - "Windows Flutter Host Window"
Cohesion: 0.06
Nodes (35): DWORD, FlutterViewController, LONG_PTR, MethodChannel, FlutterWindow, active_save_dialog_, capture_overlay_active_, capture_request_pending_ (+27 more)

### Community 20 - "Cargokit Environment Config"
Cohesion: 0.09
Nodes (22): static bool get, static List, static String get, configuration, darwinArchs, darwinPlatformName, Environment, _getEnv (+14 more)

### Community 21 - "Cargokit Platform Build Steps"
Cohesion: 0.14
Nodes (18): artifacts_provider.dart, builder.dart, environment.dart, options.dart, package:logging/logging.dart, target.dart, build, BuildCMake (+10 more)

### Community 22 - "editor_models.dart"
Cohesion: 0.09
Nodes (26): Color, dart:ui, AnnotationObject, AnnotationStyle, ArrowAnnotation, blockSize, bounds, center (+18 more)

### Community 23 - "Windows Capture Window Controller"
Cohesion: 0.11
Nodes (19): bottom, CaptureWindowController, _channel, _installMethodHandler, left, prepareCapture, restoreEditor, right (+11 more)

### Community 24 - "Precompiled Binary Publishing"
Cohesion: 0.11
Nodes (18): PrivateKey, RepositorySlug, androidMinSdkVersion, androidNdkVersion, androidSdkLocation, fileName, _getOrCreateRelease, githubToken (+10 more)

### Community 25 - "capture.dart"
Cohesion: 0.07
Nodes (32): capabilities(), capture_desktop(), crop_frame(), CapturedFrame, Option, PlatformCapabilities, Result, Vec (+24 more)

### Community 26 - "Native Window Controller (C++)"
Cohesion: 0.22
Nodes (14): DartProject, HWND, LPARAM, LRESULT, UINT, WPARAM, ExitApplication, FlutterWindow::FlutterWindow() (+6 more)

### Community 27 - "Win32 Window Base (C++)"
Cohesion: 0.08
Nodes (40): HWND, LPARAM, LRESULT, Point, RECT, UINT, wchar_t, WPARAM (+32 more)

### Community 28 - "Annotation Painter"
Cohesion: 0.12
Nodes (15): ByteData?, editor_models.dart, Offset, annotations, draft, imagePixels, imageSize, paint (+7 more)

### Community 29 - "Win32 Window Scaffolding"
Cohesion: 0.12
Nodes (30): HWND, LPARAM, LRESULT, POINT, string, UINT, unique_ptr, vector (+22 more)

### Community 30 - "editor_controller_test.dart"
Cohesion: 0.33
Nodes (5): package:flutter_test/flutter_test.dart, package:proshottr/features/editor/editor_controller.dart, package:proshottr/features/editor/editor_models.dart, TextAnnotation, main

### Community 31 - "capture_selection_overlay_test.dart"
Cohesion: 0.06
Nodes (32): CustomPaint, dart:async, MouseRegion, package:flutter/gestures.dart, package:proshottr/features/capture/capture_selection_overlay.dart, package:proshottr/services/windows_capture_window.dart, return, _backWindow (+24 more)

### Community 32 - "Windows App Entrypoint (C++)"
Cohesion: 0.27
Nodes (9): _In_, _In_opt_, wWinMain(), string, vector, wchar_t, CreateAndAttachConsole(), GetCommandLineArguments() (+1 more)

### Community 33 - "Cargo Manifest Loading"
Cohesion: 0.18
Nodes (10): package:path/path.dart, package:toml/toml.dart, CrateInfo, fileName, load, ManifestException, message, packageName (+2 more)

### Community 34 - "Cargokit Pod Build Script"
Cohesion: 0.18
Nodes (10): CARGOKIT_CONFIGURATION, CARGOKIT_DARWIN_ARCHS, CARGOKIT_DARWIN_PLATFORM_NAME, CARGOKIT_MANIFEST_DIR, CARGOKIT_OUTPUT_DIR, CARGOKIT_ROOT_PROJECT_DIR, CARGOKIT_TARGET_TEMP_DIR, CARGOKIT_TOOL_TEMP_DIR (+2 more)

### Community 35 - "quick_capture_view_test.dart"
Cohesion: 0.06
Nodes (31): IgnorePointer, Opacity, package:proshottr/features/capture/quick_capture_view.dart, required EditorController controller,
  Size, Switch, canvas, cards, crop (+23 more)

### Community 36 - "Cargokit Logging"
Cohesion: 0.20
Nodes (9): dart:io, enableVerboseLogging, initLogging, kDoubleSeparator, kSeparator, _lastMessageWasSeparator, _log, out (+1 more)

### Community 37 - "Cargokit Gradle Plugin"
Cohesion: 0.22
Nodes (6): DefaultTask, Plugin, Project, CargoKitBuildTask, CargoKitExtension, CargoKitPlugin

### Community 38 - "State"
Cohesion: 0.27
Nodes (10): State, StatefulWidget, CaptureSelectionOverlay, _CaptureSelectionOverlayState, QuickCaptureView, _QuickCaptureViewState, _StickerPickerDialog, _StickerPickerDialogState (+2 more)

### Community 39 - "Editor UI Widgets (Stateless)"
Cohesion: 0.20
Nodes (10): StatelessWidget, _SelectionHint, _DimensionLabel, _PresetButton, _StickerButton, _EmptyWorkspace, _Inspector, _StatusBar (+2 more)

### Community 40 - "Rust API Dart Facade"
Cohesion: 0.22
Nodes (8): capture.dart, frb_generated.dart, package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart, capabilities, captureDesktop, cropFrame, savePng, savePngAs

### Community 41 - "Win32 Message Handling"
Cohesion: 0.24
Nodes (14): LONG, MethodResult, EncodableValue, vector, InstallTrayIcon, OnCreate, OnDestroy, PrepareCaptureWindow (+6 more)

### Community 42 - "RustLib API Interface"
Cohesion: 0.40
Nodes (6): BaseApi, BaseEntrypoint, RustLibApiImplPlatform, RustLib, RustLibApi, RustLibApiImpl

### Community 43 - "rustup.dart"
Cohesion: 0.12
Nodes (16): List, _didInstallRustSrcForNightly, _didInstallZigBuild, executablePath, _getInstalledTargets, _getInstalledToolchains, installedTargets, _installedToolchains (+8 more)

### Community 44 - "RustLib Platform Impl"
Cohesion: 0.67
Nodes (4): BaseApiImpl, RustLibWire, RustLibApiImplPlatform, RustLibApiImplPlatform

### Community 45 - "CustomPainter"
Cohesion: 0.40
Nodes (5): CustomPainter, _SelectionPainter, _FrozenSelectionPainter, AnnotationPainter, _CropPainter

### Community 47 - "WASM JS Interop"
Cohesion: 0.67
Nodes (3): @anonymous, @JS, RustLibWasmModule

### Community 48 - "RustLib Wire Base"
Cohesion: 0.67
Nodes (3): BaseWire, RustLibWire, RustLibWire

### Community 51 - "Editor Controller Base"
Cohesion: 0.20
Nodes (10): package:flutter/services.dart, package:super_clipboard/super_clipboard.dart, static const, CaptureOutputService, _channel, copyPng, pinPng, savePngAs (+2 more)

### Community 68 - "capture_service.dart"
Cohesion: 0.20
Nodes (10): package:proshottr/src/rust/api/simple.dart, package:proshottr/src/rust/capture.dart, capabilities, captureDesktop, CaptureService, cropFrame, NativeCaptureService, savePng (+2 more)

### Community 71 - "package:flutter/material.dart"
Cohesion: 0.20
Nodes (8): app.dart, features/editor/editor_screen.dart, package:flutter/material.dart, src/rust/frb_generated.dart, build, ProShottrApp, init, main

## Knowledge Gaps
- **838 isolated node(s):** `proshottr_core`, `build`, `_PixelSample`, `_DragMode`, `frame` (+833 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 993 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **14 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `String` connect `capture/mod.rs` to `capture.dart`, `scene.rs`, `Self`?**
  _High betweenness centrality (0.111) - this node is a cross-community bridge._
- **Why does `_` connect `_` to `Cargokit Android/Target Build`, `frb_generated.io.dart`, `Rust API Dart Facade`, `RustLib Platform Impl`, `WASM JS Interop`, `RustLib Wire Base`, `capture_selection_overlay_test.dart`?**
  _High betweenness centrality (0.076) - this node is a cross-community bridge._
- **What connects `proshottr_core`, `build`, `_PixelSample` to the rest of the system?**
  _838 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `frb_generated.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.02702702702702703 - nodes in this community are weakly interconnected._
- **Should `Product Vision & Design Concepts` be split into smaller, more focused modules?**
  _Cohesion score 0.052597402597402594 - nodes in this community are weakly interconnected._
- **Should `capture_selection_overlay.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.02857142857142857 - nodes in this community are weakly interconnected._
- **Should `Self` be split into smaller, more focused modules?**
  _Cohesion score 0.07372229760289462 - nodes in this community are weakly interconnected._
