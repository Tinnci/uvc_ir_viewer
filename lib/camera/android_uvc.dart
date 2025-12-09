import 'dart:async';
import 'package:flutter/services.dart';
import 'camera_interface.dart';

class AndroidUVCCamera implements CameraInterface {
  static const MethodChannel _channel = MethodChannel(
    'com.example.uvc_viewer/camera',
  );

  final _frameStreamController = StreamController<CameraFrame>.broadcast();
  bool _isInitialized = false;

  @override
  Stream<CameraFrame> get frameStream => _frameStreamController.stream;

  @override
  bool get isInitialized => _isInitialized;

  @override
  Future<void> initialize() async {
    // 基础初始化，可能不需要做太多事情，因为通过MethodChannel调用
    _isInitialized = true;
  }

  @override
  Future<List<String>> enumerateDevices() async {
    final List<dynamic> devices = await _channel.invokeMethod(
      'enumerateDevices',
    );
    return devices.cast<String>();
  }

  @override
  Future<int?> getTextureId() async {
    final int? textureId = await _channel.invokeMethod('startPreview');
    return textureId;
  }

  @override
  Future<Map<String, dynamic>> getDeviceStatus(int deviceIndex) async {
    // 实现Android端的设备状态查询
    return {
      'isConnected': true, // 简化实现
      'isAvailable': true,
    };
  }

  @override
  Future<void> openDevice(int deviceIndex) async {
    await _channel.invokeMethod('openDevice', {'index': deviceIndex});
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
