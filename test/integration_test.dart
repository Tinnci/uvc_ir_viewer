// @TestOn('windows') library integration_test;

import 'dart:ffi';
import 'package:flutter_test/flutter_test.dart';
import 'package:uvc_ir_viewer/camera/uvc_camera.dart';
import 'package:win32/win32.dart' as win32;
import 'package:logging/logging.dart';

void main() {
  group('UVCCamera Hardware Integration Tests', () {
    late UVCCamera camera;
    late Logger logger;

    setUpAll(() async {
      logger = Logger('IntegrationTest');
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
        // 初始化 COM
        final hr =
            win32.CoInitializeEx(nullptr, win32.COINIT.COINIT_MULTITHREADED);
        if (win32.FAILED(hr)) {
          if (hr == win32.RPC_E_CHANGED_MODE) {
            logger.warning(
                'COM already initialized with different threading model');
          } else {
            throw Exception(
                'Failed to initialize COM: 0x${hr.toRadixString(16)}');
          }
        }
      } catch (e, stackTrace) {
        logger.severe('Error in setUpAll', e, stackTrace);
        rethrow;
      }
    });

    setUp(() async {
      try {
        camera =
            UVCCamera(skipComInit: true); // 跳过 COM 初始化，因为我们在 setUpAll 中已经初始化了
        // 等待一段时间以确保设备准备就绪
        await Future.delayed(const Duration(seconds: 2));
      } catch (e, stackTrace) {
        logger.severe('Error in setUp', e, stackTrace);
        rethrow;
      }
    });

    tearDown(() async {
      try {
        camera.dispose();
        // 等待一段时间以确保资源被正确释放
        await Future.delayed(const Duration(seconds: 2));
      } catch (e) {
        logger.warning('Error in tearDown: $e');
      }
    });

    tearDownAll(() {
      try {
        win32.CoUninitialize();
      } catch (e) {
        logger.warning('Error in tearDownAll: $e');
      }
    });

    test('basic camera initialization test', () async {
      try {
        expect(camera.isInitialized, false,
            reason: 'Camera should not be initialized initially');

        final result = await camera.initialize().timeout(
          const Duration(seconds: 30),
          onTimeout: () {
            logger.warning('Camera initialization timed out after 30 seconds');
            return false;
          },
        );

        expect(result, true, reason: 'Camera initialization should succeed');
        expect(camera.isInitialized, true,
            reason: 'Camera should be marked as initialized');
      } catch (e, stackTrace) {
        logger.severe('Error in basic initialization test', e, stackTrace);
        rethrow;
      }
    }, timeout: const Timeout(Duration(seconds: 60)));
  });
}
