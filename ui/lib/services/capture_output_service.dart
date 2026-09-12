import 'package:flutter/services.dart';
import 'package:super_clipboard/super_clipboard.dart';

/// Output is separate from capture so dialogs remain owned by the active host.
abstract interface class CaptureOutputService {
  Future<void> copyPng(Uint8List bytes);
  Future<String?> savePngAs(Uint8List bytes);
  Future<void> pinPng(Uint8List bytes);
}

class WindowsCaptureOutputService implements CaptureOutputService {
  const WindowsCaptureOutputService();

  static const _channel = MethodChannel('proshottr/windows_capture_window');

  @override
  Future<void> copyPng(Uint8List bytes) async {
    final clipboard = SystemClipboard.instance;
    if (clipboard == null) throw StateError('Image clipboard is unavailable.');
    final item = DataWriterItem(suggestedName: 'ProShottr.png');
    item.add(Formats.png(bytes));
    await clipboard.write([item]);
  }

  @override
  Future<String?> savePngAs(Uint8List bytes) =>
      _channel.invokeMethod<String>('savePngAs', {'pngBytes': bytes});

  @override
  Future<void> pinPng(Uint8List bytes) =>
      _channel.invokeMethod<void>('pinImage', {'pngBytes': bytes});
}
