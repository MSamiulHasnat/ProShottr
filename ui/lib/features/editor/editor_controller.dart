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
  Rect? _crop;
  final List<_SceneState> _undo = [];
  final List<_SceneState> _redo = [];
  AnnotationObject? _draft;
  Rect? _cropDraft;
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

  /// Visible region of the source image in physical source pixels, or null
  /// when the whole image is visible. Exports are exactly this size.
  Rect? get crop => _crop;

  /// The crop rectangle being dragged, in source pixels, before it commits.
  Rect? get cropDraft => _cropDraft;

  /// The crop that would commit if the current drag ended now: whole source
  /// pixels inside the current crop, or null when there is no usable drag.
  Rect? get pendingCrop {
    final draft = _cropDraft;
    return draft == null ? null : _normalizeCrop(draft);
  }

  int get revision => _revision;
  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;

  EditorSnapshot snapshot() =>
      EditorSnapshot._(_state, List.of(_undo), List.of(_redo));

  void restore(EditorSnapshot snapshot) {
    _apply(snapshot._current);
    _undo
      ..clear()
      ..addAll(snapshot._undo);
    _redo
      ..clear()
      ..addAll(snapshot._redo);
    _draft = null;
    _cropDraft = null;
    _dragOrigin = null;
    notifyListeners();
  }

  @override
  void notifyListeners() {
    _revision++;
    super.notifyListeners();
  }

  AnnotationStyle get _style =>
      AnnotationStyle(color: _color, strokeWidth: _strokeWidth);

  _SceneState get _state => _SceneState(List.of(_annotations), _crop);

  void _apply(_SceneState state) {
    _annotations
      ..clear()
      ..addAll(state.annotations);
    _crop = state.crop;
  }

  void _pushHistory() {
    _undo.add(_state);
    _redo.clear();
  }

  void selectTool(EditorTool value) {
    if (_tool == value) return;
    _tool = value;
    _draft = null;
    _cropDraft = null;
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
    if (_tool == EditorTool.crop) {
      _draft = null;
      _cropDraft = Rect.fromPoints(point, point);
      notifyListeners();
      return;
    }
    _cropDraft = null;
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
      EditorTool.select ||
      EditorTool.text ||
      EditorTool.sticker ||
      EditorTool.crop => null,
    };
    notifyListeners();
  }

  void updateStroke(Offset point) {
    final origin = _dragOrigin;
    if (origin == null) return;
    if (_cropDraft != null) {
      _cropDraft = Rect.fromPoints(origin, point);
      notifyListeners();
      return;
    }
    final current = _draft;
    if (current == null) return;

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
    final cropDraft = _cropDraft;
    final current = _draft;
    _draft = null;
    _cropDraft = null;
    _dragOrigin = null;
    if (cropDraft != null) {
      final next = _normalizeCrop(cropDraft);
      if (next == null || next == _crop) {
        notifyListeners();
      } else {
        _pushHistory();
        _crop = next;
        notifyListeners();
      }
      return;
    }
    if (current != null && _isMeaningful(current)) {
      _commit(current);
    } else {
      notifyListeners();
    }
  }

  void cancelStroke() {
    if (_draft == null && _cropDraft == null && _dragOrigin == null) return;
    _draft = null;
    _cropDraft = null;
    _dragOrigin = null;
    notifyListeners();
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

  /// Sets the visible region as one undoable step, or clears it with null.
  ///
  /// The rectangle is in source pixels. It is snapped outward to whole pixels
  /// and intersected with the current crop, so a crop can only shrink until
  /// it is reset or undone. Rectangles under 2 × 2 pixels are ignored.
  void setCrop(Rect? value) {
    final next = value == null ? null : _normalizeCrop(value);
    if (value != null && next == null) return;
    if (next == _crop) return;
    _pushHistory();
    _crop = next;
    notifyListeners();
  }

  Rect? _normalizeCrop(Rect value) {
    var rect = Rect.fromLTRB(
      value.left.floorToDouble(),
      value.top.floorToDouble(),
      value.right.ceilToDouble(),
      value.bottom.ceilToDouble(),
    );
    if (_crop case final current?) rect = rect.intersect(current);
    if (rect.width < 2 || rect.height < 2) return null;
    return rect;
  }

  void undo() {
    if (_undo.isEmpty) return;
    _redo.add(_state);
    _apply(_undo.removeLast());
    notifyListeners();
  }

  void redo() {
    if (_redo.isEmpty) return;
    _undo.add(_state);
    _apply(_redo.removeLast());
    notifyListeners();
  }

  /// Removes every annotation as one undoable step; the crop is kept.
  void clear() {
    if (_annotations.isEmpty) return;
    _pushHistory();
    _annotations.clear();
    notifyListeners();
  }

  void reset() {
    _annotations.clear();
    _crop = null;
    _undo.clear();
    _redo.clear();
    _draft = null;
    _cropDraft = null;
    _dragOrigin = null;
    notifyListeners();
  }

  void _commit(AnnotationObject annotation) {
    _pushHistory();
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

/// One undoable version of the document: its annotations and its crop.
class _SceneState {
  _SceneState(List<AnnotationObject> annotations, this.crop)
    : annotations = List.unmodifiable(annotations);

  final List<AnnotationObject> annotations;
  final Rect? crop;
}

/// A capture session can be discarded without losing the prior editor history.
class EditorSnapshot {
  EditorSnapshot._(this._current, this._undo, this._redo);

  final _SceneState _current;
  final List<_SceneState> _undo;
  final List<_SceneState> _redo;
}
