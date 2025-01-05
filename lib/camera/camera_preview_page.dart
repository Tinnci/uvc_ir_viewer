import 'package:flutter/material.dart';
import 'uvc_camera.dart';

class CameraPreviewPage extends StatefulWidget {
  const CameraPreviewPage({super.key});

  @override
  State<CameraPreviewPage> createState() => _CameraPreviewPageState();
}

class _CameraPreviewPageState extends State<CameraPreviewPage> {
  final UVCCamera _camera = UVCCamera();
  bool _isInitializing = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      final initialized = await _camera.initialize();
      if (initialized) {
        await _camera.startPreview();
      } else {
        setState(() {
          _error = 'Failed to initialize camera';
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error: $e';
      });
    } finally {
      setState(() {
        _isInitializing = false;
      });
    }
  }

  @override
  void dispose() {
    _camera.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('UVC IR Camera Preview'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Center(
        child: _buildPreviewWidget(),
      ),
    );
  }

  Widget _buildPreviewWidget() {
    if (_isInitializing) {
      return const CircularProgressIndicator();
    }

    if (_error != null) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 16),
          Text(_error!, style: const TextStyle(color: Colors.red)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _error = null;
                _isInitializing = true;
              });
              _initializeCamera();
            },
            child: const Text('Retry'),
          ),
        ],
      );
    }

    if (!_camera.isInitialized) {
      return const Text('Camera not initialized');
    }

    // TODO: Implement camera preview widget
    return Container(
      color: Colors.black,
      child: const Center(
        child: Text(
          'Camera Preview',
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
  }
}
