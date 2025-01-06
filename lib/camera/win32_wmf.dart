import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart' as win32;
import 'package:flutter/foundation.dart';

// Windows Media Foundation function types
typedef MFStartupNative = Int32 Function(Int32 version, Int32 flags);
typedef MFStartupDart = int Function(int version, int flags);

typedef MFShutdownNative = Int32 Function();
typedef MFShutdownDart = int Function();

// Define missing constants
const int mfVersion = 0x00020070;

class WMFCamera {
  bool _isInitialized = false;
  static DynamicLibrary? _mfplat;
  static Function? _mfStartup;
  static Function? _mfShutdown;
  int? _currentDeviceIndex;
  bool _isDeviceOpen = false;

  static void _initializeLibraries() {
    if (_mfplat != null) return;

    try {
      debugPrint('Loading mfplat.dll...');
      _mfplat = DynamicLibrary.open('mfplat.dll');

      debugPrint('Looking up MFStartup...');
      _mfStartup =
          _mfplat!.lookupFunction<MFStartupNative, MFStartupDart>('MFStartup');
      debugPrint('Looking up MFShutdown...');
      _mfShutdown = _mfplat!
          .lookupFunction<MFShutdownNative, MFShutdownDart>('MFShutdown');
    } catch (e, stackTrace) {
      debugPrint('Failed to initialize Windows Media Foundation: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Whether the camera system is initialized
  bool get isInitialized => _isInitialized;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _initializeLibraries();
      debugPrint('Calling MFStartup...');
      final hr = _mfStartup!(mfVersion, 0);
      if (win32.FAILED(hr)) {
        final error = win32.WindowsException(hr);
        debugPrint('MFStartup failed with error: $error');
        throw error;
      }
      _isInitialized = true;
      debugPrint('WMF initialization successful');
    } catch (e, stackTrace) {
      debugPrint('Failed to initialize camera: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  Future<List<String>> enumerateDevices() async {
    if (!_isInitialized) {
      debugPrint('Initializing before device enumeration...');
      await initialize();
    }

    final devices = <String>[];

    try {
      debugPrint('Enumerating video capture devices...');
      final hr = win32.CoInitializeEx(nullptr, win32.COINIT_MULTITHREADED);
      if (win32.FAILED(hr)) {
        throw win32.WindowsException(hr);
      }

      try {
        // 使用 Windows 核心 API 枚举设备
        final hDevInfo = win32.SetupDiGetClassDevs(nullptr, win32.TEXT('USB'),
            0, win32.DIGCF_PRESENT | win32.DIGCF_ALLCLASSES);

        if (hDevInfo != win32.INVALID_HANDLE_VALUE) {
          var index = 0;
          final devInfoData = calloc<win32.SP_DEVINFO_DATA>();
          devInfoData.ref.cbSize = sizeOf<win32.SP_DEVINFO_DATA>();

          while (
              win32.SetupDiEnumDeviceInfo(hDevInfo, index, devInfoData) != 0) {
            final buffer = calloc<Uint16>(256).cast<Utf16>();
            final bufferSize = calloc<Uint32>();
            bufferSize.value = 256;

            if (win32.SetupDiGetDeviceInstanceId(
                    hDevInfo, devInfoData, buffer, 256, bufferSize) !=
                0) {
              final deviceId = buffer.toDartString();
              if (deviceId.toLowerCase().contains('usb') &&
                  deviceId.toLowerCase().contains('vid_')) {
                debugPrint('Found USB device: $deviceId');
                devices.add(deviceId);
              }
            }

            calloc.free(buffer);
            calloc.free(bufferSize);
            index++;
          }

          calloc.free(devInfoData);
          win32.SetupDiDestroyDeviceInfoList(hDevInfo);
        }
      } finally {
        win32.CoUninitialize();
      }
    } catch (e, stackTrace) {
      debugPrint('Error during device enumeration: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }

    return devices;
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
      status['isAvailable'] = true;

      // 检查设备是否已经被打开
      if (_currentDeviceIndex == deviceIndex && _isDeviceOpen) {
        status['isAvailable'] = true;
      }
    } catch (e) {
      status['error'] = 'Failed to check device: $e';
    }

    return status;
  }

  /// 打开设备
  Future<void> openDevice(int deviceIndex) async {
    if (!_isInitialized) {
      await initialize();
    }

    final devices = await enumerateDevices();
    if (deviceIndex < 0 || deviceIndex >= devices.length) {
      throw Exception('Invalid device index');
    }

    // 如果已经打开了其他设备，先关闭它
    if (_isDeviceOpen && _currentDeviceIndex != deviceIndex) {
      await closeDevice();
    }

    // 如果已经打开了这个设备，直接返回
    if (_isDeviceOpen && _currentDeviceIndex == deviceIndex) {
      return;
    }

    try {
      debugPrint('Opening device $deviceIndex: ${devices[deviceIndex]}');
      // TODO: 实现实际的设备打开逻辑
      _currentDeviceIndex = deviceIndex;
      _isDeviceOpen = true;
    } catch (e) {
      debugPrint('Failed to open device: $e');
      rethrow;
    }
  }

  /// 关闭设备
  Future<void> closeDevice() async {
    if (!_isDeviceOpen) return;

    try {
      debugPrint('Closing device $_currentDeviceIndex');
      // TODO: 实现实际的设备关闭逻辑
      _currentDeviceIndex = null;
      _isDeviceOpen = false;
    } catch (e) {
      debugPrint('Failed to close device: $e');
      rethrow;
    }
  }

  /// 设置亮度
  Future<void> setBrightness(double value) async {
    if (!_isDeviceOpen) {
      throw Exception('No device is open');
    }

    try {
      debugPrint('Setting brightness to $value');
      // TODO: 实现实际的亮度调节逻辑
    } catch (e) {
      debugPrint('Failed to set brightness: $e');
      rethrow;
    }
  }

  /// 设置对比度
  Future<void> setContrast(double value) async {
    if (!_isDeviceOpen) {
      throw Exception('No device is open');
    }

    try {
      debugPrint('Setting contrast to $value');
      // TODO: 实现实际的对比度调节逻辑
    } catch (e) {
      debugPrint('Failed to set contrast: $e');
      rethrow;
    }
  }

  void dispose() {
    if (_isInitialized) {
      debugPrint('Shutting down WMF...');
      _mfShutdown!();
      _isInitialized = false;
      debugPrint('WMF shutdown complete');
    }
  }
}
