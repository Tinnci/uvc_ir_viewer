import 'dart:typed_data';

class CameraFrame {
  final Uint8List bytes;
  final int width;
  final int height;

  CameraFrame({required this.bytes, required this.width, required this.height});
}

abstract class CameraInterface {
  bool get isInitialized;
  Future<void> initialize();
  Future<List<String>> enumerateDevices();
  Future<int?> getTextureId(); // 获取用于预览的纹理ID
  Future<Map<String, dynamic>> getDeviceStatus(int deviceIndex);
  Future<void> openDevice(int deviceIndex);
  Future<void> closeDevice();
  Stream<CameraFrame> get frameStream;
  Future<void> setBrightness(double value);
  Future<void> setContrast(double value);
  void dispose();
}
