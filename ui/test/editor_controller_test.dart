import 'package:flutter_test/flutter_test.dart';
import 'package:proshottr/features/editor/editor_controller.dart';
import 'package:proshottr/features/editor/editor_models.dart';

void main() {
  test('commits a rectangle and supports undo and redo', () {
    final controller = EditorController();
    controller.selectTool(EditorTool.rectangle);

    controller.beginStroke(const Offset(10, 20));
    controller.updateStroke(const Offset(110, 70));
    controller.endStroke();

    expect(controller.annotations, hasLength(1));
    expect(controller.canUndo, isTrue);

    controller.undo();
    expect(controller.annotations, isEmpty);
    expect(controller.canRedo, isTrue);

    controller.redo();
    expect(controller.annotations, hasLength(1));
  });

  test('ignores accidental clicks that have no drawable size', () {
    final controller = EditorController();
    controller.beginStroke(const Offset(20, 20));
    controller.endStroke();

    expect(controller.annotations, isEmpty);
    expect(controller.canUndo, isFalse);
  });

  test('a new annotation clears redo history', () {
    final controller = EditorController();
    controller.addText(const Offset(4, 8), 'First');
    controller.undo();
    controller.addText(const Offset(4, 8), 'Second');

    expect(controller.canRedo, isFalse);
    expect(controller.annotations.single, isA<TextAnnotation>());
  });

  test('uses the three text presets for new labels', () {
    final controller = EditorController()..setFontSize(48);
    controller.addText(const Offset(10, 10), 'Large');

    final annotation = controller.annotations.single as TextAnnotation;
    expect(annotation.fontSize, 48);
  });

  test('commits sticker and mosaic annotations non-destructively', () {
    final controller = EditorController();
    controller.setSticker('🚀');
    controller.addSticker(const Offset(40, 40));
    controller.selectTool(EditorTool.mosaic);
    controller.beginStroke(const Offset(10, 10));
    controller.updateStroke(const Offset(100, 80));
    controller.endStroke();

    expect(controller.annotations.first, isA<StickerAnnotation>());
    expect(controller.annotations.last, isA<MosaicAnnotation>());
    expect(controller.canUndo, isTrue);
  });
}
