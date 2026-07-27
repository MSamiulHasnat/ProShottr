import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:proshottr/src/rust/capture.dart';
import 'package:super_clipboard/super_clipboard.dart';

import '../../services/capture_service.dart';
import '../../services/windows_capture_window.dart';
import '../capture/capture_selection_overlay.dart';
import '../capture/quick_capture_view.dart';
import 'editor_canvas.dart';
import 'editor_controller.dart';
import 'editor_models.dart';

class EditorScreen extends StatefulWidget {
  const EditorScreen({
    super.key,
    this.captureService,
    this.captureWindowController,
  });

  final CaptureService? captureService;
  final CaptureWindowController? captureWindowController;

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  late final CaptureService _captureService;
  late final CaptureWindowController _captureWindow;
  final EditorController _controller = EditorController();
  final GlobalKey _exportKey = GlobalKey();
  CapturedFrame? _frame;
  CapturedFrame? _selectionFrame;
  Rect? _normalizedSelection;
  PlatformCapabilities? _capabilities;
  _SessionMode _mode = _SessionMode.editor;
  bool _busy = false;
  String _status = 'Ready';

  @override
  void initState() {
    super.initState();
    _captureService = widget.captureService ?? const NativeCaptureService();
    _captureWindow =
        widget.captureWindowController ?? WindowsCaptureWindowController();
    _captureWindow.setCaptureRequestedHandler(_capture);
    _captureWindow.setCaptureCancelledHandler(_cancelCaptureSession);
    _capabilities = _captureService.capabilities();
  }

