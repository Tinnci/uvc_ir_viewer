// This is an example unit test.
//
// A unit test tests a single function, method, or class. To learn more about
// writing unit tests, visit
// https://flutter.dev/to/unit-testing

// @TestOn('windows') library unit_test;

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

    test('Camera initialization', () {
      expect(camera.isInitialized, isFalse);
    });
  });
}
