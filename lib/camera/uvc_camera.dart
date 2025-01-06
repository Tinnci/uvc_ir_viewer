import 'dart:async';
import 'package:logging/logging.dart';
import 'win32_wmf.dart';

class UVCCamera {
  final WMFCamera _camera = WMFCamera();
  final _logger = Logger('UVCCamera');
  bool _initialized = false;
  Timer? _deviceCheckTimer;

  Future<void> initialize() async {
    if (_initialized) return;
    await _camera.startPreview(-1); // 使用-1初始化但不启动预览
    _initialized = true;
    _startDeviceCheck();
  }

  void _startDeviceCheck() {
    _deviceCheckTimer?.cancel();
    _deviceCheckTimer =
        Timer.periodic(const Duration(seconds: 2), (timer) async {
      try {
        final devices = await enumerateDevices();
        if (devices.isEmpty) {
          _logger.warning('No UVC devices found');
        } else {
          _logger.info('Found ${devices.length} UVC devices');
        }
      } catch (e) {
        _logger.severe('Failed to check devices', e);
      }
    });
  }

  /// 检查设备是否正确连接
  Future<bool> checkDeviceConnection(int deviceIndex) async {
    try {
      final devices = await enumerateDevices();
      if (deviceIndex < 0 || deviceIndex >= devices.length) {
        return false;
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  /// 获取设备状态信息
  Future<Map<String, dynamic>> getDeviceStatus(int deviceIndex) async {
    final status = <String, dynamic>{
      'isConnected': false,
      'deviceName': '',
      'isAvailable': false,
      'error': null,
    };

    try {
      final devices = await enumerateDevices();
      if (deviceIndex < 0 || deviceIndex >= devices.length) {
        status['error'] = 'Invalid device index';
        return status;
      }

      status['isConnected'] = true;
      status['deviceName'] = devices[deviceIndex];

      // 尝试打开设备以验证其可用性
      try {
        await _camera.startPreview(deviceIndex);
        status['isAvailable'] = true;
        await _camera.stopPreview();
      } catch (e) {
        status['error'] = 'Device not available: $e';
      }
    } catch (e) {
      status['error'] = 'Failed to check device: $e';
    }

    return status;
  }

  /// 检查所有可用设备
  Future<List<Map<String, dynamic>>> checkAllDevices() async {
    final deviceStatuses = <Map<String, dynamic>>[];
    try {
      final devices = await enumerateDevices();
      for (var i = 0; i < devices.length; i++) {
        final status = await getDeviceStatus(i);
        deviceStatuses.add(status);
      }
    } catch (e) {
      _logger.severe('Failed to check all devices', e);
    }
    return deviceStatuses;
  }

  /// Releases resources used by the camera
  void dispose() {
    _deviceCheckTimer?.cancel();
    _camera.stopPreview();
    _initialized = false;
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
