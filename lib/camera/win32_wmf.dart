import 'dart:async';
import 'package:flutter/services.dart';
import 'camera_interface.dart';

class WMFCamera implements CameraInterface {
  static const MethodChannel _channel =
      MethodChannel('com.example.uvc_viewer/camera');
  static const MethodChannel _deviceChangeChannel =
      MethodChannel('com.example.uvc_viewer/device_change');

  final _frameStreamController = StreamController<CameraFrame>.broadcast();
  final _deviceChangeController = StreamController<String>.broadcast();
  bool _isInitialized = false;
  CameraResolution? _currentResolution;
  List<CameraResolution> _supportedResolutions = [];

  @override
  Stream<CameraFrame> get frameStream => _frameStreamController.stream;

  @override
  bool get isInitialized => _isInitialized;

  @override
  CameraResolution? get currentResolution => _currentResolution;

  @override
  Future<void> initialize() async {
    // Platform channel is always ready on Windows once registered
    _isInitialized = true;

    // Listen for device change notifications from native
    _deviceChangeChannel.setMethodCallHandler((call) async {
      if (call.method == 'onDeviceChanged') {
        final String changeType = call.arguments as String? ?? 'unknown';
        _deviceChangeController.add(changeType);
      }
    });
  }

  @override
  Future<List<String>> enumerateDevices() async {
    final List<dynamic> devices =
        await _channel.invokeMethod('enumerateDevices');
    return devices.cast<String>();
  }

  int _deviceIndex = 0;

  @override
  Future<int?> getTextureId() async {
    final Map<String, dynamic> params = {'index': _deviceIndex};
    if (_currentResolution != null) {
      params['width'] = _currentResolution!.width;
      params['height'] = _currentResolution!.height;
    }
    final int? textureId = await _channel.invokeMethod('startPreview', params);
    return textureId;
  }

  @override
  Future<Map<String, dynamic>> getDeviceStatus(int deviceIndex) async {
    try {
      final Map<dynamic, dynamic>? result = await _channel
          .invokeMethod('getDeviceStatus', {'index': deviceIndex});
      if (result != null) {
        return result.cast<String, dynamic>();
      }
      return {
        'isConnected': false,
        'isAvailable': false,
        'error': 'Failed to get device status',
      };
    } catch (e) {
      return {
        'isConnected': false,
        'isAvailable': false,
        'error': e.toString(),
      };
    }
  }

  @override
  Future<void> openDevice(int deviceIndex) async {
    _deviceIndex = deviceIndex;
    // 获取支持的分辨率
    _supportedResolutions = await getSupportedResolutions();
    if (_supportedResolutions.isNotEmpty && _currentResolution == null) {
      _currentResolution = _supportedResolutions.first;
    }
  }

  @override
  Future<void> closeDevice() async {
    await _channel.invokeMethod('closeDevice');
  }

  @override
  Future<void> setBrightness(double value) async {
    await _channel.invokeMethod('setBrightness', {'value': value});
  }

  @override
  Future<void> setContrast(double value) async {
    await _channel.invokeMethod('setContrast', {'value': value});
  }

  @override
  Future<List<CameraResolution>> getSupportedResolutions() async {
    try {
      final List<dynamic>? result = await _channel
          .invokeMethod('getSupportedResolutions', {'index': _deviceIndex});
      if (result != null) {
        return result.map((item) {
          final map = item as Map<dynamic, dynamic>;
          return CameraResolution(
            width: map['width'] as int,
            height: map['height'] as int,
            frameRate: (map['frameRate'] as int?) ?? 30,
          );
        }).toList();
      }
    } catch (e) {
      // 如果原生层还未实现，返回默认分辨率列表
    }
    // 返回常见的默认分辨率
    return [
      CameraResolution(width: 640, height: 480, frameRate: 30),
      CameraResolution(width: 320, height: 240, frameRate: 30),
      CameraResolution(width: 1280, height: 720, frameRate: 30),
    ];
  }

  @override
  Future<void> setResolution(CameraResolution resolution) async {
    _currentResolution = resolution;
    // 如果正在预览，需要重新启动预览以应用新分辨率
    try {
      await _channel.invokeMethod('setResolution', {
        'width': resolution.width,
        'height': resolution.height,
      });
    } catch (e) {
      // 原生层可能还未实现，忽略错误
    }
  }

  @override
  Future<Uint8List?> capturePhoto() async {
    try {
      final result = await _channel.invokeMethod('capturePhoto');
      if (result != null) {
        return result as Uint8List;
      }
    } catch (e) {
      // 捕获失败
    }
    return null;
  }

  @override
  Stream<String> get onDeviceChanged => _deviceChangeController.stream;

  @override
  void dispose() {
    _frameStreamController.close();
    _deviceChangeController.close();
  }
}
