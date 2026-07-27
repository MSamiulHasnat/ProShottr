import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'editor_models.dart';

class AnnotationPainter extends CustomPainter {
  const AnnotationPainter({
    required this.annotations,
    required this.imageSize,
    this.revision = 0,
    this.draft,
    this.imagePixels,
    this.pixelOrigin = Offset.zero,
  });

  final List<AnnotationObject> annotations;
  final int revision;
  final AnnotationObject? draft;
  final ByteData? imagePixels;
  final Size imageSize;
  final Offset pixelOrigin;

  @override
  void paint(Canvas canvas, Size size) {
    for (final annotation in annotations) {
      _paintAnnotation(canvas, annotation, size);
    }
    if (draft case final annotation?) {
      _paintAnnotation(canvas, annotation, size);
    }
  }

  void _paintAnnotation(
    Canvas canvas,
    AnnotationObject annotation,
    Size canvasSize,
  ) {
    final paint = Paint()
      ..color = annotation.style.color
      ..strokeWidth = annotation.style.strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;

    switch (annotation) {
      case RectangleAnnotation(:final bounds):
        canvas.drawRect(bounds, paint..style = PaintingStyle.fill);
      case EllipseAnnotation(:final bounds):
        canvas.drawOval(bounds, paint);
      case ArrowAnnotation(:final start, :final end):
        _paintArrow(canvas, start, end, paint);
      case PenAnnotation(:final points):
        _paintPen(canvas, points, paint);
      case TextAnnotation(:final origin, :final text, :final fontSize):
        final painter = TextPainter(
          text: TextSpan(
            text: text,
            style: TextStyle(
              color: annotation.style.color,
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
              height: 1.15,
              shadows: const [Shadow(color: Color(0x66000000), blurRadius: 2)],
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        painter.paint(canvas, origin);
      case StickerAnnotation(:final center, :final emoji, :final size):
        final painter = TextPainter(
          text: TextSpan(
            text: emoji,
            style: TextStyle(fontSize: size),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        painter.paint(
          canvas,
          center - Offset(painter.width / 2, painter.height / 2),
        );
      case MosaicAnnotation(:final bounds, :final blockSize):
        _paintMosaic(canvas, bounds, blockSize, canvasSize);
    }
  }

  void _paintMosaic(
    Canvas canvas,
    Rect bounds,
    double blockSize,
    Size canvasSize,
  ) {
    final pixels = imagePixels;
    if (pixels == null || imageSize.isEmpty) {
      canvas.drawRect(bounds, Paint()..color = const Color(0xAA7B8492));
      return;
    }
    final clipped = bounds.intersect(Offset.zero & canvasSize);
    final step = blockSize.clamp(6, 36).toDouble();
    final width = imageSize.width.round();
    final height = imageSize.height.round();
    final paint = Paint()..style = PaintingStyle.fill;
    for (double y = clipped.top; y < clipped.bottom; y += step) {
      for (double x = clipped.left; x < clipped.right; x += step) {
        final sampleX = (x + step / 2 + pixelOrigin.dx).floor().clamp(
          0,
          width - 1,
        );
        final sampleY = (y + step / 2 + pixelOrigin.dy).floor().clamp(
          0,
          height - 1,
        );
        final offset = (sampleY * width + sampleX) * 4;
        paint.color = Color.fromARGB(
          pixels.getUint8(offset + 3),
          pixels.getUint8(offset),
          pixels.getUint8(offset + 1),
          pixels.getUint8(offset + 2),
        );
        canvas.drawRect(
          Rect.fromLTWH(
            x,
            y,
            math.min(step + 0.5, clipped.right - x),
            math.min(step + 0.5, clipped.bottom - y),
          ),
          paint,
        );
      }
    }
  }

  void _paintPen(Canvas canvas, List<Offset> points, Paint paint) {
    if (points.length < 2) return;
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var index = 1; index < points.length - 1; index++) {
      final point = points[index];
      final next = points[index + 1];
      final midpoint = Offset(
        (point.dx + next.dx) / 2,
        (point.dy + next.dy) / 2,
      );
      path.quadraticBezierTo(point.dx, point.dy, midpoint.dx, midpoint.dy);
    }
    path.lineTo(points.last.dx, points.last.dy);
    canvas.drawPath(path, paint);
  }

  void _paintArrow(Canvas canvas, Offset start, Offset end, Paint paint) {
    final delta = end - start;
    if (delta.distance < 0.1) return;
    canvas.drawLine(start, end, paint);

    final angle = math.atan2(delta.dy, delta.dx);
    final headLength = math.max(14, paint.strokeWidth * 4);
    const spread = math.pi / 7;
    final first =
        end -
        Offset(
          math.cos(angle - spread) * headLength,
          math.sin(angle - spread) * headLength,
        );
    final second =
        end -
        Offset(
          math.cos(angle + spread) * headLength,
          math.sin(angle + spread) * headLength,
        );
    final head = Path()
      ..moveTo(first.dx, first.dy)
      ..lineTo(end.dx, end.dy)
      ..lineTo(second.dx, second.dy);
    canvas.drawPath(head, paint);
  }

  @override
  bool shouldRepaint(covariant AnnotationPainter oldDelegate) =>
      oldDelegate.revision != revision ||
      oldDelegate.draft != draft ||
      oldDelegate.imagePixels != imagePixels ||
      oldDelegate.imageSize != imageSize ||
      oldDelegate.pixelOrigin != pixelOrigin;
}
