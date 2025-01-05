// This is an example unit test.
//
// A unit test tests a single function, method, or class. To learn more about
// writing unit tests, visit
// https://flutter.dev/to/unit-testing

// @TestOn('windows') library unit_test;

import 'package:flutter_test/flutter_test.dart';
import 'package:uvc_ir_viewer/camera/uvc_camera.dart';
import 'package:logging/logging.dart';

void main() {
  group('UVCCamera Tests', () {
    late UVCCamera camera;
    late Logger logger;

    setUp(() {
      logger = Logger('UnitTest');
      Logger.root.level = Level.ALL;
      Logger.root.onRecord.listen((record) {
        // 在测试环境中，我们使用 printOnFailure 来记录日志
        // 这样只有在测试失败时才会显示日志
        addTearDown(() {
          printOnFailure(
              '${record.level.name}: ${record.time}: ${record.message}');
          if (record.error != null) {
            printOnFailure('Error: ${record.error}');
          }
          if (record.stackTrace != null) {
            printOnFailure('Stack trace:\n${record.stackTrace}');
          }
        });
      });

      try {
        camera = UVCCamera();
      } catch (e, stackTrace) {
        logger.severe('Error in setUp', e, stackTrace);
        rethrow;
      }
    });

    tearDown(() {
      try {
        camera.dispose();
      } catch (e) {
        logger.warning('Error in tearDown: $e');
      }
    });

    test('initial state should be not initialized', () {
      expect(camera.isInitialized, false);
      expect(camera.isPreviewStarted, false);
    });

    test('vendorId and productId should be correct', () {
      expect(UVCCamera.vendorId, 0x2BDF);
      expect(UVCCamera.productId, 0x0101);
    });

    test('dispose() should reset initialized state', () {
      expect(camera.isInitialized, false);
      camera.dispose();
      expect(camera.isInitialized, false);
      expect(camera.isPreviewStarted, false);
    });

    test('startPreview() should throw when not initialized', () {
      expect(() => camera.startPreview(), throwsException);
    });
  });
}
