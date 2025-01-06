// This is an example unit test.
//
// A unit test tests a single function, method, or class. To learn more about
// writing unit tests, visit
// https://flutter.dev/to/unit-testing

@TestOn('windows')
library unit_test;

import 'package:flutter_test/flutter_test.dart';
import 'package:uvc_ir_viewer/camera/uvc_camera.dart';
import 'package:uvc_ir_viewer/camera/win32_wmf.dart';
import 'package:logging/logging.dart';
import 'package:flutter/foundation.dart';

void main() {
  group('Basic WMF Tests', () {
    late WMFCamera wmfCamera;

    setUp(() {
      wmfCamera = WMFCamera();
      Logger.root.level = Level.ALL;
      Logger.root.onRecord.listen((record) {
        debugPrint('${record.level.name}: ${record.time}: ${record.message}');
      });
    });

    test('WMF Initialization', () async {
      expect(wmfCamera.isInitialized, false);
      await wmfCamera.initialize();
      expect(wmfCamera.isInitialized, true);
    });

    test('Device Enumeration', () async {
      try {
        await wmfCamera.initialize();
        final devices = await wmfCamera.enumerateDevices();
        expect(devices, isA<List<String>>());
        debugPrint('Found ${devices.length} devices:');
        for (var device in devices) {
          debugPrint('Device: $device');
        }
      } catch (e, stackTrace) {
        debugPrint('Error during device enumeration: $e');
        debugPrint('Stack trace: $stackTrace');
        rethrow;
      }
    });

    test('Device Status Check - No Device', () async {
      try {
        await wmfCamera.initialize();
        final devices = await wmfCamera.enumerateDevices();
        expect(devices, isEmpty);

        // 测试无效设备索引
        final status = await wmfCamera.getDeviceStatus(0);
        expect(status['isConnected'], false);
        expect(status['error'], isNotNull);
      } catch (e, stackTrace) {
        debugPrint('Error during device status check: $e');
        debugPrint('Stack trace: $stackTrace');
        rethrow;
      }
    });

    test('Device Open Error Handling', () async {
      try {
        await wmfCamera.initialize();

        // 尝试打开不存在的设备应该抛出异常
        expect(() => wmfCamera.openDevice(0), throwsException);
      } catch (e, stackTrace) {
        debugPrint('Error during device open test: $e');
        debugPrint('Stack trace: $stackTrace');
        rethrow;
      }
    });
  });

  group('Basic UVCCamera Tests', () {
    late UVCCamera camera;

    setUp(() {
      camera = UVCCamera();
      Logger.root.level = Level.ALL;
      Logger.root.onRecord.listen((record) {
        debugPrint('${record.level.name}: ${record.time}: ${record.message}');
      });
    });

    tearDown(() {
      camera.dispose();
    });

    test('Camera Initialization', () async {
      try {
        expect(camera.isInitialized, false);
        await camera.initialize();
        expect(camera.isInitialized, true);
      } catch (e, stackTrace) {
        debugPrint('Error during camera initialization: $e');
        debugPrint('Stack trace: $stackTrace');
        rethrow;
      }
    });

    test('Device Enumeration - No Device', () async {
      try {
        await camera.initialize();
        final devices = await camera.enumerateDevices();
        expect(devices, isEmpty);
      } catch (e, stackTrace) {
        debugPrint('Error during device enumeration: $e');
        debugPrint('Stack trace: $stackTrace');
        rethrow;
      }
    });

    test('Device Control Error Handling', () async {
      try {
        await camera.initialize();
        final devices = await camera.enumerateDevices();
        expect(devices, isEmpty);

        // 尝试获取不存在设备的状态
        final status = await camera.getDeviceStatus(0);
        expect(status['isConnected'], false);
        expect(status['error'], isNotNull);

        // 尝试打开不存在的设备应该抛出异常
        expect(() => camera.openDevice(0), throwsException);

        // 尝试在没有打开设备的情况下设置参数应该抛出异常
        expect(() => camera.setBrightness(0.5), throwsException);
        expect(() => camera.setContrast(0.5), throwsException);
      } catch (e, stackTrace) {
        debugPrint('Error during device control test: $e');
        debugPrint('Stack trace: $stackTrace');
        rethrow;
      }
    });
  });
}
