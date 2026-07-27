import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:proshottr/src/rust/capture.dart';

import '../../services/windows_capture_window.dart';
import '../editor/annotation_painter.dart';
import '../editor/editor_controller.dart';

class CaptureSelectionOverlay extends StatefulWidget {
  const CaptureSelectionOverlay({
    super.key,
    required this.frame,
    required this.controller,
    required this.windowController,
    required this.onTextRequested,
    required this.onCancel,
    required this.onConfirm,
  });

  final CapturedFrame frame;
  final EditorController controller;
  final CaptureWindowController windowController;
  final Future<void> Function(Offset point) onTextRequested;
  final VoidCallback onCancel;
  final Future<void> Function(Rect pixelBounds, Rect normalizedBounds)
  onConfirm;

  @override
  State<CaptureSelectionOverlay> createState() =>
      _CaptureSelectionOverlayState();
}

class _CaptureSelectionOverlayState extends State<CaptureSelectionOverlay> {
  Rect? _selection;
  Rect? _windowHighlight;
  Offset _cursor = Offset.zero;
  Offset? _dragStart;
  Rect? _dragSelection;
  _DragMode _dragMode = _DragMode.newSelection;
  ui.Image? _decodedImage;
  ByteData? _pixels;
  Size _viewSize = Size.zero;
  bool _confirming = false;
  Timer? _windowDetectionTimer;
  Timer? _cursorRebuildTimer;
  int _windowDetectionRequest = 0;

