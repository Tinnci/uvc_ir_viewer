import 'win32_wmf.dart';

class UVCCamera {
  final WMFCamera _camera = WMFCamera();
  bool _isInitialized = false;

  /// Whether the camera is initialized
  bool get isInitialized => _isInitialized;

  Future<void> initialize() async {
    if (_isInitialized) return;
    await _camera.initialize();
    _isInitialized = true;
  }

  Future<List<String>> enumerateDevices() async {
    if (!_isInitialized) {
      await initialize();
    }
    return _camera.enumerateDevices();
  }

  /// 获取设备状态信息
  Future<Map<String, dynamic>> getDeviceStatus(int deviceIndex) async {
    if (!_isInitialized) {
      await initialize();
    }
    return _camera.getDeviceStatus(deviceIndex);
  }

  /// 打开设备
  Future<void> openDevice(int deviceIndex) async {
    if (!_isInitialized) {
      await initialize();
    }
    await _camera.openDevice(deviceIndex);
  }

  /// 关闭设备
  Future<void> closeDevice() async {
    if (!_isInitialized) return;
    await _camera.closeDevice();
  }

  /// 设置亮度
  Future<void> setBrightness(double value) async {
    if (!_isInitialized) {
      throw Exception('Camera is not initialized');
    }
    await _camera.setBrightness(value);
  }

  /// 设置对比度
  Future<void> setContrast(double value) async {
    if (!_isInitialized) {
      throw Exception('Camera is not initialized');
    }
    await _camera.setContrast(value);
  }

  void dispose() {
    _camera.dispose();
    _isInitialized = false;
  }
}
