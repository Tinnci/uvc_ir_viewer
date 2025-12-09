import 'dart:async';
import 'package:flutter/services.dart';
import 'camera_interface.dart';

class WMFCamera implements CameraInterface {
  static const MethodChannel _channel =
      MethodChannel('com.example.uvc_viewer/camera');

  final _frameStreamController = StreamController<CameraFrame>.broadcast();
  bool _isInitialized = false;

  @override
  Stream<CameraFrame> get frameStream => _frameStreamController.stream;

  @override
  bool get isInitialized => _isInitialized;

  @override
  Future<void> initialize() async {
    // Platform channel is always ready on Windows once registered
    _isInitialized = true;
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
    final int? textureId =
        await _channel.invokeMethod('startPreview', {'index': _deviceIndex});
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
  void dispose() {
    _frameStreamController.close();
  }
}
