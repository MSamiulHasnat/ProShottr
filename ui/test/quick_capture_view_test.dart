import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proshottr/features/capture/quick_capture_view.dart';
import 'package:proshottr/features/editor/editor_controller.dart';
import 'package:proshottr/features/editor/editor_models.dart';
import 'package:proshottr/src/rust/capture.dart';

late Uint8List _png;

Future<void> _pumpHud(
  WidgetTester tester, {
  required EditorController controller,
  Size display = const Size(1200, 800),
  Rect selection = const Rect.fromLTWH(0.1, 0.1, 0.8, 0.5),
  bool logicalPixels = false,
  int width = 1200,
  int height = 800,
  double scale = 1,
  VoidCallback? onSave,
  VoidCallback? onPin,
  VoidCallback? onShare,
  VoidCallback? onExtractText,
  bool hasTextContent = false,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = display;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final frame = CapturedFrame(
    pngBytes: _png,
    width: width,
    height: height,
    originX: 0,
    originY: 0,
    scaleFactor: scale,
    displays: const [],
  );
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData.dark(useMaterial3: true),
      home: QuickCaptureView(
        frame: frame,
        desktopFrame: frame,
        normalizedSelection: selection,
        controller: controller,
        exportKey: GlobalKey(),
        busy: false,
        onTextRequested: (_) async {},
        onCancel: () {},
        onDone: () {},
        onSave: onSave ?? () {},
        onPin: onPin ?? () {},
        onShare: onShare ?? () {},
        onOpenEditor: () {},
        onExtractText: onExtractText,
        hasTextContent: hasTextContent,
        showLogicalPixels: logicalPixels,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _tooltipStarting(String text) => find.byWidgetPredicate(
  (widget) => widget is Tooltip && widget.message?.startsWith(text) == true,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawColor(const Color(0xFF324D68), BlendMode.src);
    final picture = recorder.endRecording();
    final image = await picture.toImage(1, 1);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    _png = data!.buffer.asUint8List();
    image.dispose();
    picture.dispose();
  });

  testWidgets(
    'wide HUD preserves four group order and explains disabled tools',
    (tester) async {
      final controller = EditorController();
      addTearDown(controller.dispose);
      await _pumpHud(tester, controller: controller);

      final tooltips = [
        'Filled rectangle (R)',
        'Outline ellipse (E)',
        'Sticker (S)',
        'Arrow (A)',
        'Brush (P)',
        'Mosaic (M)',
        'Text (T)',
        'Translate',
        'Extract text (OCR)',
        'Scrolling capture',
        'Undo (Ctrl+Z)',
        'Redo (Ctrl+Y / Ctrl+Shift+Z)',
        'Save as PNG (Ctrl+S)',
        'Pin to desktop (Ctrl+P)',
        'Share / send (Ctrl+Enter)',
        'Cancel (Esc)',
        'Confirm and copy (Enter)',
      ];
      var previous = -1.0;
      for (final tooltip in tooltips) {
        final finder = _tooltipStarting(tooltip);
        expect(finder, findsOneWidget);
        final position = tester.getCenter(finder).dx;
        expect(position, greaterThan(previous));
        previous = position;
      }
      expect(
        find.byTooltip('Translate — No translation provider configured'),
        findsOneWidget,
      );
      expect(
        find.byTooltip('Undo (Ctrl+Z) — No annotations to undo'),
        findsOneWidget,
      );
      expect(find.byType(SingleChildScrollView), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'content collapses before output, remaining tools stay centered',
    (tester) async {
      final controller = EditorController();
      addTearDown(controller.dispose);
      await _pumpHud(
        tester,
        controller: controller,
        selection: const Rect.fromLTWH(0.25, 0.1, 0.5, 0.3),
      );

      expect(_tooltipStarting('Translate'), findsNothing);
      expect(find.byTooltip('Save as PNG (Ctrl+S)'), findsOneWidget);
      final bar = tester.getRect(find.byKey(const ValueKey('quick-hud')));
      expect(bar.center.dx, 600);
      expect(bar.top, greaterThan(320));
      await tester.tap(find.byTooltip('More tools'));
      await tester.pumpAndSettle();
      expect(find.text('Translate'), findsOneWidget);
      expect(find.text('No translation provider configured'), findsOneWidget);
      expect(find.text('Save as PNG'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'narrow selection puts content and output in an actionable flyout',
    (tester) async {
      final controller = EditorController();
      addTearDown(controller.dispose);
      var saves = 0;
      await _pumpHud(
        tester,
        controller: controller,
        selection: const Rect.fromLTWH(0.4, 0.1, 0.2, 0.3),
        onSave: () => saves++,
      );

      expect(find.byTooltip('Filled rectangle (R)'), findsOneWidget);
      expect(find.byTooltip('Text (T)'), findsOneWidget);
      expect(find.byTooltip('Cancel (Esc)'), findsOneWidget);
      expect(find.byTooltip('Confirm and copy (Enter)'), findsOneWidget);
      expect(find.byTooltip('Save as PNG (Ctrl+S)'), findsNothing);
      expect(
        tester.getRect(find.byKey(const ValueKey('quick-hud'))).center.dx,
        600,
      );
      await tester.tap(find.byTooltip('More tools'));
      await tester.pumpAndSettle();
      expect(find.text('Translate'), findsOneWidget);
      expect(find.text('Pin to desktop'), findsOneWidget);
      expect(find.text('Share / send'), findsOneWidget);
      await tester.tap(find.text('Save as PNG'));
      await tester.pumpAndSettle();
      expect(saves, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'near bottom and right edges HUD flips and clamps outside capture',
    (tester) async {
      final controller = EditorController();
      addTearDown(controller.dispose);
      await _pumpHud(
        tester,
        controller: controller,
        selection: const Rect.fromLTWH(0.8, 0.75, 0.18, 0.15),
      );
      final bar = tester.getRect(find.byKey(const ValueKey('quick-hud')));
      expect(bar.bottom, lessThan(600));
      expect(bar.right, lessThanOrEqualTo(1200));
      expect(bar.left, greaterThanOrEqualTo(0));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'full display uses reduced opacity and badge passes drawing input',
    (tester) async {
      final controller = EditorController();
      addTearDown(controller.dispose);
      await _pumpHud(
        tester,
        controller: controller,
        selection: const Rect.fromLTWH(0, 0, 1, 1),
      );
      final opacity = tester.widget<Opacity>(
        find.ancestor(
          of: find.byKey(const ValueKey('quick-hud')),
          matching: find.byType(Opacity),
        ),
      );
      expect(opacity.opacity, lessThan(1));
      final badge = find.byKey(const ValueKey('capture-resolution'));
      expect(tester.widget<IgnorePointer>(badge).ignoring, isTrue);
      final gesture = await tester.startGesture(tester.getCenter(badge));
      await gesture.moveBy(const Offset(80, 60));
      await gesture.up();
      await tester.pump();
      expect(controller.annotations, hasLength(1));
    },
  );

  testWidgets('badge follows raster changes, units, and display edges', (
    tester,
  ) async {
    final controller = EditorController();
    addTearDown(controller.dispose);
    await _pumpHud(
      tester,
      controller: controller,
      width: 1600,
      height: 900,
      scale: 2,
      selection: const Rect.fromLTWH(0.98, 0, 0.02, 0.5),
    );
    expect(find.text('1600 × 900 @2x'), findsOneWidget);
    final badge = tester.getRect(
      find.byKey(const ValueKey('capture-resolution')),
    );
    expect(badge.right, lessThanOrEqualTo(1200));
    expect(badge.top, greaterThanOrEqualTo(0));
    await _pumpHud(
      tester,
      controller: controller,
      width: 1200,
      height: 600,
      scale: 2,
      logicalPixels: true,
    );
    expect(find.text('600 × 300 @2x'), findsOneWidget);
  });

  testWidgets('crop re-anchors the badge and toolbar and can be reset', (
    tester,
  ) async {
    final controller = EditorController();
    addTearDown(controller.dispose);
    await _pumpHud(tester, controller: controller);
    expect(find.text('1200 × 800'), findsOneWidget);
    final before = tester.getRect(find.byKey(const ValueKey('quick-hud')));

    await tester.tap(find.byTooltip('More tools'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Crop'));
    await tester.pumpAndSettle();
    expect(controller.tool, EditorTool.crop);
    expect(find.text('Drag inside the capture to crop'), findsOneWidget);

    // The 1200 × 800 raster is fitted at 0.5x inside the 960 × 400 selection,
    // so it spans view x 300..900 and y 80..480.
    final gesture = await tester.startGesture(const Offset(400.25, 120.25));
    await gesture.moveTo(const Offset(600.25, 220.25));
    await tester.pump();
    expect(find.text('401 × 201'), findsOneWidget, reason: 'live badge');
    await gesture.up();
    await tester.pumpAndSettle();
    expect(controller.crop, const Rect.fromLTRB(200, 80, 601, 281));
    expect(find.text('401 × 201'), findsOneWidget);

    // The crop maps to view (280, 120) with size 320.8 × 100.5; the badge
    // sits above its top-left corner and the toolbar below its centre.
    final badge = tester.getRect(
      find.byKey(const ValueKey('capture-resolution')),
    );
    expect(badge.left, closeTo(280, 1));
    expect(badge.bottom, lessThanOrEqualTo(120));
    final after = tester.getRect(find.byKey(const ValueKey('quick-hud')));
    expect(after.top, closeTo(230.5, 1));
    expect(after.center.dx, closeTo(440.4, 1));
    expect(after, isNot(before));

    // Reset is offered both in the crop style row and in the overflow menu.
    await tester.tap(find.byTooltip('More tools'));
    await tester.pumpAndSettle();
    expect(find.text('Reset crop'), findsNWidgets(2));
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(find.text('Reset crop'), findsOneWidget);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Reset crop'));
    await tester.pumpAndSettle();
    expect(controller.crop, isNull);
    expect(controller.canUndo, isTrue);
    expect(find.text('1200 × 800'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('OCR needs detected text and a backend', (tester) async {
    final controller = EditorController();
    addTearDown(controller.dispose);
    var extracted = 0;
    await _pumpHud(
      tester,
      controller: controller,
      onExtractText: () => extracted++,
    );
    expect(
      find.byTooltip('Extract text (OCR) — No text detected in this capture'),
      findsOneWidget,
    );
    await _pumpHud(
      tester,
      controller: controller,
      hasTextContent: true,
      onExtractText: () => extracted++,
    );
    await tester.tap(find.byTooltip('Extract text (OCR)'));
    expect(extracted, 1);
  });

  testWidgets('mosaic replaces palette with a explained disabled AI toggle', (
    tester,
  ) async {
    final controller = EditorController();
    addTearDown(controller.dispose);
    await _pumpHud(tester, controller: controller);
    await tester.tap(find.byTooltip('Mosaic (M)'));
    await tester.pumpAndSettle();
    expect(controller.tool, EditorTool.mosaic);
    expect(find.byTooltip('Blue'), findsNothing);
    expect(find.text('AI masking'), findsOneWidget);
    expect(tester.widget<Switch>(find.byType(Switch)).onChanged, isNull);
    expect(
      _tooltipStarting('AI masking — automatic sensitive-content'),
      findsOneWidget,
    );
  });

  testWidgets(
    'small display retains draw and session tools and sticker recents',
    (tester) async {
      final controller = EditorController();
      addTearDown(controller.dispose);
      await _pumpHud(
        tester,
        controller: controller,
        display: const Size(320, 640),
      );
      expect(find.byTooltip('Confirm and copy (Enter)'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Sticker (S)'));
      await tester.pumpAndSettle();
      expect(find.text('RECENT'), findsOneWidget);
      await tester.tap(find.text('Objects'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('⭐'));
      await tester.pumpAndSettle();
      expect(controller.sticker, '⭐');
      await tester.tap(find.text('Choose sticker'));
      await tester.pumpAndSettle();
      expect(find.text('⭐'), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Quick HUD visual preview (run with --update-goldens)', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 800);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = EditorController();
    addTearDown(controller.dispose);
    final frames = await tester.runAsync(() async {
      final configFile = File('.dart_tool/package_config.json');
      final config = jsonDecode(await configFile.readAsString()) as Map;
      final flutterPackage = (config['packages'] as List)
          .cast<Map>()
          .firstWhere((package) => package['name'] == 'flutter');
      final sdk = Directory.fromUri(
        configFile.absolute.uri.resolve(flutterPackage['rootUri'] as String),
      ).parent.parent.path;
      final fonts = '$sdk/bin/cache/artifacts/material_fonts';
      for (final entry in [
        ('Roboto', 'roboto-regular.ttf'),
        ('MaterialIcons', 'materialicons-regular.otf'),
      ]) {
        final loader = FontLoader(entry.$1)
          ..addFont(
            File('$fonts/${entry.$2}').readAsBytes().then(ByteData.sublistView),
          );
        await loader.load();
      }
      return _previewFrames();
    });
    debugDisableShadows = false;
    controller.setColor(const Color(0xFFE9435B));
    controller.selectTool(EditorTool.arrow);
    controller.beginStroke(const Offset(565, 320));
    controller.updateStroke(const Offset(700, 215));
    controller.endStroke();
    controller.setColor(const Color(0xFF2788F5));
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark(useMaterial3: true).copyWith(
          textTheme: ThemeData.dark().textTheme.apply(fontFamily: 'Roboto'),
        ),
        home: QuickCaptureView(
          frame: frames!.$2,
          desktopFrame: frames.$1,
          normalizedSelection: const Rect.fromLTWH(0.125, 0.15, 0.75, 0.55),
          controller: controller,
          exportKey: GlobalKey(),
          busy: false,
          onTextRequested: (_) async {},
          onCancel: () {},
          onDone: () {},
          onSave: () {},
          onPin: () {},
          onShare: () {},
          onOpenEditor: () {},
        ),
      ),
    );
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(QuickCaptureView),
      matchesGoldenFile('goldens/quick_capture.png'),
    );
    debugDisableShadows = true;
  }, skip: !autoUpdateGoldenFiles);
}

Future<(CapturedFrame, CapturedFrame)> _previewFrames() async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    const Rect.fromLTWH(0, 0, 1280, 800),
    Paint()..color = const Color(0xFF263648),
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      const Rect.fromLTWH(105, 60, 1070, 665),
      const Radius.circular(14),
    ),
    Paint()..color = const Color(0xFFF5F7FB),
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      const Rect.fromLTWH(105, 60, 1070, 42),
      const Radius.circular(14),
    ),
    Paint()..color = const Color(0xFFE2E8F0),
  );
  for (var i = 0; i < 3; i++) {
    canvas.drawCircle(
      Offset(127 + i * 18, 81),
      5,
      Paint()..color = [Colors.redAccent, Colors.amber, Colors.green][i],
    );
  }
  void label(
    String value,
    Offset at,
    double fontSize,
    Color color, {
    FontWeight weight = FontWeight.w400,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: value,
        style: TextStyle(
          fontSize: fontSize,
          color: color,
          fontWeight: weight,
          fontFamily: 'Roboto',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, at);
    painter.dispose();
  }

  label(
    'studio.example / overview',
    const Offset(482, 72),
    12,
    const Color(0xFF5C6D83),
  );
  label(
    'STUDIO',
    const Offset(191, 147),
    14,
    const Color(0xFF2788F5),
    weight: FontWeight.w700,
  );
  label(
    'A little progress, every day.',
    const Offset(191, 180),
    30,
    const Color(0xFF1F3047),
    weight: FontWeight.w700,
  );
  label(
    'Your project overview for September',
    const Offset(191, 228),
    14,
    const Color(0xFF738296),
  );
  const cards = [
    ('Projects shipped', '24', '+6 this month'),
    ('Team focus', '92%', '+12% this month'),
    ('Happy customers', '1,280', '+18% this month'),
  ];
  for (var i = 0; i < cards.length; i++) {
    final x = 191.0 + i * 290;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x, 278, 266, 166),
        const Radius.circular(14),
      ),
      Paint()..color = Colors.white,
    );
    label(cards[i].$1, Offset(x + 22, 300), 14, const Color(0xFF738296));
    label(
      cards[i].$2,
      Offset(x + 22, 336),
      35,
      const Color(0xFF1F3047),
      weight: FontWeight.w700,
    );
    label(cards[i].$3, Offset(x + 22, 400), 12, const Color(0xFF28A36B));
  }
  label(
    'Small steps. Visible results.',
    const Offset(191, 484),
    17,
    const Color(0xFF738296),
  );
  final picture = recorder.endRecording();
  final desktop = await picture.toImage(1280, 800);
  picture.dispose();
  final cropRecorder = ui.PictureRecorder();
  Canvas(cropRecorder).drawImageRect(
    desktop,
    const Rect.fromLTWH(160, 120, 960, 440),
    const Rect.fromLTWH(0, 0, 960, 440),
    Paint(),
  );
  final cropPicture = cropRecorder.endRecording();
  final crop = await cropPicture.toImage(960, 440);
  cropPicture.dispose();
  final desktopBytes = await desktop.toByteData(format: ui.ImageByteFormat.png);
  final cropBytes = await crop.toByteData(format: ui.ImageByteFormat.png);
  desktop.dispose();
  crop.dispose();
  return (
    CapturedFrame(
      pngBytes: desktopBytes!.buffer.asUint8List(),
      width: 1280,
      height: 800,
      originX: 0,
      originY: 0,
      scaleFactor: 1,
      displays: const [],
    ),
    CapturedFrame(
      pngBytes: cropBytes!.buffer.asUint8List(),
      width: 960,
      height: 440,
      originX: 160,
      originY: 120,
      scaleFactor: 1,
      displays: const [],
    ),
  );
}
