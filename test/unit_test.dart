// This is an example unit test.
//
// A unit test tests a single function, method, or class. To learn more about
// writing unit tests, visit
// https://flutter.dev/to/unit-testing

@TestOn('windows')
library unit_test;

import 'package:flutter_test/flutter_test.dart';
import 'package:uvc_ir_viewer/camera/uvc_camera.dart';
import 'package:logging/logging.dart';
import 'package:flutter/foundation.dart';

void main() {
  group('UVCCamera Tests', () {
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

    group('Initialization Tests', () {
      test('Camera should start uninitialized', () {
        expect(camera.isInitialized, isFalse);
      });

      test('Camera should be initialized after initialize()', () async {
        await camera.initialize();
        expect(camera.isInitialized, isTrue);
      });

      test('Multiple initialization calls should not throw', () async {
        await camera.initialize();
        await camera.initialize(); // 第二次调用不应抛出异常
        expect(camera.isInitialized, isTrue);
      });
    });

    group('Device Enumeration Tests', () {
      test('Should return a list of devices', () async {
        await camera.initialize();
        final devices = await camera.enumerateDevices();
        expect(devices, isA<List<String>>());
      });

      test('Device list should not be null', () async {
        await camera.initialize();
        final devices = await camera.enumerateDevices();
        expect(devices, isNotNull);
      });
    });

    group('Device Control Tests', () {
      test('Should handle invalid device index', () async {
        await camera.initialize();
        expect(() => camera.openDevice(-1), throwsA(anything));
      });

      test('Preview state should be correct', () async {
        await camera.initialize();
        expect(camera.isPreviewStarted, isFalse);
      });

      test('Should close device properly', () async {
        await camera.initialize();
        await camera.closeDevice();
        expect(camera.isPreviewStarted, isFalse);
      });
    });

    group('Error Handling Tests', () {
      test('Should handle device open errors gracefully', () async {
        await camera.initialize();
        // 尝试打开一个不存在的设备索引
        expect(() => camera.openDevice(999), throwsA(anything));
      });

      test('Should handle multiple close calls', () async {
        await camera.initialize();
        await camera.closeDevice();
        await camera.closeDevice(); // 第二次关闭不应抛出异常
      });
    });

    group('Resource Management Tests', () {
      test('Dispose should cleanup resources', () async {
        await camera.initialize();
        camera.dispose();
        expect(camera.isInitialized, isFalse);
      });

      test('Should handle operations after dispose', () async {
        camera.dispose();
        expect(() => camera.initialize(), throwsA(anything));
      });
    });

    group('Camera Settings Tests', () {
      test('Should set resolution', () async {
        await camera.initialize();
        // 测试设置分辨率
        expect(() => camera.setResolution(640, 480), returnsNormally);
      });

      // TODO: 添加更多相机参数测试
      // test('Should set brightness', () async {
      //   await camera.initialize();
      //   await camera.setBrightness(0.5);
      //   expect(camera.getBrightness(), equals(0.5));
      // });

      // test('Should set contrast', () async {
      //   await camera.initialize();
      //   await camera.setContrast(0.5);
      //   expect(camera.getContrast(), equals(0.5));
      // });
    });
  });
}
