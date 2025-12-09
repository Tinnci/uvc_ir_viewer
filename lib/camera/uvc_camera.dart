import 'dart:io';
import 'dart:async';
import 'dart:typed_data';
import 'camera_interface.dart';
import 'win32_wmf.dart';
import 'android_uvc.dart';

class UVCCamera implements CameraInterface {
  late final CameraInterface _impl;
  bool _isCreated = false;

  UVCCamera() {
    if (Platform.isWindows) {
      _impl = WMFCamera();
    } else if (Platform.isAndroid) {
      _impl = AndroidUVCCamera();
    } else {
      throw UnsupportedError('Platform not supported');
    }
    _isCreated = true;
  }

  @override
  Stream<CameraFrame> get frameStream => _impl.frameStream;

  @override
  bool get isInitialized => _impl.isInitialized;

  @override
  CameraResolution? get currentResolution => _impl.currentResolution;

  @override
  Future<void> initialize() => _impl.initialize();

  @override
  Future<List<String>> enumerateDevices() => _impl.enumerateDevices();

  @override
  Future<int?> getTextureId() => _impl.getTextureId();

  @override
  Future<Map<String, dynamic>> getDeviceStatus(int deviceIndex) =>
      _impl.getDeviceStatus(deviceIndex);

  @override
  Future<void> openDevice(int deviceIndex) => _impl.openDevice(deviceIndex);

  @override
  Future<void> closeDevice() => _impl.closeDevice();

  @override
  Future<void> setBrightness(double value) => _impl.setBrightness(value);

  @override
  Future<void> setContrast(double value) => _impl.setContrast(value);

  @override
  Future<List<CameraResolution>> getSupportedResolutions() =>
      _impl.getSupportedResolutions();

  @override
  Future<void> setResolution(CameraResolution resolution) =>
      _impl.setResolution(resolution);

  @override
  Future<Uint8List?> capturePhoto() => _impl.capturePhoto();

  @override
  void dispose() {
    if (_isCreated) {
      _impl.dispose();
    }
  }
}
