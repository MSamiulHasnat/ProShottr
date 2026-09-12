import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'annotation_painter.dart';
import 'editor_controller.dart';
import 'editor_models.dart';

class EditorCanvas extends StatefulWidget {
  const EditorCanvas({
    super.key,
    required this.imageBytes,
    required this.imageSize,
    required this.controller,
    required this.exportKey,
    required this.onTextRequested,
    this.canvasPadding = const EdgeInsets.all(24),
    this.backgroundColor = const Color(0xFF11151C),
  });

  final Uint8List imageBytes;
  final Size imageSize;
  final EditorController controller;
  final GlobalKey exportKey;
  final Future<void> Function(Offset point) onTextRequested;
  final EdgeInsetsGeometry canvasPadding;
  final Color backgroundColor;

  @override
  State<EditorCanvas> createState() => _EditorCanvasState();
}

class _EditorCanvasState extends State<EditorCanvas> {
  int? _activePointer;
  ui.Image? _decodedImage;
  ByteData? _pixels;
  int _decodeGeneration = 0;

  @override
  void initState() {
    super.initState();
    _decodeImage();
  }

  @override
  void didUpdateWidget(covariant EditorCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.imageBytes, widget.imageBytes)) _decodeImage();
  }

  @override
  void dispose() {
    _decodedImage?.dispose();
    super.dispose();
  }

  Future<void> _decodeImage() async {
    final generation = ++_decodeGeneration;
    final codec = await ui.instantiateImageCodec(widget.imageBytes);
    final frame = await codec.getNextFrame();
    codec.dispose();
    final pixels = await frame.image.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    );
    if (!mounted || generation != _decodeGeneration) {
      frame.image.dispose();
      return;
    }
    _decodedImage?.dispose();
    setState(() {
      _decodedImage = frame.image;
      _pixels = pixels;
    });
  }

  /// The part of the source image that is shown and exported: the crop when
  /// one is set, otherwise the whole image.
  Rect get _visible =>
      widget.controller.crop ?? (Offset.zero & widget.imageSize);

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: ColoredBox(
        color: widget.backgroundColor,
        child: Padding(
          padding: widget.canvasPadding,
          child: Center(
            child: FittedBox(
              fit: BoxFit.contain,
              child: AnimatedBuilder(
                animation: widget.controller,
                child: Image.memory(
                  widget.imageBytes,
                  fit: BoxFit.fill,
                  gaplessPlayback: true,
                  filterQuality: FilterQuality.medium,
                ),
                builder: (context, image) {
                  final visible = _visible;
                  // The export boundary is exactly the visible region, in
                  // physical source pixels. The full image and every
                  // annotation keep their source coordinates underneath it
                  // and are shifted so the crop's corner sits at the origin.
                  return RepaintBoundary(
                    key: widget.exportKey,
                    child: SizedBox(
                      width: visible.width,
                      height: visible.height,
                      child: ClipRect(
                        child: OverflowBox(
                          alignment: Alignment.topLeft,
                          minWidth: widget.imageSize.width,
                          maxWidth: widget.imageSize.width,
                          minHeight: widget.imageSize.height,
                          maxHeight: widget.imageSize.height,
                          child: Transform.translate(
                            offset: -visible.topLeft,
                            child: SizedBox(
                              width: widget.imageSize.width,
                              height: widget.imageSize.height,
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  image!,
                                  Listener(
                                    behavior: HitTestBehavior.opaque,
                                    onPointerDown: _pointerDown,
                                    onPointerMove: _pointerMove,
                                    onPointerUp: _pointerUp,
                                    onPointerCancel: _pointerCancel,
                                    child: CustomPaint(
                                      painter: AnnotationPainter(
                                        annotations:
                                            widget.controller.annotations,
                                        revision: widget.controller.revision,
                                        draft: widget.controller.draft,
                                        imagePixels: _pixels,
                                        imageSize: widget.imageSize,
                                      ),
                                      foregroundPainter:
                                          widget.controller.tool ==
                                              EditorTool.crop
                                          ? _CropPainter(
                                              visible: visible,
                                              pending:
                                                  widget.controller.pendingCrop,
                                            )
                                          : null,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  bool get _cropping => widget.controller.tool == EditorTool.crop;

  /// A crop can only be drawn inside the region that is currently visible.
  Offset _cropPoint(Offset position) {
    final visible = _visible;
    return Offset(
      position.dx.clamp(visible.left, visible.right),
      position.dy.clamp(visible.top, visible.bottom),
    );
  }

  void _pointerDown(PointerDownEvent event) {
    if (_activePointer != null || event.buttons != kPrimaryButton) return;
    if (widget.controller.tool == EditorTool.text) {
      widget.onTextRequested(event.localPosition);
      return;
    }
    if (widget.controller.tool == EditorTool.sticker) {
      widget.controller.addSticker(event.localPosition);
      return;
    }
    _activePointer = event.pointer;
    widget.controller.beginStroke(
      _cropping ? _cropPoint(event.localPosition) : event.localPosition,
    );
  }

  void _pointerMove(PointerMoveEvent event) {
    if (_activePointer != event.pointer) return;
    widget.controller.updateStroke(
      _cropping ? _cropPoint(event.localPosition) : event.localPosition,
    );
  }

  void _pointerUp(PointerUpEvent event) {
    if (_activePointer != event.pointer) return;
    _activePointer = null;
    widget.controller.endStroke();
  }

  void _pointerCancel(PointerCancelEvent event) {
    if (_activePointer != event.pointer) return;
    _activePointer = null;
    widget.controller.cancelStroke();
  }
}

/// Shows the pending crop while the crop tool is armed: the region outside
/// the drag is washed out and the drag carries its size in physical pixels.
class _CropPainter extends CustomPainter {
  const _CropPainter({required this.visible, required this.pending});

  final Rect visible;
  final Rect? pending;

  @override
  void paint(Canvas canvas, Size size) {
    final target = pending;
    if (target == null || target.isEmpty) return;

    final wash = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(visible)
      ..addRect(target);
    canvas.drawPath(wash, Paint()..color = const Color(0x8C000000));
    canvas.drawRect(
      target,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    final label = TextPainter(
      text: TextSpan(
        text: '${target.width.round()} × ${target.height.round()}',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          shadows: [Shadow(color: Color(0xCC000000), blurRadius: 3)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final labelOffset = Offset(
      target.left.clamp(visible.left, visible.right - label.width),
      (target.top - label.height - 4).clamp(
        visible.top,
        visible.bottom - label.height,
      ),
    );
    label.paint(canvas, labelOffset);
    label.dispose();
  }

  @override
  bool shouldRepaint(covariant _CropPainter oldDelegate) =>
      oldDelegate.visible != visible || oldDelegate.pending != pending;
}
