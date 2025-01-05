@TestOn('windows')

import 'package:flutter_test/flutter_test.dart';
import 'package:uvc_ir_viewer/camera/uvc_camera.dart';

void main() {
  group('UVCCamera Hardware Integration Tests', () {
    late UVCCamera camera;

    setUp(() {
      print('Setting up integration test...');
      try {
        print('Creating UVCCamera instance...');
        camera = UVCCamera(skipComInit: true);
        print('Camera instance created successfully');
      } catch (e, stackTrace) {
        print('Error in setUp: $e');
        print('Stack trace: $stackTrace');
        rethrow;
      }
    });

    tearDown(() {
      print('Tearing down integration test...');
      try {
        camera.dispose();
        print('Camera disposed successfully');
      } catch (e) {
        print('Error in tearDown: $e');
      }
    });

    test('initialize() should succeed with connected hardware', () async {
      print('Starting hardware initialization test...');
      try {
        expect(camera.isInitialized, false,
            reason: 'Camera should not be initialized initially');
        print('Calling initialize()...');

        final result = await camera.initialize().timeout(
          const Duration(seconds: 30),
          onTimeout: () {
            print('Camera initialization timed out after 30 seconds');
            return false;
          },
        );

        print('Initialize result: $result');
        expect(result, true, reason: 'Camera initialization should succeed');
        expect(camera.isInitialized, true,
            reason: 'Camera should be marked as initialized');
        print('Hardware initialization test completed successfully');
      } catch (e, stackTrace) {
        print('Error in initialization test: $e');
        print('Stack trace: $stackTrace');
        rethrow;
      }
    }, timeout: Timeout(Duration(seconds: 60)));

    test('complete camera workflow test', () async {
      print('Starting workflow test...');
      try {
        // Initialize camera
        print('Step 1: Initializing camera...');
        expect(camera.isInitialized, false);
        final initResult = await camera.initialize().timeout(
          const Duration(seconds: 30),
          onTimeout: () {
            print('Camera initialization timed out after 30 seconds');
            return false;
          },
        );
        print('Initialize result: $initResult');
        expect(initResult, true,
            reason: 'Camera initialization should succeed');
        expect(camera.isInitialized, true,
            reason: 'Camera should be marked as initialized');

        // Start preview
        print('Step 2: Starting preview...');
        final startResult = await camera.startPreview().timeout(
          const Duration(seconds: 30),
          onTimeout: () {
            print('Preview start timed out after 30 seconds');
            return false;
          },
        );
        print('Start preview result: $startResult');
        expect(startResult, true, reason: 'Preview should start successfully');
        expect(camera.isPreviewStarted, true,
            reason: 'Preview should be marked as started');

        // Wait for a few seconds to ensure preview is working
        print('Step 3: Waiting for preview...');
        await Future.delayed(Duration(seconds: 2));

        // Stop preview
        print('Step 4: Stopping preview...');
        final stopResult = await camera.stopPreview().timeout(
          const Duration(seconds: 30),
          onTimeout: () {
            print('Preview stop timed out after 30 seconds');
            return false;
          },
        );
        print('Stop preview result: $stopResult');
        expect(stopResult, true, reason: 'Preview should stop successfully');
        expect(camera.isPreviewStarted, false,
            reason: 'Preview should be marked as stopped');
        print('Workflow test completed successfully');
      } catch (e, stackTrace) {
        print('Error in workflow test: $e');
        print('Stack trace: $stackTrace');
        rethrow;
      }
    }, timeout: Timeout(Duration(seconds: 120)));

    test('reinitialize after dispose should work', () async {
      print('Starting reinitialize test...');
      try {
        // First initialization
        print('Step 1: First initialization...');
        expect(camera.isInitialized, false);
        final initResult = await camera.initialize().timeout(
          const Duration(seconds: 30),
          onTimeout: () {
            print('Camera initialization timed out after 30 seconds');
            return false;
          },
        );
        print('First initialize result: $initResult');
        expect(initResult, true, reason: 'First initialization should succeed');
        expect(camera.isInitialized, true,
            reason: 'Camera should be marked as initialized');

        // Dispose
        print('Step 2: Disposing camera...');
        camera.dispose();
        expect(camera.isInitialized, false,
            reason: 'Camera should be marked as uninitialized after dispose');

        // Reinitialize
        print('Step 3: Reinitializing camera...');
        final reinitResult = await camera.initialize().timeout(
          const Duration(seconds: 30),
          onTimeout: () {
            print('Camera reinitialization timed out after 30 seconds');
            return false;
          },
        );
        print('Reinitialize result: $reinitResult');
        expect(reinitResult, true, reason: 'Reinitialization should succeed');
        expect(camera.isInitialized, true,
            reason:
                'Camera should be marked as initialized after reinitialization');
        print('Reinitialize test completed successfully');
      } catch (e, stackTrace) {
        print('Error in reinitialize test: $e');
        print('Stack trace: $stackTrace');
        rethrow;
      }
    }, timeout: Timeout(Duration(seconds: 120)));
  });
}
