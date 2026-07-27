import 'package:flutter/services.dart';

abstract interface class CaptureWindowController {
  void setCaptureRequestedHandler(Future<void> Function()? handler);
  void setCaptureCancelledHandler(Future<void> Function()? handler);
  Future<void> prepareCapture();
  Future<void> showCaptureOverlay();
  Future<void> restoreEditor();
  Future<void> showEditor();
  Future<WindowBounds?> windowAtPoint(int x, int y);
}

class WindowBounds {
  const WindowBounds({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
    this.title = '',
  });

  final int left;
  final int top;
  final int right;
  final int bottom;
  final String title;
}

class WindowsCaptureWindowController implements CaptureWindowController {
  WindowsCaptureWindowController();

  static const _channel = MethodChannel('proshottr/windows_capture_window');
  Future<void> Function()? _captureRequestedHandler;
  Future<void> Function()? _captureCancelledHandler;

  @override
  void setCaptureRequestedHandler(Future<void> Function()? handler) {
    _captureRequestedHandler = handler;
    _installMethodHandler();
  }

  @override
  void setCaptureCancelledHandler(Future<void> Function()? handler) {
    _captureCancelledHandler = handler;
    _installMethodHandler();
  }

  void _installMethodHandler() {
    if (_captureRequestedHandler == null && _captureCancelledHandler == null) {
      _channel.setMethodCallHandler(null);
      return;
    }
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'captureRequested':
          await _captureRequestedHandler?.call();
        case 'captureCancelled':
          await _captureCancelledHandler?.call();
      }
    });
  }

  @override
  Future<void> prepareCapture() => _channel.invokeMethod('prepareCapture');

  @override
  Future<void> showCaptureOverlay() =>
      _channel.invokeMethod('showCaptureOverlay');

  @override
  Future<void> restoreEditor() => _channel.invokeMethod('restoreEditor');

  @override
  Future<void> showEditor() => _channel.invokeMethod('showEditor');

  @override
  Future<WindowBounds?> windowAtPoint(int x, int y) async {
    final result = await _channel.invokeMethod<Map<Object?, Object?>>(
      'windowAtPoint',
      <String, int>{'x': x, 'y': y},
    );
    if (result == null) return null;
    int value(String key) => (result[key] as num).round();
    return WindowBounds(
      left: value('left'),
      top: value('top'),
      right: value('right'),
      bottom: value('bottom'),
      title: result['title'] as String? ?? '',
    );
  }
}