  @override
  void dispose() {
    _captureWindow.setCaptureRequestedHandler(null);
    _captureWindow.setCaptureCancelledHandler(null);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final content = switch (_mode) {
      _SessionMode.selecting => CaptureSelectionOverlay(
        frame: _selectionFrame!,
        controller: _controller,
        windowController: _captureWindow,
        onTextRequested: _requestText,
        onCancel: _cancelCaptureSession,
        onConfirm: _confirmSelection,
      ),
      _SessionMode.quick => QuickCaptureView(
        frame: _frame!,
        desktopFrame: _selectionFrame!,
        normalizedSelection: _normalizedSelection!,
        controller: _controller,
        exportKey: _exportKey,
        busy: _busy,
        onTextRequested: _requestText,
        onCancel: _cancelCaptureSession,
        onDone: () => _copy(finishSession: true),
        onSave: _save,
        onOpenEditor: _openProEditor,
      ),
      _SessionMode.editor => _buildEditorShell(),
    };
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyS, alt: true, shift: true):
            _capture,
        const SingleActivator(LogicalKeyboardKey.keyZ, control: true):
            _controller.undo,
        const SingleActivator(LogicalKeyboardKey.keyY, control: true):
            _controller.redo,
        const SingleActivator(LogicalKeyboardKey.keyC, control: true): _copy,
        const SingleActivator(LogicalKeyboardKey.keyS, control: true): _save,
        const SingleActivator(LogicalKeyboardKey.escape): _handleEscape,
      },
      child: Focus(autofocus: true, child: content),
    );
  }

  Widget _buildEditorShell() {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(
              busy: _busy,
              hasFrame: _frame != null,
              controller: _controller,
              onCapture: _capture,
              onCopy: _copy,
              onSave: _save,
            ),
            const Divider(height: 1, color: Color(0xFF242A35)),
            Expanded(
              child: Row(
                children: [
                  _ToolRail(controller: _controller),
                  const VerticalDivider(width: 1, color: Color(0xFF242A35)),
                  Expanded(child: _buildWorkspace()),
                  const VerticalDivider(width: 1, color: Color(0xFF242A35)),
                  _Inspector(controller: _controller),
                ],
              ),
            ),
            _StatusBar(
              status: _status,
              frame: _frame,
              capabilities: _capabilities,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkspace() {
    final frame = _frame;
    if (frame == null) {
      return _EmptyWorkspace(
        enabled: _capabilities?.desktopCapture ?? false,
        busy: _busy,
        onCapture: _capture,
      );
    }
    return EditorCanvas(
      imageBytes: frame.pngBytes,
      imageSize: Size(frame.width.toDouble(), frame.height.toDouble()),
      controller: _controller,
      exportKey: _exportKey,
      onTextRequested: _requestText,
    );
  }

  Future<void> _capture() async {
    if (_busy ||
        _mode != _SessionMode.editor ||
        !(_capabilities?.desktopCapture ?? false)) {
      return;
    }
    setState(() {
      _busy = true;
      _status = 'Preparing frozen Windows capture…';
    });
    try {
      await _captureWindow.prepareCapture();
      final frame = await _captureService.captureDesktop();
      if (!mounted) {
        await _captureWindow.restoreEditor();
        return;
      }
      setState(() {
        _selectionFrame = frame;
        _mode = _SessionMode.selecting;
        _busy = false;
        _status = 'Select a region from ${frame.width} × ${frame.height}';
      });
      await WidgetsBinding.instance.endOfFrame;
      await _captureWindow.showCaptureOverlay();
    } catch (error) {
      await _captureWindow.restoreEditor();
      _showError('Capture failed', error);
      if (mounted) {
        setState(() {
          _mode = _SessionMode.editor;
          _selectionFrame = null;
          _busy = false;
        });
      }
    }
  }

  Future<void> _confirmSelection(
    Rect pixelBounds,
    Rect normalizedBounds,
  ) async {
    final source = _selectionFrame;
    if (source == null) return;
    try {
      final cropped = await _captureService.cropFrame(
        source,
        pixelBounds.left.round(),
        pixelBounds.top.round(),
        pixelBounds.width.round(),
        pixelBounds.height.round(),
      );
      if (!mounted) return;
      _controller.reset();
      setState(() {
        _frame = cropped;
        _normalizedSelection = normalizedBounds;
        _mode = _SessionMode.quick;
        _status = 'Selected ${cropped.width} × ${cropped.height}';
      });
    } catch (error) {
      _showError('Could not crop selection', error);
    }
  }

  Future<void> _cancelCaptureSession() async {
    if (_busy) return;
    await _captureWindow.restoreEditor();
    if (!mounted) return;
    setState(() {
      _selectionFrame = null;
      _normalizedSelection = null;
      _mode = _SessionMode.editor;
      _status = 'Capture cancelled';
    });
  }

  Future<void> _openProEditor() async {
    await _captureWindow.restoreEditor();
    await _captureWindow.showEditor();
    if (!mounted) return;
    setState(() {
      _selectionFrame = null;
      _normalizedSelection = null;
      _mode = _SessionMode.editor;
      _status = 'Editing ${_frame?.width} × ${_frame?.height}';
    });
  }

  void _handleEscape() {
    if (_mode == _SessionMode.editor) {
      _controller.reset();
    } else {
      _cancelCaptureSession();
    }
  }

  Future<Uint8List?> _renderPng() async {
    final boundary = _exportKey.currentContext?.findRenderObject();
    if (boundary is! RenderRepaintBoundary) return null;
    final image = await boundary.toImage(pixelRatio: 1);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data?.buffer.asUint8List();
  }

  Future<void> _copy({bool finishSession = false}) async {
    if (_frame == null || _busy) return;
    setState(() {
      _busy = true;
      _status = 'Rendering clipboard image…';
    });
    try {
      final bytes = await _renderPng();
      final clipboard = SystemClipboard.instance;
      if (bytes == null) throw StateError('The editor canvas is not ready.');
      if (clipboard == null) {
        throw StateError('Image clipboard is unavailable.');
      }
      final item = DataWriterItem(suggestedName: 'ProShottr.png');
      item.add(Formats.png(bytes));
      await clipboard.write([item]);
      if (finishSession) await _captureWindow.restoreEditor();
      if (mounted) {
        setState(() {
          _status = 'Copied image to clipboard';
          if (finishSession) {
            _mode = _SessionMode.editor;
            _selectionFrame = null;
            _normalizedSelection = null;
          }
        });
      }
    } catch (error) {
      _showError('Copy failed', error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    if (_frame == null || _busy) return;
    setState(() {
      _busy = true;
      _status = 'Saving PNG…';
    });
    try {
      final bytes = await _renderPng();
      if (bytes == null) throw StateError('The editor canvas is not ready.');
      if (_mode == _SessionMode.quick) {
        await _captureWindow.restoreEditor();
        if (!mounted) return;
        setState(() {
          _mode = _SessionMode.editor;
          _selectionFrame = null;
          _normalizedSelection = null;
        });
        await WidgetsBinding.instance.endOfFrame;
      }
      final path = await _captureService.savePngAs(bytes);
      if (mounted) {
        if (path == null) {
          setState(() => _status = 'Save cancelled');
        } else {
          setState(() => _status = 'Saved to $path');
          _showMessage('Saved to $path');
        }
      }
    } catch (error) {
      _showError('Save failed', error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _requestText(Offset point) async {
    final field = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add text'),
        content: TextField(
          controller: field,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(hintText: 'Type a label'),
          onSubmitted: (value) => Navigator.pop(context, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, field.text),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    field.dispose();
    if (value != null) _controller.addText(point, value);
  }

  void _showError(String title, Object error) {
    if (!mounted) return;
    setState(() => _status = '$title: $error');
    _showMessage('$title: $error', isError: true);
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? const Color(0xFF9F2940) : null,
      ),
    );
  }
}

enum _SessionMode { editor, selecting, quick }

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.busy,
    required this.hasFrame,
    required this.controller,
    required this.onCapture,
    required this.onCopy,
    required this.onSave,
  });

  final bool busy;
  final bool hasFrame;
  final EditorController controller;
  final VoidCallback onCapture;
  final VoidCallback onCopy;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 1000;
    return SizedBox(
      height: 64,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFFFF4D67),
                borderRadius: BorderRadius.circular(9),
              ),
              child: const Icon(Icons.crop_free_rounded, size: 20),
            ),
            if (!compact) ...[
              const SizedBox(width: 10),
              const Text(
                'ProShottr',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: 24),
            ] else
              const SizedBox(width: 8),
            if (compact)
              IconButton.filled(
                tooltip: 'Capture desktop (Alt+Shift+S)',
                onPressed: busy ? null : onCapture,
                icon: busy
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.screenshot_monitor_rounded, size: 18),
              )
            else
              FilledButton.icon(
                onPressed: busy ? null : onCapture,
                icon: busy
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.screenshot_monitor_rounded, size: 18),
                label: const Text('Capture desktop'),
              ),
            const Spacer(),
            AnimatedBuilder(
              animation: controller,
              builder: (context, child) => Row(
                children: [
                  IconButton(
                    tooltip: 'Undo (Ctrl+Z)',
                    onPressed: controller.canUndo ? controller.undo : null,
                    icon: const Icon(Icons.undo_rounded),
                  ),
                  IconButton(
                    tooltip: 'Redo (Ctrl+Y)',
                    onPressed: controller.canRedo ? controller.redo : null,
                    icon: const Icon(Icons.redo_rounded),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (compact)
              IconButton.outlined(
                tooltip: 'Copy (Ctrl+C)',
                onPressed: hasFrame && !busy ? onCopy : null,
                icon: const Icon(Icons.content_copy_rounded, size: 17),
              )
            else
              OutlinedButton.icon(
                onPressed: hasFrame && !busy ? onCopy : null,
                icon: const Icon(Icons.content_copy_rounded, size: 17),
                label: const Text('Copy'),
              ),
            const SizedBox(width: 8),
            if (compact)
              IconButton.filledTonal(
                tooltip: 'Save (Ctrl+S)',
                onPressed: hasFrame && !busy ? onSave : null,
                icon: const Icon(Icons.save_alt_rounded, size: 18),
              )
            else
              FilledButton.tonalIcon(
                onPressed: hasFrame && !busy ? onSave : null,
                icon: const Icon(Icons.save_alt_rounded, size: 18),
                label: const Text('Save'),
              ),
          ],
        ),
      ),
    );
  }
}

