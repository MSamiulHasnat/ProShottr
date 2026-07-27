import 'dart:typed_data';
import 'dart:ui' as ui;

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
    final codec = await ui.instantiateImageCodec(widget.imageBytes);
    final frame = await codec.getNextFrame();
    codec.dispose();
    final pixels = await frame.image.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    );
    if (!mounted) {
      frame.image.dispose();
      return;
    }
    _decodedImage?.dispose();
    setState(() {
      _decodedImage = frame.image;
      _pixels = pixels;
    });
  }

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
              child: RepaintBoundary(
                key: widget.exportKey,
                child: SizedBox(
                  width: widget.imageSize.width,
                  height: widget.imageSize.height,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.memory(
                        widget.imageBytes,
                        fit: BoxFit.fill,
                        gaplessPlayback: true,
                        filterQuality: FilterQuality.medium,
                      ),
                      AnimatedBuilder(
                        animation: widget.controller,
                        builder: (context, child) => Listener(
                          behavior: HitTestBehavior.opaque,
                          onPointerDown: _pointerDown,
                          onPointerMove: _pointerMove,
                          onPointerUp: _pointerUp,
                          onPointerCancel: _pointerCancel,
                          child: CustomPaint(
                            painter: AnnotationPainter(
                              annotations: widget.controller.annotations,
                              revision: widget.controller.revision,
                              draft: widget.controller.draft,
                              imagePixels: _pixels,
                              imageSize: widget.imageSize,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _pointerDown(PointerDownEvent event) {
    if (_activePointer != null) return;
    if (widget.controller.tool == EditorTool.text) {
      widget.onTextRequested(event.localPosition);
      return;
    }
    if (widget.controller.tool == EditorTool.sticker) {
      widget.controller.addSticker(event.localPosition);
      return;
    }
    _activePointer = event.pointer;
    widget.controller.beginStroke(event.localPosition);
  }

  void _pointerMove(PointerMoveEvent event) {
    if (_activePointer != event.pointer) return;
    widget.controller.updateStroke(event.localPosition);
  }

  void _pointerUp(PointerUpEvent event) {
    if (_activePointer != event.pointer) return;
    _activePointer = null;
    widget.controller.endStroke();
  }

  void _pointerCancel(PointerCancelEvent event) {
    if (_activePointer != event.pointer) return;
    _activePointer = null;
    widget.controller.endStroke();
  }
}
