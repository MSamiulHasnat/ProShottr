import 'dart:ui';

enum EditorTool {
  select,
  rectangle,
  ellipse,
  sticker,
  arrow,
  pen,
  mosaic,
  text,

  /// Drag to shrink the visible region of the capture. A crop is a document
  /// property, not a raster edit: annotations keep their source coordinates
  /// and the step is undoable.
  crop,
}

class AnnotationStyle {
  const AnnotationStyle({required this.color, required this.strokeWidth});

  final Color color;
  final double strokeWidth;
}

sealed class AnnotationObject {
  const AnnotationObject({required this.style});

  final AnnotationStyle style;
}

class RectangleAnnotation extends AnnotationObject {
  const RectangleAnnotation({required this.bounds, required super.style});

  final Rect bounds;

  RectangleAnnotation copyWith({Rect? bounds, AnnotationStyle? style}) =>
      RectangleAnnotation(
        bounds: bounds ?? this.bounds,
        style: style ?? this.style,
      );
}

class EllipseAnnotation extends AnnotationObject {
  const EllipseAnnotation({required this.bounds, required super.style});

  final Rect bounds;

  EllipseAnnotation copyWith({Rect? bounds, AnnotationStyle? style}) =>
      EllipseAnnotation(
        bounds: bounds ?? this.bounds,
        style: style ?? this.style,
      );
}

class ArrowAnnotation extends AnnotationObject {
  const ArrowAnnotation({
    required this.start,
    required this.end,
    required super.style,
  });

  final Offset start;
  final Offset end;

  ArrowAnnotation copyWith({
    Offset? start,
    Offset? end,
    AnnotationStyle? style,
  }) => ArrowAnnotation(
    start: start ?? this.start,
    end: end ?? this.end,
    style: style ?? this.style,
  );
}

class PenAnnotation extends AnnotationObject {
  PenAnnotation({required List<Offset> points, required super.style})
    : points = List.unmodifiable(points);

  final List<Offset> points;

  PenAnnotation copyWith({List<Offset>? points, AnnotationStyle? style}) =>
      PenAnnotation(points: points ?? this.points, style: style ?? this.style);
}

class TextAnnotation extends AnnotationObject {
  const TextAnnotation({
    required this.origin,
    required this.text,
    required this.fontSize,
    required super.style,
  });

  final Offset origin;
  final String text;
  final double fontSize;
}

class StickerAnnotation extends AnnotationObject {
  const StickerAnnotation({
    required this.center,
    required this.emoji,
    required this.size,
    required super.style,
  });

  final Offset center;
  final String emoji;
  final double size;
}

class MosaicAnnotation extends AnnotationObject {
  const MosaicAnnotation({
    required this.bounds,
    required this.blockSize,
    required super.style,
  });

  final Rect bounds;
  final double blockSize;

  MosaicAnnotation copyWith({
    Rect? bounds,
    double? blockSize,
    AnnotationStyle? style,
  }) => MosaicAnnotation(
    bounds: bounds ?? this.bounds,
    blockSize: blockSize ?? this.blockSize,
    style: style ?? this.style,
  );
}
