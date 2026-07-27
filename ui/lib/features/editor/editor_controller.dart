import 'dart:collection';
import 'dart:ui';

import 'package:flutter/foundation.dart';

import 'editor_models.dart';

class EditorController extends ChangeNotifier {
  EditorTool _tool = EditorTool.rectangle;
  Color _color = const Color(0xFFE9435B);
  double _strokeWidth = 5;
  double _fontSize = 32;
  String _sticker = '😀';
  final List<AnnotationObject> _annotations = [];
  final List<List<AnnotationObject>> _undo = [];
  final List<List<AnnotationObject>> _redo = [];
  AnnotationObject? _draft;
  Offset? _dragOrigin;
  int _revision = 0;

  EditorTool get tool => _tool;
  Color get color => _color;
  double get strokeWidth => _strokeWidth;
  double get fontSize => _fontSize;
  String get sticker => _sticker;
  UnmodifiableListView<AnnotationObject> get annotations =>
      UnmodifiableListView(_annotations);
  AnnotationObject? get draft => _draft;
  int get revision => _revision;
  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;

  @override
  void notifyListeners() {
    _revision++;
    super.notifyListeners();
  }

  AnnotationStyle get _style =>
      AnnotationStyle(color: _color, strokeWidth: _strokeWidth);

  void selectTool(EditorTool value) {
    if (_tool == value) return;
    _tool = value;
    _draft = null;
    _dragOrigin = null;
    notifyListeners();
  }

  void setColor(Color value) {
    if (_color == value) return;
    _color = value;
    notifyListeners();
  }

  void setStrokeWidth(double value) {
    final next = value.clamp(1, 24).toDouble();
    if (_strokeWidth == next) return;
    _strokeWidth = next;
    notifyListeners();
  }

  void setFontSize(double value) {
    if (_fontSize == value) return;
    _fontSize = value;
    notifyListeners();
  }

  void setSticker(String value) {
    if (value.isEmpty) return;
    _sticker = value;
    _tool = EditorTool.sticker;
    notifyListeners();
  }

  void beginStroke(Offset point) {
    _dragOrigin = point;
    _draft = switch (_tool) {
      EditorTool.rectangle => RectangleAnnotation(
        bounds: Rect.fromPoints(point, point),
        style: _style,
      ),
      EditorTool.ellipse => EllipseAnnotation(
        bounds: Rect.fromPoints(point, point),
        style: _style,
      ),
      EditorTool.arrow => ArrowAnnotation(
        start: point,
        end: point,
        style: _style,
      ),
      EditorTool.pen => PenAnnotation(points: [point], style: _style),
      EditorTool.mosaic => MosaicAnnotation(
        bounds: Rect.fromPoints(point, point),
        blockSize: _strokeWidth * 3,
        style: _style,
      ),
      EditorTool.select || EditorTool.text || EditorTool.sticker => null,
    };
    notifyListeners();
  }

  void updateStroke(Offset point) {
    final origin = _dragOrigin;
    final current = _draft;
    if (origin == null || current == null) return;

    _draft = switch (current) {
      RectangleAnnotation() => current.copyWith(
        bounds: Rect.fromPoints(origin, point),
      ),
      EllipseAnnotation() => current.copyWith(
        bounds: Rect.fromPoints(origin, point),
      ),
      ArrowAnnotation() => current.copyWith(end: point),
      PenAnnotation() => current.copyWith(points: [...current.points, point]),
      MosaicAnnotation() => current.copyWith(
        bounds: Rect.fromPoints(origin, point),
      ),
      TextAnnotation() || StickerAnnotation() => current,
    };
    notifyListeners();
  }

  void endStroke() {
    final current = _draft;
    _draft = null;
    _dragOrigin = null;
    if (current != null && _isMeaningful(current)) {
      _commit(current);
    } else {
      notifyListeners();
    }
  }

  void addText(Offset origin, String text, {double? fontSize}) {
    final value = text.trim();
    if (value.isEmpty) return;
    _commit(
      TextAnnotation(
        origin: origin,
        text: value,
        fontSize: fontSize ?? _fontSize,
        style: _style,
      ),
    );
  }

  void addSticker(Offset center) {
    _commit(
      StickerAnnotation(
        center: center,
        emoji: _sticker,
        size: 56,
        style: _style,
      ),
    );
  }

  void undo() {
    if (_undo.isEmpty) return;
    _redo.add(List.of(_annotations));
    _annotations
      ..clear()
      ..addAll(_undo.removeLast());
    notifyListeners();
  }

  void redo() {
    if (_redo.isEmpty) return;
    _undo.add(List.of(_annotations));
    _annotations
      ..clear()
      ..addAll(_redo.removeLast());
    notifyListeners();
  }

  void clear() {
    if (_annotations.isEmpty) return;
    _undo.add(List.of(_annotations));
    _redo.clear();
    _annotations.clear();
    notifyListeners();
  }

  void reset() {
    _annotations.clear();
    _undo.clear();
    _redo.clear();
    _draft = null;
    _dragOrigin = null;
    notifyListeners();
  }

  void _commit(AnnotationObject annotation) {
    _undo.add(List.of(_annotations));
    _redo.clear();
    _annotations.add(annotation);
    notifyListeners();
  }

  bool _isMeaningful(AnnotationObject annotation) => switch (annotation) {
    RectangleAnnotation(:final bounds) ||
    EllipseAnnotation(:final bounds) => bounds.width >= 2 && bounds.height >= 2,
    ArrowAnnotation(:final start, :final end) => (end - start).distance >= 2,
    PenAnnotation(:final points) => points.length >= 2,
    MosaicAnnotation(:final bounds) => bounds.width >= 2 && bounds.height >= 2,
    TextAnnotation(:final text) => text.isNotEmpty,
    StickerAnnotation(:final emoji) => emoji.isNotEmpty,
  };
}
