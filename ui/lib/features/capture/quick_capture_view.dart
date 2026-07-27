import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:proshottr/src/rust/capture.dart';

import '../editor/editor_canvas.dart';
import '../editor/editor_controller.dart';
import '../editor/editor_models.dart';

const quickPalette = <Color>[
  Color(0xFF2788F5),
  Color(0xFF28B86F),
  Color(0xFFF2C94C),
  Color(0xFF8B939F),
  Color(0xFFFFFFFF),
  Color(0xFFE9435B),
];

const quickStrokeWidths = <double>[2, 5, 9];
const quickTextSizes = <double>[20, 32, 48];

class QuickCaptureView extends StatefulWidget {
  const QuickCaptureView({
    super.key,
    required this.frame,
    required this.desktopFrame,
    required this.normalizedSelection,
    required this.controller,
    required this.exportKey,
    required this.busy,
    required this.onTextRequested,
    required this.onCancel,
    required this.onDone,
    required this.onSave,
    required this.onOpenEditor,
  });

  final CapturedFrame frame;
  final CapturedFrame desktopFrame;
  final Rect normalizedSelection;
  final EditorController controller;
  final GlobalKey exportKey;
  final bool busy;
  final Future<void> Function(Offset point) onTextRequested;
  final VoidCallback onCancel;
  final VoidCallback onDone;
  final VoidCallback onSave;
  final VoidCallback onOpenEditor;

  @override
  State<QuickCaptureView> createState() => _QuickCaptureViewState();
}

class _QuickCaptureViewState extends State<QuickCaptureView> {
  final List<String> _recentStickers = [];

