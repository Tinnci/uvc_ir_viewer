// This is an example unit test.
//
// A unit test tests a single function, method, or class. To learn more about
// writing unit tests, visit
// https://flutter.dev/to/unit-testing

@TestOn('windows')

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uvc_ir_viewer/camera/uvc_camera.dart';

void main() {
  group('UVCCamera Tests', () {
    late UVCCamera camera;

    setUp(() {
      print('Setting up test...');
      try {
        camera = UVCCamera();
        print('Camera instance created');
      } catch (e, stackTrace) {
        print('Error in setUp: $e');
        print('Stack trace: $stackTrace');
        rethrow;
      }
    });

    tearDown(() {
      print('Tearing down test...');
      try {
        camera.dispose();
        print('Test cleanup completed');
      } catch (e) {
        print('Error in tearDown: $e');
      }
    });

    test('initial state should be not initialized', () {
      expect(camera.isInitialized, false);
      expect(camera.isPreviewStarted, false);
    });

    test('VENDOR_ID and PRODUCT_ID should be correct', () {
      expect(UVCCamera.VENDOR_ID, 0x2BDF);
      expect(UVCCamera.PRODUCT_ID, 0x0101);
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