  @override
  void initState() {
    super.initState();
    // Let the frozen screenshot paint once before doing the full-size pixel
    // readback used by the coordinate/color HUD.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _decodePixels();
    });
  }

  @override
  void dispose() {
    _windowDetectionTimer?.cancel();
    _cursorRebuildTimer?.cancel();
    _decodedImage?.dispose();
    super.dispose();
  }

  Future<void> _decodePixels() async {
    final codec = await ui.instantiateImageCodec(widget.frame.pngBytes);
    final decoded = await codec.getNextFrame();
    codec.dispose();
    final pixels = await decoded.image.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    );
    if (!mounted) {
      decoded.image.dispose();
      return;
    }
    setState(() {
      _decodedImage = decoded.image;
      _pixels = pixels;
    });
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): widget.onCancel,
        const SingleActivator(LogicalKeyboardKey.enter): _confirm,
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: Colors.black,
          body: LayoutBuilder(
            builder: (context, constraints) {
              _viewSize = constraints.biggest;
              return MouseRegion(
                cursor: SystemMouseCursors.precise,
                onHover: (event) => _cursorMoved(event.localPosition),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    RepaintBoundary(
                      child: Image.memory(
                        widget.frame.pngBytes,
                        fit: BoxFit.fill,
                        gaplessPlayback: true,
                        filterQuality: FilterQuality.low,
                      ),
                    ),
                    Listener(
                      behavior: HitTestBehavior.opaque,
                      onPointerDown: _pointerDown,
                      onPointerMove: _pointerMove,
                      onPointerUp: _pointerUp,
                      onPointerCancel: (_) => _finishDrag(),
                      child: const SizedBox.expand(),
                    ),
                    IgnorePointer(
                      child: CustomPaint(
                        painter: _SelectionPainter(
                          selection: _selection,
                          windowHighlight: _windowHighlight,
                          cursor: _cursor,
                        ),
                      ),
                    ),
                    if (_selection case final selection?)
                      _buildInlineAnnotations(selection),
                    _buildCoordinateHud(),
                    if (_selection case final selection?) ...[
                      _buildDimensionLabel(selection),
                    ],
                    const Positioned(
                      left: 18,
                      bottom: 18,
                      child: _SelectionHint(),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildInlineAnnotations(Rect selection) {
    return Positioned(
      left: selection.left,
      top: selection.top,
      width: selection.width,
      height: selection.height,
      child: IgnorePointer(
        child: CustomPaint(
          painter: AnnotationPainter(
            annotations: widget.controller.annotations,
            draft: widget.controller.draft,
            imagePixels: _pixels,
            imageSize: Size(
              widget.frame.width.toDouble(),
              widget.frame.height.toDouble(),
            ),
            pixelOrigin: Offset(
              _toPixel(Offset(selection.left, 0)).dx,
              _toPixel(Offset(0, selection.top)).dy,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCoordinateHud() {
    final pixel = _toPixel(_cursor);
    final x = widget.frame.originX + pixel.dx.round();
    final y = widget.frame.originY + pixel.dy.round();
    final hex = _hexAt(pixel);
    const hudWidth = 180.0;
    final placeLeft = _cursor.dx + 18 + hudWidth < _viewSize.width;
    final left = placeLeft ? _cursor.dx + 18 : _cursor.dx - hudWidth - 8;
    final top = (_cursor.dy + 18).clamp(8, _viewSize.height - 62).toDouble();
    return Positioned(
      left: left.clamp(8, _viewSize.width - hudWidth - 8).toDouble(),
      top: top,
      child: IgnorePointer(
        child: Container(
          width: hudWidth,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: const Color(0xED11151C),
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: const Color(0xFF3B4658)),
            boxShadow: const [
              BoxShadow(color: Color(0x66000000), blurRadius: 10),
            ],
          ),
          child: DefaultTextStyle(
            style: const TextStyle(
              fontFamily: 'Consolas',
              fontSize: 11,
              color: Colors.white,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('LOC  $x,$y'),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: _colorAt(pixel),
                        border: Border.all(color: Colors.white54),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text('HEX  $hex'),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDimensionLabel(Rect selection) {
    final pixels = _toPixelRect(selection);
    final top = selection.top > 34 ? selection.top - 30 : selection.top + 8;
    return Positioned(
      left: selection.left,
      top: top,
      child: IgnorePointer(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xEB11151C),
            borderRadius: BorderRadius.circular(5),
          ),
          child: Text(
            '${pixels.width.round()} × ${pixels.height.round()}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  void _pointerDown(PointerDownEvent event) {
    if (_confirming || event.buttons != kPrimaryButton) return;
    final point = _clampPoint(event.localPosition);
    _cursorMoved(point);
    _dragStart = point;
    _dragSelection = _selection;
    _dragMode = _hitTest(point);
    if (_dragMode == _DragMode.newSelection) {
      _selection = Rect.fromPoints(point, point);
    }
    setState(() {});
  }

  void _pointerMove(PointerMoveEvent event) {
    final point = _clampPoint(event.localPosition);
    _cursorMoved(point);
    final start = _dragStart;
    final original = _dragSelection;
    if (start == null) {
      setState(() {});
      return;
    }

    final delta = point - start;
    Rect next;
    if (_dragMode == _DragMode.newSelection || original == null) {
      next = Rect.fromPoints(start, point);
    } else if (_dragMode == _DragMode.move) {
      next = original.shift(delta);
      if (next.left < 0) next = next.shift(Offset(-next.left, 0));
      if (next.top < 0) next = next.shift(Offset(0, -next.top));
      if (next.right > _viewSize.width) {
        next = next.shift(Offset(_viewSize.width - next.right, 0));
      }
      if (next.bottom > _viewSize.height) {
        next = next.shift(Offset(0, _viewSize.height - next.bottom));
      }
    } else {
      var left = original.left;
      var top = original.top;
      var right = original.right;
      var bottom = original.bottom;
      if (_dragMode.adjustsLeft) left = point.dx;
      if (_dragMode.adjustsRight) right = point.dx;
      if (_dragMode.adjustsTop) top = point.dy;
      if (_dragMode.adjustsBottom) bottom = point.dy;
      next = Rect.fromLTRB(
        left.clamp(0, _viewSize.width),
        top.clamp(0, _viewSize.height),
        right.clamp(0, _viewSize.width),
        bottom.clamp(0, _viewSize.height),
      );
      next = Rect.fromLTRB(
        next.left < next.right ? next.left : next.right,
        next.top < next.bottom ? next.top : next.bottom,
        next.left < next.right ? next.right : next.left,
        next.top < next.bottom ? next.bottom : next.top,
      );
    }
    setState(() => _selection = next);
  }

  void _pointerUp(PointerUpEvent event) {
    if (_dragStart == null) return;
    final point = _clampPoint(event.localPosition);
    final start = _dragStart!;
    final moved = (point - start).distance >= 8;
    _cursorMoved(point);
    final autoWindow = _windowHighlight;
    final valid = _finishDrag();
    if (valid) {
      _confirm();
    } else if (!moved && autoWindow != null) {
      setState(() => _selection = autoWindow);
      _confirm();
    }
  }

  bool _finishDrag() {
    final selection = _selection;
    final valid =
        selection != null && selection.width >= 4 && selection.height >= 4;
    setState(() {
      _dragStart = null;
      _dragSelection = null;
      if (!valid) _selection = null;
    });
    return valid;
  }

  _DragMode _hitTest(Offset point) {
    final rect = _selection;
    if (rect == null) return _DragMode.newSelection;
    const radius = 10.0;
    final nearLeft = (point.dx - rect.left).abs() <= radius;
    final nearRight = (point.dx - rect.right).abs() <= radius;
    final nearTop = (point.dy - rect.top).abs() <= radius;
    final nearBottom = (point.dy - rect.bottom).abs() <= radius;
    if (nearLeft && nearTop) return _DragMode.topLeft;
    if (nearRight && nearTop) return _DragMode.topRight;
    if (nearLeft && nearBottom) return _DragMode.bottomLeft;
    if (nearRight && nearBottom) return _DragMode.bottomRight;
    if (nearLeft && point.dy >= rect.top && point.dy <= rect.bottom) {
      return _DragMode.left;
    }
    if (nearRight && point.dy >= rect.top && point.dy <= rect.bottom) {
      return _DragMode.right;
    }
    if (nearTop && point.dx >= rect.left && point.dx <= rect.right) {
      return _DragMode.top;
    }
    if (nearBottom && point.dx >= rect.left && point.dx <= rect.right) {
      return _DragMode.bottom;
    }
    if (rect.contains(point)) return _DragMode.move;
    return _DragMode.newSelection;
  }

  Future<void> _confirm() async {
    final selection = _selection;
    if (selection == null || _confirming) return;
    setState(() => _confirming = true);
    try {
      final normalized = Rect.fromLTRB(
        selection.left / _viewSize.width,
        selection.top / _viewSize.height,
        selection.right / _viewSize.width,
        selection.bottom / _viewSize.height,
      );
      await widget.onConfirm(_toPixelRect(selection), normalized);
    } finally {
      if (mounted) setState(() => _confirming = false);
    }
  }

  void _cursorMoved(Offset value) {
    final point = _clampPoint(value);
    _cursor = point;
    _scheduleWindowDetection();
    if (_cursorRebuildTimer != null) return;
    _cursorRebuildTimer = Timer(const Duration(milliseconds: 16), () {
      _cursorRebuildTimer = null;
      if (mounted) setState(() {});
    });
  }

  void _scheduleWindowDetection() {
    _windowDetectionTimer?.cancel();
    final request = ++_windowDetectionRequest;
    _windowDetectionTimer = Timer(const Duration(milliseconds: 35), () async {
      final pixel = _toPixel(_cursor);
      final detected = await widget.windowController.windowAtPoint(
        widget.frame.originX + pixel.dx.round(),
        widget.frame.originY + pixel.dy.round(),
      );
      if (!mounted || request != _windowDetectionRequest) return;
      final next = _toViewRect(detected);
      if (next != _windowHighlight) setState(() => _windowHighlight = next);
    });
  }

  Rect? _toViewRect(WindowBounds? bounds) {
    if (bounds == null || _viewSize.isEmpty) return null;
    final left =
        ((bounds.left - widget.frame.originX) *
                _viewSize.width /
                widget.frame.width)
            .clamp(0, _viewSize.width)
            .toDouble();
    final top =
        ((bounds.top - widget.frame.originY) *
                _viewSize.height /
                widget.frame.height)
            .clamp(0, _viewSize.height)
            .toDouble();
    final right =
        ((bounds.right - widget.frame.originX) *
                _viewSize.width /
                widget.frame.width)
            .clamp(0, _viewSize.width)
            .toDouble();
    final bottom =
        ((bounds.bottom - widget.frame.originY) *
                _viewSize.height /
                widget.frame.height)
            .clamp(0, _viewSize.height)
            .toDouble();
    if (right - left < 4 || bottom - top < 4) return null;
    return Rect.fromLTRB(left, top, right, bottom);
  }

  Offset _clampPoint(Offset value) => Offset(
    value.dx.clamp(0, _viewSize.width).toDouble(),
    value.dy.clamp(0, _viewSize.height).toDouble(),
  );

  Offset _toPixel(Offset value) {
    if (_viewSize.isEmpty) return Offset.zero;
    return Offset(
      value.dx * widget.frame.width / _viewSize.width,
      value.dy * widget.frame.height / _viewSize.height,
    );
  }

  Rect _toPixelRect(Rect value) {
    final topLeft = _toPixel(value.topLeft);
    final bottomRight = _toPixel(value.bottomRight);
    final left = topLeft.dx.floor().clamp(0, widget.frame.width - 1);
    final top = topLeft.dy.floor().clamp(0, widget.frame.height - 1);
    final right = bottomRight.dx.ceil().clamp(left + 1, widget.frame.width);
    final bottom = bottomRight.dy.ceil().clamp(top + 1, widget.frame.height);
    return Rect.fromLTRB(
      left.toDouble(),
      top.toDouble(),
      right.toDouble(),
      bottom.toDouble(),
    );
  }

  Color _colorAt(Offset pixel) {
    final data = _pixels;
    final image = _decodedImage;
    if (data == null || image == null) return Colors.transparent;
    final x = pixel.dx.floor().clamp(0, image.width - 1);
    final y = pixel.dy.floor().clamp(0, image.height - 1);
    final offset = (y * image.width + x) * 4;
    return Color.fromARGB(
      data.getUint8(offset + 3),
      data.getUint8(offset),
      data.getUint8(offset + 1),
      data.getUint8(offset + 2),
    );
  }

  String _hexAt(Offset pixel) {
    final color = _colorAt(pixel);
    if (_pixels == null) return '#------';
    String byte(int value) => value.toRadixString(16).padLeft(2, '0');
    return '#${byte((color.r * 255).round())}'
            '${byte((color.g * 255).round())}'
            '${byte((color.b * 255).round())}'
        .toUpperCase();
  }
}

enum _DragMode {
  newSelection,
  move,
  left,
  right,
  top,
  bottom,
  topLeft,
  topRight,
  bottomLeft,
  bottomRight;

  bool get adjustsLeft =>
      this == _DragMode.left ||
      this == _DragMode.topLeft ||
      this == _DragMode.bottomLeft;
  bool get adjustsRight =>
      this == _DragMode.right ||
      this == _DragMode.topRight ||
      this == _DragMode.bottomRight;
  bool get adjustsTop =>
      this == _DragMode.top ||
      this == _DragMode.topLeft ||
      this == _DragMode.topRight;
  bool get adjustsBottom =>
      this == _DragMode.bottom ||
      this == _DragMode.bottomLeft ||
      this == _DragMode.bottomRight;
}

class _SelectionPainter extends CustomPainter {
  const _SelectionPainter({
    required this.selection,
    required this.windowHighlight,
    required this.cursor,
  });

  final Rect? selection;
  final Rect? windowHighlight;
  final Offset cursor;

  @override
  void paint(Canvas canvas, Size size) {
    final selected = selection;
    if (selected == null) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()..color = const Color(0x66000000),
      );
      if (windowHighlight case final highlight?) {
        canvas.drawRect(
          highlight,
          Paint()
            ..color = const Color(0xFF00D084)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      }
    } else {
      final shade = Path()
        ..fillType = PathFillType.evenOdd
        ..addRect(Offset.zero & size)
        ..addRect(selected);
      canvas.drawPath(shade, Paint()..color = const Color(0x99000000));
      canvas.drawRect(
        selected,
        Paint()
          ..color = const Color(0xFF36D590)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
      for (final point in [
        selected.topLeft,
        selected.topCenter,
        selected.topRight,
        selected.centerLeft,
        selected.centerRight,
        selected.bottomLeft,
        selected.bottomCenter,
        selected.bottomRight,
      ]) {
        canvas.drawCircle(point, 4.5, Paint()..color = const Color(0xFF36D590));
        canvas.drawCircle(
          point,
          4.5,
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1,
        );
      }
    }

    final crosshair = Paint()
      ..color = const Color(0xCCFFFFFF)
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(cursor.dx - 10, cursor.dy),
      Offset(cursor.dx + 10, cursor.dy),
      crosshair,
    );
    canvas.drawLine(
      Offset(cursor.dx, cursor.dy - 10),
      Offset(cursor.dx, cursor.dy + 10),
      crosshair,
    );
  }

  @override
  bool shouldRepaint(covariant _SelectionPainter oldDelegate) =>
      oldDelegate.selection != selection ||
      oldDelegate.windowHighlight != windowHighlight ||
      oldDelegate.cursor != cursor;
}

class _SelectionHint extends StatelessWidget {
  const _SelectionHint();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0xCC11151C),
          borderRadius: BorderRadius.circular(7),
        ),
        child: const Text(
          'Hover a window to highlight it  •  click to capture  •  drag for a region  •  Esc to cancel',
          style: TextStyle(color: Color(0xFFD7DCE5), fontSize: 11),
        ),
      ),
    );
  }
}
