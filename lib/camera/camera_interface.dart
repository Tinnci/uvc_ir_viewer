import 'dart:typed_data';

class CameraFrame {
  final Uint8List bytes;
  final int width;
  final int height;

  CameraFrame({required this.bytes, required this.width, required this.height});
}

/// 表示相机支持的分辨率
class CameraResolution {
  final int width;
  final int height;
  final int frameRate;

  CameraResolution({
    required this.width,
    required this.height,
    this.frameRate = 30,
  });

  String get displayName =>
      '${width}x$height${frameRate > 0 ? ' @${frameRate}fps' : ''}';

  @override
  String toString() => displayName;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CameraResolution &&
          width == other.width &&
          height == other.height;

  @override
  int get hashCode => width.hashCode ^ height.hashCode;
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

  /// 获取设备支持的分辨率列表
  Future<List<CameraResolution>> getSupportedResolutions();

  /// 设置当前分辨率
  Future<void> setResolution(CameraResolution resolution);

  /// 获取当前分辨率
  CameraResolution? get currentResolution;

  /// 拍照并返回图片数据
  Future<Uint8List?> capturePhoto();

  /// 设备热插拔事件流 (connected/disconnected)
  Stream<String> get onDeviceChanged;

  void dispose();
}
