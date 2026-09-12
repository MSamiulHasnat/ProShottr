import 'dart:ui' show Offset, Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:proshottr/features/editor/editor_controller.dart';
import 'package:proshottr/features/editor/editor_models.dart';

void main() {
  test(
    'discarded capture restores prior image annotations and redo history',
    () {
      final controller = EditorController();
      addTearDown(controller.dispose);
      controller.addText(const Offset(5, 5), 'Keep me');
      controller.addText(const Offset(8, 8), 'Redo me');
      controller.undo();
      final previous = controller.snapshot();
      controller.reset();
      controller.addText(const Offset(2, 2), 'Discard me');

      controller.restore(previous);

      expect((controller.annotations.single as TextAnnotation).text, 'Keep me');
      expect(controller.canRedo, isTrue);
      controller.redo();
      expect((controller.annotations.last as TextAnnotation).text, 'Redo me');
      controller.undo();
      controller.undo();
      expect(controller.annotations, isEmpty);
    },
  );

  test('cancelled pointer input never commits a partial annotation', () {
    final controller = EditorController();
    addTearDown(controller.dispose);
    controller.beginStroke(const Offset(5, 5));
    controller.updateStroke(const Offset(100, 90));
    controller.cancelStroke();
    expect(controller.draft, isNull);
    expect(controller.canUndo, isFalse);
    expect(controller.annotations, isEmpty);
  });

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

  test('crop is an undoable step that only shrinks until it is reset', () {
    final controller = EditorController();
    addTearDown(controller.dispose);
    controller.addText(const Offset(5, 5), 'Label');

    controller.setCrop(const Rect.fromLTWH(10.4, 20.6, 100.2, 50.5));
    expect(controller.crop, const Rect.fromLTRB(10, 20, 111, 72));
    expect(controller.annotations, hasLength(1));

    // A later crop is clipped to the current one; it can never grow by drag.
    controller.setCrop(const Rect.fromLTWH(0, 0, 60, 40));
    expect(controller.crop, const Rect.fromLTRB(10, 20, 60, 40));
    // A crop under 2 × 2 pixels is ignored and adds no history.
    controller.setCrop(const Rect.fromLTWH(20, 25, 1, 1));
    expect(controller.crop, const Rect.fromLTRB(10, 20, 60, 40));

    controller.undo();
    expect(controller.crop, const Rect.fromLTRB(10, 20, 111, 72));
    controller.undo();
    expect(controller.crop, isNull);
    expect(controller.annotations, hasLength(1));
    controller.redo();
    expect(controller.crop, const Rect.fromLTRB(10, 20, 111, 72));

    controller.setCrop(null);
    expect(controller.crop, isNull);
    expect(controller.canRedo, isFalse);
    controller.undo();
    expect(controller.crop, const Rect.fromLTRB(10, 20, 111, 72));
  });

  test('crop tool drags commit whole pixels and survive snapshots', () {
    final controller = EditorController();
    addTearDown(controller.dispose);
    controller.selectTool(EditorTool.crop);
    controller.beginStroke(const Offset(30, 30));
    controller.updateStroke(const Offset(90.5, 70.2));
    expect(controller.draft, isNull);
    expect(controller.pendingCrop, const Rect.fromLTRB(30, 30, 91, 71));
    controller.endStroke();
    expect(controller.crop, const Rect.fromLTRB(30, 30, 91, 71));
    expect(controller.cropDraft, isNull);
    expect(controller.canUndo, isTrue);

    final snapshot = controller.snapshot();
    controller.reset();
    expect(controller.crop, isNull);
    controller.restore(snapshot);
    expect(controller.crop, const Rect.fromLTRB(30, 30, 91, 71));

    // Clearing markup keeps the crop; a cancelled drag commits nothing.
    controller.addText(const Offset(40, 40), 'Inside');
    controller.clear();
    expect(controller.annotations, isEmpty);
    expect(controller.crop, const Rect.fromLTRB(30, 30, 91, 71));
    controller.beginStroke(const Offset(35, 35));
    controller.updateStroke(const Offset(60, 60));
    controller.cancelStroke();
    expect(controller.pendingCrop, isNull);
    expect(controller.crop, const Rect.fromLTRB(30, 30, 91, 71));
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