  static const _tools = <(EditorTool, IconData, String)>[
    (EditorTool.rectangle, Icons.crop_square_rounded, 'Filled rectangle'),
    (EditorTool.ellipse, Icons.circle_outlined, 'Outline ellipse'),
    (EditorTool.sticker, Icons.emoji_emotions_outlined, 'Sticker'),
    (EditorTool.arrow, Icons.north_east_rounded, 'Arrow'),
    (EditorTool.pen, Icons.draw_rounded, 'Brush'),
    (EditorTool.mosaic, Icons.grid_on_rounded, 'Mosaic'),
    (EditorTool.text, Icons.title_rounded, 'Text'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest;
          final selection = Rect.fromLTRB(
            widget.normalizedSelection.left * size.width,
            widget.normalizedSelection.top * size.height,
            widget.normalizedSelection.right * size.width,
            widget.normalizedSelection.bottom * size.height,
          ).intersect(Offset.zero & size);
          const toolbarHeight = 58.0;
          final toolbarWidth = math
              .min(
                size.width - 20,
                math.max(620, math.min(1000, selection.width + 180)),
              )
              .toDouble();
          final toolbarLeft = (selection.center.dx - toolbarWidth / 2)
              .clamp(10, size.width - toolbarWidth - 10)
              .toDouble();
          final fitsBelow = selection.bottom + toolbarHeight + 18 < size.height;
          final toolbarTop =
              (fitsBelow
                      ? selection.bottom + 10
                      : selection.top - toolbarHeight - 10)
                  .clamp(10, size.height - toolbarHeight - 10)
                  .toDouble();
          final labelTop = selection.top >= 28
              ? selection.top - 26
              : selection.top + 6;

          return Stack(
            fit: StackFit.expand,
            children: [
              RepaintBoundary(
                child: Image.memory(
                  widget.desktopFrame.pngBytes,
                  fit: BoxFit.fill,
                  gaplessPlayback: true,
                  filterQuality: FilterQuality.low,
                ),
              ),
              Positioned.fromRect(
                rect: selection,
                child: EditorCanvas(
                  imageBytes: widget.frame.pngBytes,
                  imageSize: Size(
                    widget.frame.width.toDouble(),
                    widget.frame.height.toDouble(),
                  ),
                  controller: widget.controller,
                  exportKey: widget.exportKey,
                  onTextRequested: widget.onTextRequested,
                  canvasPadding: EdgeInsets.zero,
                  backgroundColor: Colors.transparent,
                ),
              ),
              IgnorePointer(
                child: CustomPaint(
                  painter: _FrozenSelectionPainter(selection: selection),
                ),
              ),
              Positioned(
                left: selection.left,
                top: labelTop,
                child: _DimensionLabel(
                  width: widget.frame.width,
                  height: widget.frame.height,
                ),
              ),
              Positioned(
                left: toolbarLeft,
                top: toolbarTop,
                width: toolbarWidth,
                height: toolbarHeight,
                child: _buildQuickHud(),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildQuickHud() {
    return Material(
      color: const Color(0xFA161B23),
      borderRadius: BorderRadius.circular(11),
      elevation: 20,
      child: AnimatedBuilder(
        animation: widget.controller,
        builder: (context, child) => ClipRRect(
          borderRadius: BorderRadius.circular(11),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              children: [
                for (final (tool, icon, label) in _tools)
                  Padding(
                    padding: const EdgeInsets.only(right: 3),
                    child: IconButton.filledTonal(
                      isSelected: widget.controller.tool == tool,
                      tooltip: label,
                      onPressed: () => _selectTool(tool),
                      icon: Icon(icon, size: 20),
                    ),
                  ),
                _divider(),
                if (widget.controller.tool == EditorTool.text)
                  _buildTextSizes()
                else if (widget.controller.tool == EditorTool.sticker)
                  _buildStickerControl()
                else
                  _buildStrokeWidths(),
                const SizedBox(width: 8),
                _buildColors(),
                _divider(),
                IconButton(
                  tooltip: 'Undo (Ctrl+Z)',
                  onPressed: widget.controller.canUndo && !widget.busy
                      ? widget.controller.undo
                      : null,
                  icon: const Icon(Icons.undo_rounded),
                ),
                IconButton(
                  tooltip: 'Redo (Ctrl+Y)',
                  onPressed: widget.controller.canRedo && !widget.busy
                      ? widget.controller.redo
                      : null,
                  icon: const Icon(Icons.redo_rounded),
                ),
                IconButton(
                  tooltip: 'Save as PNG (Ctrl+S)',
                  onPressed: widget.busy ? null : widget.onSave,
                  icon: const Icon(Icons.save_alt_rounded),
                ),
                IconButton(
                  tooltip: 'Open Pro editor',
                  onPressed: widget.busy ? null : widget.onOpenEditor,
                  icon: const Icon(Icons.tune_rounded),
                ),
                IconButton(
                  tooltip: 'Cancel (Esc)',
                  onPressed: widget.busy ? null : widget.onCancel,
                  icon: const Icon(
                    Icons.close_rounded,
                    color: Color(0xFFFF5B72),
                  ),
                ),
                IconButton(
                  tooltip: 'Done — copy to clipboard',
                  onPressed: widget.busy ? null : widget.onDone,
                  icon: widget.busy
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(
                          Icons.check_rounded,
                          color: Color(0xFF36D590),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _divider() => Container(
    width: 1,
    height: 30,
    margin: const EdgeInsets.symmetric(horizontal: 8),
    color: const Color(0xFF343D4C),
  );

  Widget _buildStrokeWidths() => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (final width in quickStrokeWidths)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: _PresetButton(
            selected: widget.controller.strokeWidth == width,
            tooltip: '${width.round()} px',
            onPressed: () => widget.controller.setStrokeWidth(width),
            child: Container(
              width: width + 4,
              height: width + 4,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
    ],
  );

  Widget _buildTextSizes() => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (final size in quickTextSizes)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: _PresetButton(
            selected: widget.controller.fontSize == size,
            tooltip: '${size.round()} px text',
            onPressed: () => widget.controller.setFontSize(size),
            child: Text(
              'A',
              style: TextStyle(
                fontSize: 11 + quickTextSizes.indexOf(size) * 3,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
    ],
  );

  Widget _buildStickerControl() => OutlinedButton.icon(
    onPressed: _chooseSticker,
    icon: Text(widget.controller.sticker, style: const TextStyle(fontSize: 18)),
    label: const Text('Choose'),
  );

  Widget _buildColors() => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (final color in quickPalette)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: Tooltip(
            message: _colorName(color),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => widget.controller.setColor(color),
              child: Container(
                width: 25,
                height: 25,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: widget.controller.color == color
                        ? const Color(0xFF36D590)
                        : const Color(0xFF505A69),
                    width: widget.controller.color == color ? 3 : 1,
                  ),
                ),
              ),
            ),
          ),
        ),
    ],
  );

  void _selectTool(EditorTool tool) {
    if (tool == EditorTool.sticker) {
      _chooseSticker();
    } else {
      widget.controller.selectTool(tool);
    }
  }

  Future<void> _chooseSticker() async {
    final value = await showDialog<String>(
      context: context,
      builder: (context) => _StickerPickerDialog(recents: _recentStickers),
    );
    if (value == null) return;
    setState(() {
      _recentStickers
        ..remove(value)
        ..insert(0, value);
      if (_recentStickers.length > 12) _recentStickers.removeLast();
    });
    widget.controller.setSticker(value);
  }

  String _colorName(Color color) => switch (quickPalette.indexOf(color)) {
    0 => 'Blue',
    1 => 'Green',
    2 => 'Yellow',
    3 => 'Grey',
    4 => 'White',
    _ => 'Red',
  };
}

class _PresetButton extends StatelessWidget {
  const _PresetButton({
    required this.selected,
    required this.tooltip,
    required this.onPressed,
    required this.child,
  });

  final bool selected;
  final String tooltip;
  final VoidCallback onPressed;
  final Widget child;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF334657) : Colors.transparent,
          shape: BoxShape.circle,
          border: selected ? Border.all(color: const Color(0xFF36D590)) : null,
        ),
        child: child,
      ),
    ),
  );
}

class _StickerPickerDialog extends StatefulWidget {
  const _StickerPickerDialog({required this.recents});

  final List<String> recents;

  @override
  State<_StickerPickerDialog> createState() => _StickerPickerDialogState();
}

class _StickerPickerDialogState extends State<_StickerPickerDialog> {
  int _category = 0;

  static const categories = <(String, List<String>)>[
    (
      'Faces',
      ['😀', '😂', '🥰', '😎', '🤔', '😭', '😡', '🥳', '🤯', '😴', '🤩', '🫡'],
    ),
    (
      'Hearts',
      ['❤️', '🧡', '💛', '💚', '💙', '💜', '🖤', '🤍', '💖', '💔', '💕', '💯'],
    ),
    (
      'Hands',
      ['👍', '👎', '👏', '🙏', '🤝', '✌️', '🤞', '👌', '👋', '💪', '☝️', '🙌'],
    ),
    (
      'Objects',
      ['⭐', '🔥', '🎉', '✅', '❌', '⚠️', '📌', '💡', '🚀', '🎯', '🏆', '🔒'],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final stickers = categories[_category].$2;
    return AlertDialog(
      title: const Text('Stickers'),
      content: SizedBox(
        width: 390,
        height: widget.recents.isEmpty ? 270 : 350,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.recents.isNotEmpty) ...[
              const Text(
                'RECENT',
                style: TextStyle(fontSize: 11, color: Color(0xFF9DA7B8)),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 50,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final emoji in widget.recents)
                      _StickerButton(emoji: emoji),
                  ],
                ),
              ),
              const Divider(height: 24),
            ],
            const Text(
              'ALL STICKERS',
              style: TextStyle(fontSize: 11, color: Color(0xFF9DA7B8)),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: GridView.count(
                crossAxisCount: 6,
                children: [
                  for (final emoji in stickers) _StickerButton(emoji: emoji),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var index = 0; index < categories.length; index++)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      label: Text(categories[index].$1),
                      selected: _category == index,
                      onSelected: (_) => setState(() => _category = index),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

class _StickerButton extends StatelessWidget {
  const _StickerButton({required this.emoji});

  final String emoji;

  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(10),
    onTap: () => Navigator.pop(context, emoji),
    child: Center(child: Text(emoji, style: const TextStyle(fontSize: 29))),
  );
}

class _FrozenSelectionPainter extends CustomPainter {
  const _FrozenSelectionPainter({required this.selection});

  final Rect selection;

  @override
  void paint(Canvas canvas, Size size) {
    final shade = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRect(selection);
    canvas.drawPath(shade, Paint()..color = const Color(0xA6000000));
    canvas.drawRect(
      selection,
      Paint()
        ..color = const Color(0xFF00D084)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    for (final point in [
      selection.topLeft,
      selection.topCenter,
      selection.topRight,
      selection.centerLeft,
      selection.centerRight,
      selection.bottomLeft,
      selection.bottomCenter,
      selection.bottomRight,
    ]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: point, width: 10, height: 10),
          const Radius.circular(2),
        ),
        Paint()..color = const Color(0xFF00D084),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _FrozenSelectionPainter oldDelegate) =>
      oldDelegate.selection != selection;
}

class _DimensionLabel extends StatelessWidget {
  const _DimensionLabel({required this.width, required this.height});

  final int width;
  final int height;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xE611151C),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '$width × $height',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  );
}
