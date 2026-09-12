import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proshottr/features/editor/editor_models.dart';
import 'package:proshottr/features/editor/editor_screen.dart';
import 'package:proshottr/features/capture/quick_capture_view.dart';
import 'package:proshottr/services/capture_output_service.dart';
import 'package:proshottr/services/capture_service.dart';
import 'package:proshottr/services/windows_capture_window.dart';
import 'package:proshottr/src/rust/capture.dart';

late Uint8List _capturePng;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawColor(const Color(0xFF3A7BD5), BlendMode.src);
    final picture = recorder.endRecording();
    final image = await picture.toImage(400, 300);
    _capturePng = (await image.toByteData(
      format: ui.ImageByteFormat.png,
    ))!.buffer.asUint8List();
    image.dispose();
    picture.dispose();
  });

  testWidgets('Escape cancels the active capture overlay', (tester) async {
    final service = _FakeCaptureService();
    final window = _FakeCaptureWindowController();
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        home: EditorScreen(
          captureService: service,
          captureWindowController: window,
        ),
      ),
    );

    await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
    await tester.pumpAndSettle();

    expect(find.textContaining('Hover a window'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(window.restoreCount, 1);
    expect(find.text('Capture. Mark up. Share.'), findsOneWidget);
  });

  testWidgets('captures and shows an attached functional Quick HUD', (
    tester,
  ) async {
    final service = _FakeCaptureService();
    final window = _FakeCaptureWindowController();
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        home: EditorScreen(
          captureService: service,
          captureWindowController: window,
        ),
      ),
    );

    expect(find.text('Capture. Mark up. Share.'), findsOneWidget);
    expect(find.byTooltip('Copy (Ctrl+C)'), findsOneWidget);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
    await tester.pumpAndSettle();

    expect(service.captureCount, 1);
    expect(window.prepareCount, 1);
    expect(window.overlayCount, 1);
    expect(find.textContaining('Hover a window'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);

    final gesture = await tester.startGesture(
      const Offset(100, 100),
      buttons: kPrimaryButton,
    );
    await gesture.moveTo(const Offset(300, 280));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(service.cropCount, 1);
    expect(find.byTooltip('Filled rectangle (R)'), findsOneWidget);
    expect(find.byTooltip('Mosaic (M)'), findsOneWidget);
    expect(find.byTooltip('Confirm and copy (Enter)'), findsOneWidget);
    expect(find.text('400 × 300'), findsOneWidget);

    final annotationGesture = await tester.startGesture(
      const Offset(130, 130),
      buttons: kPrimaryButton,
    );
    await annotationGesture.moveTo(const Offset(220, 210));
    await annotationGesture.up();
    await tester.pump();

    final hud = tester.widget<QuickCaptureView>(find.byType(QuickCaptureView));
    expect(hud.controller.canUndo, isTrue);
    await _chord(tester, LogicalKeyboardKey.keyZ);
    expect(hud.controller.annotations, isEmpty);
    await _chord(tester, LogicalKeyboardKey.keyZ, shift: true);
    expect(hud.controller.annotations, hasLength(1));
  });

  testWidgets('Save As cancellation preserves Quick capture and annotations', (
    tester,
  ) async {
    final window = _FakeCaptureWindowController();
    final output = _FakeOutput();
    await _quickSession(tester, window, output);
    final hud = tester.widget<QuickCaptureView>(find.byType(QuickCaptureView));
    hud.controller.addText(const Offset(8, 8), 'Keep this label');
    await tester.pump();

    await _renderAction(tester, LogicalKeyboardKey.keyS, output);

    expect(output.savedPng, isNotNull);
    expect(window.restoreCount, 0);
    expect(find.byType(QuickCaptureView), findsOneWidget);
    expect(hud.controller.annotations, hasLength(1));
  });

  testWidgets('pin exports physical pixels and dismisses only after success', (
    tester,
  ) async {
    final window = _FakeCaptureWindowController();
    final output = _FakeOutput();
    await _quickSession(tester, window, output);

    await _renderAction(tester, LogicalKeyboardKey.keyP, output);

    expect(output.pinnedPng, isNotNull);
    final header = ByteData.sublistView(output.pinnedPng!);
    expect(header.getUint32(16), 400);
    expect(header.getUint32(20), 300);
    expect(window.restoreCount, 1);
    expect(find.byType(QuickCaptureView), findsNothing);
  });

  testWidgets('crop shrinks the badge and exports only the cropped pixels', (
    tester,
  ) async {
    final window = _FakeCaptureWindowController();
    final output = _FakeOutput();
    await _quickSession(tester, window, output);
    expect(find.text('400 × 300'), findsOneWidget);
    final hud = tester.widget<QuickCaptureView>(find.byType(QuickCaptureView));

    await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
    await tester.pump();
    expect(hud.controller.tool, EditorTool.crop);

    // The 400 × 300 capture is fitted at 0.5x inside the 200 × 180 selection,
    // so it occupies view x 100..300 and y 115..265. Mid-pixel start and end
    // points keep the floor/ceil snapping unambiguous.
    await tester.dragFrom(const Offset(150.25, 140.25), const Offset(100, 60));
    await tester.pumpAndSettle();
    expect(hud.controller.crop, const Rect.fromLTRB(100, 50, 301, 171));
    expect(find.text('201 × 121'), findsOneWidget);
    expect(find.text('400 × 300'), findsNothing);

    await _chord(tester, LogicalKeyboardKey.keyZ);
    expect(hud.controller.crop, isNull);
    expect(find.text('400 × 300'), findsOneWidget);
    await _chord(tester, LogicalKeyboardKey.keyY);
    expect(hud.controller.crop, const Rect.fromLTRB(100, 50, 301, 171));

    await _renderAction(tester, LogicalKeyboardKey.keyP, output);
    final header = ByteData.sublistView(output.pinnedPng!);
    expect(header.getUint32(16), 201);
    expect(header.getUint32(20), 121);
    expect(window.restoreCount, 1);
  });

  testWidgets('failed pin leaves the capture available for retry', (
    tester,
  ) async {
    final window = _FakeCaptureWindowController();
    final output = _FakeOutput()..pinError = StateError('Pin failed');
    await _quickSession(tester, window, output);

    await _renderAction(tester, LogicalKeyboardKey.keyP, output);

    expect(window.restoreCount, 0);
    expect(find.byType(QuickCaptureView), findsOneWidget);
    expect(find.textContaining('Pin failed'), findsOneWidget);
  });

  testWidgets('share opens a local chooser and closes without losing capture', (
    tester,
  ) async {
    await _quickSession(tester, _FakeCaptureWindowController(), _FakeOutput());
    await _chord(tester, LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text('Share capture'), findsOneWidget);
    expect(find.text('Copy image'), findsOneWidget);
    expect(find.text('Save PNG'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(QuickCaptureView), findsOneWidget);
  });

  testWidgets('cancelling a pending capture cannot reopen its overlay', (
    tester,
  ) async {
    final source = Completer<CapturedFrame>();
    final service = _FakeCaptureService()..pending = source.future;
    final window = _FakeCaptureWindowController();
    await tester.pumpWidget(
      MaterialApp(
        home: EditorScreen(
          captureService: service,
          captureWindowController: window,
          captureOutputService: _FakeOutput(),
        ),
      ),
    );
    await _startCapture(tester);
    await window.cancelled?.call();
    await tester.pump();
    source.complete(_frame());
    await tester.pumpAndSettle();
    expect(window.overlayCount, 0);
    expect(find.byType(QuickCaptureView), findsNothing);
    expect(find.text('Capture. Mark up. Share.'), findsOneWidget);
  });
}

