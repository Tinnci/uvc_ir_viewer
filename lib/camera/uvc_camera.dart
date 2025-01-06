import 'dart:async';
import 'win32_wmf.dart';

class UVCCamera {
  final WMFCamera _camera = WMFCamera();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
  }

  /// Releases resources used by the camera
  void dispose() {
    if (_initialized) {
      _camera.stopPreview();
      _initialized = false;
    }
  }

  /// Whether the camera is initialized
  bool get isInitialized => _initialized;

  Future<List<String>> enumerateDevices() async {
    return WMFCamera.enumerateDevices();
  }

  Future<void> openDevice(int deviceIndex) async {
    await _camera.startPreview(deviceIndex);
  }

  Future<void> closeDevice() async {
    await _camera.stopPreview();
  }

  Future<void> setResolution(int width, int height) async {
    await _camera.setResolution(width, height);
  }

  bool get isPreviewStarted => _camera.isPreviewActive;

  Future<void> startPreview() async {
    // Preview is started when opening the device
  }

  Future<void> stopPreview() async {
    await _camera.stopPreview();
  }
}
