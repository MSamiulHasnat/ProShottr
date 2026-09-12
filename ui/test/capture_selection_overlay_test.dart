import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proshottr/features/capture/capture_selection_overlay.dart';
import 'package:proshottr/features/editor/editor_controller.dart';
import 'package:proshottr/services/windows_capture_window.dart';
import 'package:proshottr/src/rust/capture.dart';

void main() {
  testWidgets('probe reads one frozen pixel in physical coordinates at 2x', (
    tester,
  ) async {
    final harness = await _mount(tester);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(100.8, 60.8));
    await mouse.moveTo(const Offset(100.8, 60.8));
    await tester.pump(const Duration(milliseconds: 40));

    expect(find.text('LOC -1399,21 @2x'), findsOneWidget);
    expect(find.text('HEX #3A7BD5'), findsOneWidget);
    expect(find.text('RGB 58, 123, 213'), findsOneWidget);
    expect(harness.window.points.last, const Offset(-1399, 21));
    final region = tester.widget<MouseRegion>(
      find
          .byWidgetPredicate(
            (widget) => widget is MouseRegion && widget.onHover != null,
          )
          .first,
    );
    expect(region.cursor, SystemMouseCursors.none);

    await mouse.moveTo(const Offset(799.9, 599.9));
    await tester.pump(const Duration(milliseconds: 40));
    expect(find.text('LOC -1,1099 @2x'), findsOneWidget);
    expect(find.text('HEX #112233'), findsOneWidget);
    final probe = tester.getRect(
      find.byKey(const ValueKey('capture-pixel-probe')),
    );
    expect(probe.left, greaterThanOrEqualTo(0));
    expect(probe.top, greaterThanOrEqualTo(0));
    expect(probe.right, lessThanOrEqualTo(800));
    expect(probe.bottom, lessThanOrEqualTo(600));
    await mouse.removePointer();
    await tester.pumpWidget(const SizedBox());
  });

  for (final rgb in [false, true]) {
    testWidgets('${rgb ? 'Shift+C' : 'C'} copies color before dismissing', (
      tester,
    ) async {
      final harness = await _mount(tester);
      final clipboard = Completer<Object?>();
      final writes = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            writes.add((call.arguments as Map)['text'] as String);
            return clipboard.future;
          }
          return null;
        },
      );
      addTearDown(() {
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        );
      });

      if (rgb) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
      if (rgb) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();
      expect(writes, [rgb ? 'rgb(58, 123, 213)' : '#3A7BD5']);
      expect(harness.cancelCount, 0);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
      expect(writes.length, 1, reason: 'an in-flight copy must not duplicate');
      clipboard.complete();
      await tester.pump();
      expect(harness.cancelCount, 1);
      expect(harness.selections, isEmpty);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('modified C shortcuts do not copy or dismiss the selection', (
    tester,
  ) async {
    final harness = await _mount(tester);
    final writes = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          writes.add((call.arguments as Map)['text'] as String);
        }
        return null;
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
    });
    for (final modifier in [
      LogicalKeyboardKey.controlLeft,
      LogicalKeyboardKey.altLeft,
      LogicalKeyboardKey.metaLeft,
    ]) {
      await tester.sendKeyDownEvent(modifier);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
      await tester.sendKeyUpEvent(modifier);
    }
    expect(writes, isEmpty);
    expect(harness.cancelCount, 0);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('arrow nudges use physical pixels and reject Ctrl modifiers', (
    tester,
  ) async {
    final harness = await _mount(tester);
    final drag = await tester.startGesture(const Offset(100, 100));
    await drag.moveTo(const Offset(200, 200));
    await tester.pump();
    expect(find.text('200 × 200 @2x'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    expect(find.text('201 × 210 @2x'), findsOneWidget);
    await drag.up();
    await tester.pumpAndSettle();
    expect(harness.selections.single, const Rect.fromLTRB(200, 200, 401, 410));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a fast click resolves the new window rather than cached hover', (
    tester,
  ) async {
    final harness = await _mount(tester);
    harness.window.hitTest = (x, y) async =>
        x < -1200 ? _backWindow : _frontWindow;
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(100, 100));
    await mouse.moveTo(const Offset(100, 100));
    await tester.pump(const Duration(milliseconds: 40));
    expect(_highlight(tester), const Rect.fromLTRB(0, 0, 600, 400));
    final wash = await tester.runAsync(() async {
      final recorder = ui.PictureRecorder();
      final painter = tester
          .widget<CustomPaint>(
            find.byKey(const ValueKey('capture-selection-paint')),
          )
          .painter!;
      painter.paint(Canvas(recorder), const Size(800, 600));
      final picture = recorder.endRecording();
      final image = await picture.toImage(800, 600);
      final data = await image.toByteData();
      picture.dispose();
      image.dispose();
      return data!;
    });
    expect(
      wash!.getUint8((200 * 800 + 400) * 4 + 3),
      0,
      reason: 'hovered window must remain at full brightness',
    );
    expect(
      wash.getUint8((500 * 800 + 700) * 4 + 3),
      0x66,
      reason: 'the rest of the desktop keeps the 40% dark wash',
    );

    // The front window overlaps the old cached rectangle. Click without
    // waiting for the next hover timer, as people do when moving quickly.
    await mouse.moveTo(const Offset(300, 100));
    await mouse.down(const Offset(300, 100));
    await mouse.up();
    await tester.pumpAndSettle();
    expect(harness.selections.single, const Rect.fromLTRB(400, 0, 1000, 600));
    await mouse.removePointer();
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'overlapping windows re-detect and discard out-of-order results',
    (tester) async {
      final harness = await _mount(tester);
      final oldRequest = Completer<WindowBounds?>();
      harness.window.hitTest = (x, y) =>
          x < -1200 ? oldRequest.future : Future.value(_frontWindow);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: const Offset(100, 100));
      await mouse.moveTo(const Offset(100, 100));
      await tester.pump(const Duration(milliseconds: 40));
      await mouse.moveTo(const Offset(300, 100));
      await tester.pump(const Duration(milliseconds: 40));
      expect(_highlight(tester), const Rect.fromLTRB(200, 0, 500, 300));
      oldRequest.complete(_backWindow);
      await tester.pump();
      expect(_highlight(tester), const Rect.fromLTRB(200, 0, 500, 300));
      await mouse.removePointer();
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('right-click cancels and click on empty desktop is a no-op', (
    tester,
  ) async {
    final harness = await _mount(tester);
    await tester.tapAt(const Offset(100, 100));
    await tester.pumpAndSettle();
    expect(harness.selections, isEmpty);
    expect(harness.cancelCount, 0);
    final secondary = await tester.startGesture(
      const Offset(100, 100),
      buttons: kSecondaryButton,
    );
    await secondary.up();
    await tester.pump();
    expect(harness.cancelCount, 1);
    expect(harness.selections, isEmpty);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('probe and size label use the scale of the display under them', (
    tester,
  ) async {
    // The 1600 × 1200 frame spans a 1x display on the left and a 2x display
    // on the right, both 800 physical pixels wide.
    final harness = await _mount(
      tester,
      displays: const [
        DisplayInfo(
          id: r'\\.\DISPLAY2',
          name: 'left',
          originX: -1600,
          originY: -100,
          width: 800,
          height: 1200,
          scaleFactor: 1,
          isPrimary: false,
        ),
        DisplayInfo(
          id: r'\\.\DISPLAY1',
          name: 'right',
          originX: -800,
          originY: -100,
          width: 800,
          height: 1200,
          scaleFactor: 2,
          isPrimary: true,
        ),
      ],
    );
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(100, 60));
    await mouse.moveTo(const Offset(100, 60));
    await tester.pump(const Duration(milliseconds: 40));
    expect(find.text('LOC -1400,20'), findsOneWidget);

    await mouse.moveTo(const Offset(500, 60));
    await tester.pump(const Duration(milliseconds: 40));
    expect(find.text('LOC -600,20 @2x'), findsOneWidget);

    // A selection is labelled in the units of the display under its centre,
    // while the confirmed bounds stay physical.
    final drag = await tester.startGesture(const Offset(450, 100));
    await drag.moveTo(const Offset(550, 200));
    await tester.pump();
    expect(find.text('200 × 200 @2x'), findsOneWidget);
    await drag.up();
    await tester.pumpAndSettle();
    expect(harness.selections.single, const Rect.fromLTRB(900, 200, 1100, 400));
    await mouse.removePointer();
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('logical display preference preserves physical crop bounds', (
    tester,
  ) async {
    final harness = await _mount(tester, logical: true);
    expect(find.text('LOC -800,-50 @2x'), findsOneWidget);
    final drag = await tester.startGesture(const Offset(100, 100));
    await drag.moveTo(const Offset(200, 200));
    await tester.pump();
    expect(find.text('100 × 100 @2x'), findsOneWidget);
    await drag.up();
    await tester.pumpAndSettle();
    expect(harness.selections.single, const Rect.fromLTRB(200, 200, 400, 400));
    await tester.pumpWidget(const SizedBox());
  });
}

Rect? _highlight(WidgetTester tester) {
  final paint = tester.widget<CustomPaint>(
    find.byKey(const ValueKey('capture-selection-paint')),
  );
  return (paint.painter as dynamic).windowHighlight as Rect?;
}

const _backWindow = WindowBounds(
  left: -1600,
  top: -100,
  right: -400,
  bottom: 700,
);
const _frontWindow = WindowBounds(
  left: -1200,
  top: -100,
  right: -600,
  bottom: 500,
);

Future<_Harness> _mount(
  WidgetTester tester, {
  bool logical = false,
  List<DisplayInfo> displays = const [],
}) async {
  final harness = _Harness();
  final controller = EditorController();
  addTearDown(controller.dispose);
  final frame = await tester.runAsync(() async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawColor(const Color(0xFF3A7BD5), BlendMode.src);
    canvas.drawRect(
      const Rect.fromLTWH(800, 0, 800, 1200),
      Paint()..color = const Color(0xFF112233),
    );
    final picture = recorder.endRecording();
    final image = await picture.toImage(1600, 1200);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    picture.dispose();
    image.dispose();
    return CapturedFrame(
      pngBytes: data!.buffer.asUint8List(),
      width: 1600,
      height: 1200,
      originX: -1600,
      originY: -100,
      scaleFactor: 2,
      displays: displays,
    );
  });
  await tester.pumpWidget(
    MaterialApp(
      home: CaptureSelectionOverlay(
        frame: frame!,
        controller: controller,
        windowController: harness.window,
        onTextRequested: (_) async {},
        onCancel: () => harness.cancelCount++,
        onConfirm: (pixels, _) async => harness.selections.add(pixels),
        showLogicalPixels: logical,
      ),
    ),
  );
  await tester.runAsync(() async {
    // Image decoding/readback happens on the engine, outside fake test time.
    await Future<void>.delayed(const Duration(milliseconds: 100));
  });
  await tester.pumpAndSettle();
  expect(find.text('HEX #3A7BD5'), findsOneWidget);
  return harness;
}

class _Harness {
  final window = _FakeWindowController();
  final selections = <Rect>[];
  int cancelCount = 0;
}

class _FakeWindowController implements CaptureWindowController {
  final points = <Offset>[];
  Future<WindowBounds?> Function(int, int)? hitTest;

  @override
  Future<WindowBounds?> windowAtPoint(int x, int y) async {
    points.add(Offset(x.toDouble(), y.toDouble()));
    return hitTest?.call(x, y);
  }

  @override
  void setCaptureRequestedHandler(Future<void> Function()? handler) {}
  @override
  void setCaptureCancelledHandler(Future<void> Function()? handler) {}
  @override
  Future<void> prepareCapture() async {}
  @override
  Future<void> restoreEditor() async {}
  @override
  Future<void> showCaptureOverlay() async {}
  @override
  Future<void> showEditor() async {}
}