CapturedFrame _frame() => CapturedFrame(
  pngBytes: _capturePng,
  width: 400,
  height: 300,
  originX: 0,
  originY: 0,
  scaleFactor: 1,
  displays: const [],
);

Future<void> _startCapture(WidgetTester tester) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
  await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
  await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
  await tester.pump();
}

Future<void> _quickSession(
  WidgetTester tester,
  _FakeCaptureWindowController window,
  _FakeOutput output,
) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData.dark(useMaterial3: true),
      home: EditorScreen(
        captureService: _FakeCaptureService(),
        captureWindowController: window,
        captureOutputService: output,
      ),
    ),
  );
  await _startCapture(tester);
  await tester.pumpAndSettle();
  await tester.dragFrom(const Offset(100, 100), const Offset(200, 180));
  await tester.pumpAndSettle();
  expect(find.byType(QuickCaptureView), findsOneWidget);
}

Future<void> _chord(
  WidgetTester tester,
  LogicalKeyboardKey key, {
  bool shift = false,
}) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  if (shift) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
  await tester.sendKeyEvent(key);
  if (shift) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await tester.pump();
}

Future<void> _renderAction(
  WidgetTester tester,
  LogicalKeyboardKey key,
  _FakeOutput output,
) async {
  await tester.runAsync(() async {
    await _chord(tester, key);
    // Image encoding completes on the engine thread. Pump fake microtasks while
    // allowing that real asynchronous work to finish.
    for (
      var attempt = 0;
      attempt < 100 && !output.called.isCompleted;
      attempt++
    ) {
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  });
  await tester.pumpAndSettle();
  expect(output.called.isCompleted, isTrue);
}

class _FakeOutput implements CaptureOutputService {
  final called = Completer<void>();
  Uint8List? savedPng;
  Uint8List? pinnedPng;
  Object? pinError;
  @override
  Future<void> copyPng(Uint8List bytes) async {
    called.complete();
  }

  @override
  Future<String?> savePngAs(Uint8List bytes) async {
    savedPng = bytes;
    called.complete();
    return null;
  }

  @override
  Future<void> pinPng(Uint8List bytes) async {
    pinnedPng = bytes;
    called.complete();
    if (pinError case final error?) throw error;
  }
}

class _FakeCaptureService implements CaptureService {
  int captureCount = 0;
  int cropCount = 0;
  Future<CapturedFrame>? pending;

  @override
  PlatformCapabilities capabilities() => const PlatformCapabilities(
    platform: 'windows',
    desktopCapture: true,
    regionOverlay: false,
    globalHotkey: false,
    pinWindow: false,
  );

  @override
  Future<CapturedFrame> captureDesktop() async {
    captureCount += 1;
    return pending ?? _frame();
  }

  @override
  Future<CapturedFrame> cropFrame(
    CapturedFrame frame,
    int left,
    int top,
    int width,
    int height,
  ) async {
    cropCount += 1;
    return frame;
  }

  @override
  Future<String> savePng(List<int> pngBytes) async => 'capture.png';

  @override
  Future<String?> savePngAs(List<int> pngBytes) async => 'capture.png';
}

class _FakeCaptureWindowController implements CaptureWindowController {
  int prepareCount = 0;
  int overlayCount = 0;
  int restoreCount = 0;
  Future<void> Function()? cancelled;

  @override
  Future<void> prepareCapture() async {
    prepareCount += 1;
  }

  @override
  Future<void> restoreEditor() async {
    restoreCount += 1;
  }

  @override
  Future<void> showEditor() async {}

  @override
  void setCaptureRequestedHandler(Future<void> Function()? handler) {}

  @override
  void setCaptureCancelledHandler(Future<void> Function()? handler) {
    cancelled = handler;
  }

  @override
  Future<void> showCaptureOverlay() async {
    overlayCount += 1;
  }

  @override
  Future<WindowBounds?> windowAtPoint(int x, int y) async => null;
}