class _ToolRail extends StatelessWidget {
  const _ToolRail({required this.controller});

  final EditorController controller;

  static const _tools = <(EditorTool, IconData, String)>[
    (EditorTool.select, Icons.near_me_outlined, 'Select'),
    (EditorTool.rectangle, Icons.crop_square_rounded, 'Rectangle'),
    (EditorTool.ellipse, Icons.circle_outlined, 'Ellipse'),
    (EditorTool.sticker, Icons.emoji_emotions_outlined, 'Sticker'),
    (EditorTool.arrow, Icons.north_east_rounded, 'Arrow'),
    (EditorTool.pen, Icons.draw_rounded, 'Pen'),
    (EditorTool.mosaic, Icons.grid_on_rounded, 'Mosaic'),
    (EditorTool.text, Icons.title_rounded, 'Text'),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 76,
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, child) => ListView(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          children: [
            for (final (tool, icon, label) in _tools)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Tooltip(
                  message: label,
                  child: IconButton.filledTonal(
                    isSelected: controller.tool == tool,
                    onPressed: () => controller.selectTool(tool),
                    icon: Icon(icon),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Inspector extends StatelessWidget {
  const _Inspector({required this.controller});

  final EditorController controller;

  static const colors = quickPalette;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 224,
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, child) => ListView(
          padding: const EdgeInsets.all(18),
          children: [
            Text(
              'STYLE',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: const Color(0xFF8E98A8),
                letterSpacing: 1.4,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 18),
            const Text('Color', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final color in colors)
                  InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => controller.setColor(color),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: controller.color == color
                              ? const Color(0xFFFFFFFF)
                              : const Color(0xFF384151),
                          width: controller.color == color ? 3 : 1,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            const Text('Stroke', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            SegmentedButton<double>(
              segments: [
                for (final width in quickStrokeWidths)
                  ButtonSegment(value: width, label: Text('${width.round()}')),
              ],
              selected: {controller.strokeWidth},
              onSelectionChanged: (value) =>
                  controller.setStrokeWidth(value.single),
            ),
            if (controller.tool == EditorTool.text) ...[
              const SizedBox(height: 20),
              const Text(
                'Text size',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              SegmentedButton<double>(
                segments: [
                  for (final size in quickTextSizes)
                    ButtonSegment(value: size, label: Text('${size.round()}')),
                ],
                selected: {controller.fontSize},
                onSelectionChanged: (value) =>
                    controller.setFontSize(value.single),
              ),
            ],
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: controller.annotations.isEmpty
                  ? null
                  : controller.clear,
              icon: const Icon(Icons.layers_clear_rounded, size: 17),
              label: const Text('Clear markup'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyWorkspace extends StatelessWidget {
  const _EmptyWorkspace({
    required this.enabled,
    required this.busy,
    required this.onCapture,
  });

  final bool enabled;
  final bool busy;
  final VoidCallback onCapture;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF11151C),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 78,
                  height: 78,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF4D67).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Icon(
                    Icons.screenshot_monitor_rounded,
                    size: 38,
                    color: Color(0xFFFF6B80),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Capture. Mark up. Share.',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Start with your Windows desktop, then draw precise shapes, arrows, pen strokes, and text without changing the original image.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF9DA7B8), height: 1.5),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: enabled && !busy ? onCapture : null,
                  icon: const Icon(Icons.add_to_photos_rounded),
                  label: const Text('Capture desktop'),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Alt + Shift + S',
                  style: TextStyle(color: Color(0xFF697386), fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusBar extends StatelessWidget {
  const _StatusBar({
    required this.status,
    required this.frame,
    required this.capabilities,
  });

  final String status;
  final CapturedFrame? frame;
  final PlatformCapabilities? capabilities;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: const BoxDecoration(
        color: Color(0xFF10141B),
        border: Border(top: BorderSide(color: Color(0xFF242A35))),
      ),
      child: Row(
        children: [
          const Icon(Icons.circle, size: 7, color: Color(0xFF39D98A)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              status,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: Color(0xFFA4ADBC)),
            ),
          ),
          if (frame case final value?)
            Text(
              '${value.width} × ${value.height}  •  PNG',
              style: const TextStyle(fontSize: 12, color: Color(0xFF778294)),
            ),
          const SizedBox(width: 16),
          Text(
            (capabilities?.platform ?? 'unknown').toUpperCase(),
            style: const TextStyle(fontSize: 11, color: Color(0xFF778294)),
          ),
        ],
      ),
    );
  }
}
