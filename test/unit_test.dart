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

    test('Device Status Check', () async {
      try {
        await wmfCamera.initialize();
        final devices = await wmfCamera.enumerateDevices();
        if (devices.isNotEmpty) {
          final status = await wmfCamera.getDeviceStatus(0);
          expect(status, isA<Map<String, dynamic>>());
          expect(status['isConnected'], isA<bool>());
          expect(status['deviceName'], isA<String>());
          expect(status['isAvailable'], isA<bool>());
          debugPrint('Device status: $status');
        }
      } catch (e, stackTrace) {
        debugPrint('Error during device status check: $e');
        debugPrint('Stack trace: $stackTrace');
        rethrow;
      }
    });

    test('Device Open and Close', () async {
      try {
        await wmfCamera.initialize();
        final devices = await wmfCamera.enumerateDevices();
        if (devices.isNotEmpty) {
          await wmfCamera.openDevice(0);
          final status = await wmfCamera.getDeviceStatus(0);
          expect(status['isAvailable'], true);

          await wmfCamera.closeDevice();
        }
      } catch (e, stackTrace) {
        debugPrint('Error during device open/close test: $e');
        debugPrint('Stack trace: $stackTrace');
        rethrow;
      }
    });

    test('Camera Parameters', () async {
      try {
        await wmfCamera.initialize();
        final devices = await wmfCamera.enumerateDevices();
        if (devices.isNotEmpty) {
          await wmfCamera.openDevice(0);

          await wmfCamera.setBrightness(0.5);
          await wmfCamera.setContrast(0.5);

          await wmfCamera.closeDevice();
        }
      } catch (e, stackTrace) {
        debugPrint('Error during camera parameters test: $e');
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

    test('Device Enumeration', () async {
      try {
        await camera.initialize();
        final devices = await camera.enumerateDevices();
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

    test('Device Control', () async {
      try {
        await camera.initialize();
        final devices = await camera.enumerateDevices();
        if (devices.isNotEmpty) {
          final status = await camera.getDeviceStatus(0);
          expect(status, isA<Map<String, dynamic>>());

          await camera.openDevice(0);
          await camera.setBrightness(0.5);
          await camera.setContrast(0.5);
          await camera.closeDevice();
        }
      } catch (e, stackTrace) {
        debugPrint('Error during device control test: $e');
        debugPrint('Stack trace: $stackTrace');
        rethrow;
      }
    });
  });
}
