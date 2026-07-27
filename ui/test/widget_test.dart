import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proshottr/features/editor/editor_screen.dart';
import 'package:proshottr/services/capture_service.dart';
import 'package:proshottr/services/windows_capture_window.dart';
import 'package:proshottr/src/rust/capture.dart';

void main() {
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
    expect(find.byTooltip('Filled rectangle'), findsOneWidget);
    expect(find.byTooltip('Mosaic'), findsOneWidget);
    expect(find.byTooltip('Done — copy to clipboard'), findsOneWidget);
    expect(find.text('400 × 300'), findsOneWidget);

    final annotationGesture = await tester.startGesture(
      const Offset(130, 130),
      buttons: kPrimaryButton,
    );
    await annotationGesture.moveTo(const Offset(220, 210));
    await annotationGesture.up();
    await tester.pump();

    final undo = tester.widget<IconButton>(
      find.ancestor(
        of: find.byTooltip('Undo (Ctrl+Z)'),
        matching: find.byType(IconButton),
      ),
    );
    expect(undo.onPressed, isNotNull);
  });
}

class _FakeCaptureService implements CaptureService {
  int captureCount = 0;
  int cropCount = 0;

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
    return CapturedFrame(
      pngBytes: Uint8List.fromList(
        base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M/wHwAE/wJ/l4T76QAAAABJRU5ErkJggg==',
        ),
      ),
      width: 400,
      height: 300,
      originX: 0,
      originY: 0,
      scaleFactor: 1,
    );
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
  void setCaptureCancelledHandler(Future<void> Function()? handler) {}

  @override
  Future<void> showCaptureOverlay() async {
    overlayCount += 1;
  }

  @override
  Future<WindowBounds?> windowAtPoint(int x, int y) async => null;
}
