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
    this.onPin,
    this.onShare,
    this.onExtractText,
    this.onTranslate,
    this.onScrollingCapture,
    this.onTogglePixelUnits,
    this.hasTextContent = false,
    this.showLogicalPixels = false,
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
  final VoidCallback? onPin;
  final VoidCallback? onShare;
  final VoidCallback? onExtractText;
  final VoidCallback? onTranslate;
  final VoidCallback? onScrollingCapture;
  final VoidCallback? onTogglePixelUnits;
  final bool hasTextContent;
  final bool showLogicalPixels;

  @override
  State<QuickCaptureView> createState() => _QuickCaptureViewState();
}

class _QuickCaptureViewState extends State<QuickCaptureView> {
  final List<String> _recentStickers = [];

  static const _tools = <(EditorTool, IconData, String)>[
    (EditorTool.rectangle, Icons.crop_square_rounded, 'Filled rectangle (R)'),
    (EditorTool.ellipse, Icons.circle_outlined, 'Outline ellipse (E)'),
    (EditorTool.sticker, Icons.emoji_emotions_outlined, 'Sticker (S)'),
    (EditorTool.arrow, Icons.north_east_rounded, 'Arrow (A)'),
    (EditorTool.pen, Icons.draw_rounded, 'Brush (P)'),
    (EditorTool.mosaic, Icons.grid_on_rounded, 'Mosaic (M)'),
    (EditorTool.text, Icons.title_rounded, 'Text (T)'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest;
          final captured = Rect.fromLTRB(
            widget.normalizedSelection.left * size.width,
            widget.normalizedSelection.top * size.height,
            widget.normalizedSelection.right * size.width,
            widget.normalizedSelection.bottom * size.height,
          ).intersect(Offset.zero & size);
          return AnimatedBuilder(
            animation: widget.controller,
            child: RepaintBoundary(
              child: Image.memory(
                widget.desktopFrame.pngBytes,
                fit: BoxFit.fill,
                gaplessPlayback: true,
                filterQuality: FilterQuality.low,
              ),
            ),
            builder: (context, desktop) {
              // A crop keeps the frozen desktop in place and shrinks the
              // un-dimmed region, badge, and toolbar anchor to the crop.
              final crop = widget.controller.crop;
              final selection = _cropToView(captured, crop);
              final layout = _HudLayout(size, selection);
              final scale = widget.frame.scaleFactor > 0
                  ? widget.frame.scaleFactor
                  : 1.0;
              final divisor = widget.showLogicalPixels ? scale : 1.0;
              final suffix = (scale - 1).abs() < 0.001
                  ? ''
                  : ' @${scale.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '')}x';
              final raster = widget.controller.pendingCrop ?? crop;
              final rasterWidth =
                  raster?.width ?? widget.frame.width.toDouble();
              final rasterHeight =
                  raster?.height ?? widget.frame.height.toDouble();
              final dimensions =
                  '${(rasterWidth / divisor).round()} × '
                  '${(rasterHeight / divisor).round()}$suffix';
              final labelPainter = TextPainter(
                text: TextSpan(text: dimensions, style: _dimensionStyle),
                textDirection: TextDirection.ltr,
              )..layout();
              final labelWidth = math.min(size.width, labelPainter.width + 14);
              labelPainter.dispose();
              final labelTop = selection.top >= 28
                  ? selection.top - 26
                  : selection.top + 6;

              return Stack(
                fit: StackFit.expand,
                children: [
                  desktop!,
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
                    left: selection.left.clamp(0, size.width - labelWidth),
                    top: labelTop.clamp(0, math.max(0, size.height - 24)),
                    width: labelWidth,
                    child: _DimensionLabel(text: dimensions),
                  ),
                  Positioned.fromRect(
                    rect: layout.bounds,
                    child: Opacity(
                      opacity: layout.overlapsSelection ? 0.84 : 1,
                      child: _buildQuickHud(layout),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  /// Maps a crop in source pixels onto the on-screen rectangle of the capture.
  Rect _cropToView(Rect captured, Rect? crop) {
    if (crop == null || widget.frame.width <= 0 || widget.frame.height <= 0) {
      return captured;
    }
    final scaleX = captured.width / widget.frame.width;
    final scaleY = captured.height / widget.frame.height;
    return Rect.fromLTWH(
      captured.left + crop.left * scaleX,
      captured.top + crop.top * scaleY,
      crop.width * scaleX,
      crop.height * scaleY,
    );
  }

  Widget _buildQuickHud(_HudLayout layout) => Material(
    key: const ValueKey('quick-hud'),
    color: const Color(0xFA161B23),
    borderRadius: BorderRadius.circular(11),
    elevation: 20,
    child: AnimatedBuilder(
      animation: widget.controller,
      builder: (context, child) {
        final content = _contentActions();
        final output = _outputActions();
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 50,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    for (final (tool, icon, label) in _tools)
                      SizedBox.square(
                        dimension: layout.buttonSize,
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          isSelected: widget.controller.tool == tool,
                          style: IconButton.styleFrom(
                            backgroundColor: widget.controller.tool == tool
                                ? const Color(0xFF334657)
                                : Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(7),
                            ),
                          ),
                          tooltip: widget.busy
                              ? '$label — Finishing current action'
                              : label,
                          onPressed: widget.busy
                              ? null
                              : () => _selectTool(tool),
                          icon: Icon(icon, size: 20),
                        ),
                      ),
                    if (!layout.collapseContent) ...[
                      _divider(),
                      for (final action in content)
                        _actionButton(action, layout.buttonSize),
                    ],
                    _divider(),
                    if (!layout.collapseOutput)
                      for (final action in output)
                        _actionButton(action, layout.buttonSize),
                    _overflowButton(layout, [
                      if (layout.collapseContent) ...content,
                      if (layout.collapseOutput) ...output,
                      _HudAction(
                        'Crop',
                        Icons.crop_rounded,
                        () => _selectTool(EditorTool.crop),
                        shortcut: 'C',
                      ),
                      if (widget.controller.crop != null)
                        _HudAction(
                          'Reset crop',
                          Icons.crop_free_rounded,
                          () => widget.controller.setCrop(null),
                          shortcut: 'Shift+C',
                        ),
                      if (widget.onTogglePixelUnits != null)
                        _HudAction(
                          widget.showLogicalPixels
                              ? 'Show physical pixels'
                              : 'Show logical pixels',
                          Icons.straighten_rounded,
                          widget.onTogglePixelUnits,
                        ),
                      _HudAction(
                        'Open Pro editor',
                        Icons.tune_rounded,
                        widget.onOpenEditor,
                        shortcut: 'Tab',
                      ),
                    ]),
                    _divider(),
                    _actionButton(
                      _HudAction(
                        'Cancel',
                        Icons.close_rounded,
                        widget.onCancel,
                        shortcut: 'Esc',
                        color: const Color(0xFFFF5B72),
                      ),
                      layout.buttonSize,
                    ),
                    _actionButton(
                      _HudAction(
                        'Confirm and copy',
                        Icons.check_rounded,
                        widget.onDone,
                        shortcut: 'Enter',
                        color: const Color(0xFF36D590),
                      ),
                      layout.buttonSize,
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 1, color: Color(0xFF343D4C)),
            SizedBox(
              height: 43,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: _buildStyleControls(),
                ),
              ),
            ),
          ],
        );
      },
    ),
  );

  List<_HudAction> _contentActions() => [
    _HudAction(
      'Translate',
      Icons.translate_rounded,
      widget.hasTextContent ? widget.onTranslate : null,
      disabledReason: widget.onTranslate == null
          ? 'No translation provider configured'
          : 'No text detected in this capture',
    ),
    _HudAction(
      'Extract text (OCR)',
      Icons.text_snippet_outlined,
      widget.hasTextContent ? widget.onExtractText : null,
      disabledReason: widget.onExtractText == null
          ? 'Text recognition is not available on this platform'
          : 'No text detected in this capture',
    ),
    _HudAction(
      'Scrolling capture',
      Icons.unfold_more_rounded,
      widget.onScrollingCapture,
      disabledReason: 'Scrolling capture is not available yet',
    ),
  ];

  List<_HudAction> _outputActions() => [
    _HudAction(
      'Undo',
      Icons.undo_rounded,
      widget.controller.canUndo ? widget.controller.undo : null,
      shortcut: 'Ctrl+Z',
      disabledReason: 'No annotations to undo',
    ),
    _HudAction(
      'Redo',
      Icons.redo_rounded,
      widget.controller.canRedo ? widget.controller.redo : null,
      shortcut: 'Ctrl+Y / Ctrl+Shift+Z',
      disabledReason: 'No changes to redo',
    ),
    _HudAction(
      'Save as PNG',
      Icons.save_alt_rounded,
      widget.onSave,
      shortcut: 'Ctrl+S',
    ),
    _HudAction(
      'Pin to desktop',
      Icons.push_pin_outlined,
      widget.onPin,
      shortcut: 'Ctrl+P',
      disabledReason: 'Pin windows are not available on this platform',
    ),
    _HudAction(
      'Share / send',
      Icons.ios_share_rounded,
      widget.onShare,
      shortcut: 'Ctrl+Enter',
      disabledReason: 'Sharing is not available on this platform',
    ),
  ];

  Widget _actionButton(_HudAction action, double size) => SizedBox.square(
    dimension: size,
    child: IconButton(
      padding: EdgeInsets.zero,
      tooltip: action.tooltip(widget.busy),
      onPressed: widget.busy ? null : action.onPressed,
      icon: Icon(action.icon, size: 20, color: action.color),
    ),
  );

  Widget _overflowButton(_HudLayout layout, List<_HudAction> actions) =>
      SizedBox.square(
        dimension: layout.buttonSize,
        child: PopupMenuButton<int>(
          key: const ValueKey('quick-hud-overflow'),
          tooltip: 'More tools',
          icon: const Icon(Icons.more_horiz_rounded, size: 20),
          padding: EdgeInsets.zero,
          position: PopupMenuPosition.under,
          onSelected: (index) => actions[index].onPressed?.call(),
          itemBuilder: (context) => [
            for (var index = 0; index < actions.length; index++)
              PopupMenuItem<int>(
                value: index,
                enabled: !widget.busy && actions[index].onPressed != null,
                child: Tooltip(
                  message: actions[index].tooltip(widget.busy),
                  child: Row(
                    children: [
                      Icon(actions[index].icon, size: 19),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(actions[index].label),
                            if (actions[index].onPressed == null || widget.busy)
                              Text(
                                widget.busy
                                    ? 'Finishing current action'
                                    : actions[index].disabledReason,
                                style: const TextStyle(fontSize: 10),
                              )
                            else if (actions[index].shortcut != null)
                              Text(
                                actions[index].shortcut!,
                                style: const TextStyle(fontSize: 10),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      );

  Widget _buildStyleControls() => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (widget.controller.tool == EditorTool.crop) ...[
        const Text(
          'Drag inside the capture to crop',
          style: TextStyle(fontSize: 12),
        ),
        const SizedBox(width: 10),
        OutlinedButton.icon(
          onPressed: widget.controller.crop == null
              ? null
              : () => widget.controller.setCrop(null),
          icon: const Icon(Icons.crop_free_rounded, size: 16),
          label: const Text('Reset crop'),
        ),
      ] else if (widget.controller.tool == EditorTool.sticker)
        OutlinedButton.icon(
          onPressed: _chooseSticker,
          icon: Text(
            widget.controller.sticker,
            style: const TextStyle(fontSize: 18),
          ),
          label: const Text('Choose sticker'),
        )
      else ...[
        if (widget.controller.tool == EditorTool.text)
          _buildTextSizes()
        else
          _buildStrokeWidths(),
        const SizedBox(width: 10),
        if (widget.controller.tool == EditorTool.mosaic)
          const Tooltip(
            message:
                'AI masking — automatic sensitive-content detection '
                'is not available yet. Draw to mask manually.',
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('AI masking', style: TextStyle(fontSize: 12)),
                SizedBox(width: 6),
                Switch(value: false, onChanged: null),
              ],
            ),
          )
        else
          _buildColors(),
      ],
    ],
  );

  Widget _divider() => Container(
    width: 1,
    height: 25,
    margin: const EdgeInsets.symmetric(horizontal: 6),
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
    widget.controller.selectTool(tool);
    if (tool == EditorTool.sticker) _chooseSticker();
  }

  Future<void> _chooseSticker() async {
    final value = await showDialog<String>(
      context: context,
      builder: (context) => _StickerPickerDialog(recents: _recentStickers),
    );
    if (value == null || !mounted) return;
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

class _HudAction {
  const _HudAction(
    this.label,
    this.icon,
    this.onPressed, {
    this.shortcut,
    this.disabledReason = '',
    this.color,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final String? shortcut;
  final String disabledReason;
  final Color? color;

  String tooltip(bool busy) {
    final title = shortcut == null ? label : '$label ($shortcut)';
    if (busy) return '$title — Finishing current action';
    return onPressed == null ? '$title — $disabledReason' : title;
  }
}

class _HudLayout {
  _HudLayout(Size display, Rect selection) {
    const height = 94.0;
    const fullWidth = 711.0;
    const withoutContentWidth = 590.0;
    const minimumWidth = 410.0;
    final available = math.max(0.0, display.width - 20);
    final comfortable = math.min(selection.width, available);
    collapseContent = comfortable < fullWidth;
    collapseOutput = comfortable < withoutContentWidth;
    final preferred = collapseOutput
        ? minimumWidth
        : collapseContent
        ? withoutContentWidth
        : fullWidth;
    final width = math.min(available, preferred);
    buttonSize = collapseOutput ? math.max(0, (width - 50) / 10) : 36;
    final left = (selection.center.dx - width / 2)
        .clamp(10.0, math.max(10.0, display.width - width - 10))
        .toDouble();
    final fitsBelow = selection.bottom + height + 10 <= display.height - 10;
    final fitsAbove = selection.top >= height + 20;
    overlapsSelection = !fitsBelow && !fitsAbove;
    final top = fitsBelow
        ? selection.bottom + 10
        : fitsAbove
        ? selection.top - height - 10
        : math.max(0.0, display.height - height - 12);
    bounds = Rect.fromLTWH(
      overlapsSelection ? math.max(10.0, display.width - width - 12) : left,
      top,
      width,
      height,
    );
  }

  late final Rect bounds;
  late final double buttonSize;
  late final bool collapseContent;
  late final bool collapseOutput;
  late final bool overlapsSelection;
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
      [
        '😀',
        '😂',
        '🥰',
        '😎',
        '🤔',
        '😭',
        '😡',
        '🥳',
        '🤯',
        '😴',
        '🤩',
        '🫡',
        '😅',
        '🙃',
        '😇',
        '🥹',
        '😱',
        '🤓',
        '😬',
        '🫠',
        '🤫',
        '🫣',
        '😮',
        '😍',
      ],
    ),
    (
      'Hearts',
      [
        '❤️',
        '🧡',
        '💛',
        '💚',
        '💙',
        '💜',
        '🖤',
        '🤍',
        '💖',
        '💔',
        '💕',
        '💯',
        '💗',
        '💓',
        '💞',
        '💘',
        '💝',
        '♥️',
      ],
    ),
    (
      'Hands',
      [
        '👍',
        '👎',
        '👏',
        '🙏',
        '🤝',
        '✌️',
        '🤞',
        '👌',
        '👋',
        '💪',
        '☝️',
        '🙌',
        '🤟',
        '🫶',
        '✋',
        '🤘',
        '👊',
        '👉',
      ],
    ),
    (
      'Objects',
      [
        '⭐',
        '🔥',
        '🎉',
        '✅',
        '❌',
        '⚠️',
        '📌',
        '💡',
        '🚀',
        '🎯',
        '🏆',
        '🔒',
        '📣',
        '🔔',
        '❓',
        '❗',
        '✨',
        '🎁',
        '☕',
        '💻',
        '📷',
        '📎',
        '📍',
        '⏰',
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) => Dialog(
    insetPadding: const EdgeInsets.all(20),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 440, maxHeight: 500),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Stickers',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                ),
                IconButton(
                  tooltip: 'Close stickers',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const Text(
              'RECENT',
              style: TextStyle(fontSize: 11, color: Color(0xFF9DA7B8)),
            ),
            const SizedBox(height: 8),
            if (widget.recents.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'Your recently used stickers appear here.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF9DA7B8)),
                ),
              )
            else
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final emoji in widget.recents)
                      SizedBox(width: 44, child: _StickerButton(emoji: emoji)),
                  ],
                ),
              ),
            const Divider(height: 24),
            Wrap(
              spacing: 6,
              children: [
                for (var index = 0; index < categories.length; index++)
                  ChoiceChip(
                    label: Text(categories[index].$1),
                    selected: _category == index,
                    onSelected: (_) => setState(() => _category = index),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: GridView.extent(
                maxCrossAxisExtent: 58,
                children: [
                  for (final emoji in categories[_category].$2)
                    _StickerButton(emoji: emoji),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _StickerButton extends StatelessWidget {
  const _StickerButton({required this.emoji});
  final String emoji;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Choose $emoji sticker',
    child: InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => Navigator.pop(context, emoji),
      child: Center(child: Text(emoji, style: const TextStyle(fontSize: 29))),
    ),
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
  }

  @override
  bool shouldRepaint(covariant _FrozenSelectionPainter oldDelegate) =>
      oldDelegate.selection != selection;
}

const _dimensionStyle = TextStyle(
  color: Colors.white,
  fontSize: 12,
  fontWeight: FontWeight.w600,
);

class _DimensionLabel extends StatelessWidget {
  const _DimensionLabel({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    key: const ValueKey('capture-resolution'),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xE611151C),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(text, style: _dimensionStyle, maxLines: 1),
    ),
  );
}
