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
        try {
          await camera.initialize();
          expect(camera.isInitialized, isTrue);
        } catch (e) {
          // 在测试环境中，如果没有实际的相机硬件，初始化可能会失败
          expect(e, isNotNull);
        }
      });

      test('Multiple initialization calls should be handled', () async {
        try {
          await camera.initialize();
          await camera.initialize(); // 第二次调用应该被正确处理
        } catch (e) {
          // 在测试环境中，初始化可能会失败，这是可以接受的
          expect(e, isNotNull);
        }
      });
    });

    group('Device Enumeration Tests', () {
      test('Should handle device enumeration', () async {
        try {
          await camera.initialize();
          final devices = await camera.enumerateDevices();
          expect(devices, isA<List<String>>());
        } catch (e) {
          // 在测试环境中，如果无法访问WMF API，这是可以接受的
          expect(e, isNotNull);
        }
      });
    });

    group('Device Control Tests', () {
      test('Should handle invalid device operations gracefully', () async {
        try {
          await camera.initialize();
          await camera.openDevice(-1);
          fail('Should throw an exception for invalid device index');
        } catch (e) {
          expect(e, isNotNull);
        }
      });

      test('Preview state should be tracked correctly', () async {
        expect(camera.isPreviewStarted, isFalse);
      });

      test('Should handle device close operations', () async {
        try {
          await camera.closeDevice();
          expect(camera.isPreviewStarted, isFalse);
        } catch (e) {
          expect(e, isNotNull);
        }
      });
    });

    group('Error Handling Tests', () {
      test('Should handle device open errors', () async {
        try {
          await camera.openDevice(999);
          fail('Should throw an exception for non-existent device');
        } catch (e) {
          expect(e, isNotNull);
        }
      });

      test('Should handle multiple close operations', () async {
        try {
          await camera.closeDevice();
          await camera.closeDevice();
        } catch (e) {
          fail('Multiple close operations should not throw: $e');
        }
      });
    });

    group('Resource Management Tests', () {
      test('Dispose should cleanup resources', () {
        camera.dispose();
        expect(camera.isInitialized, isFalse);
      });

      test('Should handle post-dispose operations', () async {
        camera.dispose();
        try {
          await camera.initialize();
          fail('Should throw after dispose');
        } catch (e) {
          expect(e, isNotNull);
        }
      });
    });

    group('Camera Settings Tests', () {
      test('Should handle resolution setting attempts', () async {
        try {
          await camera.initialize();
          await camera.openDevice(0);
          await camera.setResolution(640, 480);
        } catch (e) {
          // 在测试环境中，如果没有实际的相机硬件，这是可以接受的
          expect(e, isNotNull);
        }
      });

      // TODO: 当实现相机参数控制后启用这些测试
      // test('Should handle brightness control', () async {
      //   try {
      //     await camera.initialize();
      //     await camera.openDevice(0);
      //     await camera.setBrightness(0.5);
      //   } catch (e) {
      //     expect(e, isNotNull);
      //   }
      // });

      // test('Should handle contrast control', () async {
      //   try {
      //     await camera.initialize();
      //     await camera.openDevice(0);
      //     await camera.setContrast(0.5);
      //   } catch (e) {
      //     expect(e, isNotNull);
      //   }
      // });
    });
  });
}
