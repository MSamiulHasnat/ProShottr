import 'package:proshottr/src/rust/api/simple.dart' as native;
import 'package:proshottr/src/rust/capture.dart';

abstract interface class CaptureService {
  PlatformCapabilities capabilities();
  Future<CapturedFrame> captureDesktop();
  Future<CapturedFrame> cropFrame(
    CapturedFrame frame,
    int left,
    int top,
    int width,
    int height,
  );
  Future<String> savePng(List<int> pngBytes);
  Future<String?> savePngAs(List<int> pngBytes);
}

class NativeCaptureService implements CaptureService {
  const NativeCaptureService();

  @override
  PlatformCapabilities capabilities() => native.capabilities();

  @override
  Future<CapturedFrame> captureDesktop() => native.captureDesktop();

  @override
  Future<CapturedFrame> cropFrame(
    CapturedFrame frame,
    int left,
    int top,
    int width,
    int height,
  ) => native.cropFrame(
    frame: frame,
    left: left,
    top: top,
    width: width,
    height: height,
  );

  @override
  Future<String> savePng(List<int> pngBytes) =>
      native.savePng(pngBytes: pngBytes);

  @override
  Future<String?> savePngAs(List<int> pngBytes) =>
      native.savePngAs(pngBytes: pngBytes);
}
