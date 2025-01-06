import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'uvc_camera.dart';

class CameraPreviewPage extends StatefulWidget {
  const CameraPreviewPage({super.key});

  @override
  State<CameraPreviewPage> createState() => _CameraPreviewPageState();
}

class _CameraPreviewPageState extends State<CameraPreviewPage> {
  final UVCCamera _camera = UVCCamera();
  final _logger = Logger('CameraPreviewPage');
  bool _isInitializing = true;
  String? _error;
  List<String>? _devices;
  int? _selectedDeviceIndex;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      await _camera.initialize();
      final devices = await _camera.enumerateDevices();
      if (mounted) {
        setState(() {
          _devices = devices;
          _isInitializing = false;
          _error = null;
        });
      }
    } catch (e) {
      _logger.severe('Failed to initialize camera', e);
      if (mounted) {
        setState(() {
          _isInitializing = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _startPreview(int deviceIndex) async {
    try {
      await _camera.openDevice(deviceIndex);
      if (mounted) {
        setState(() {
          _selectedDeviceIndex = deviceIndex;
        });
      }
    } catch (e) {
      _logger.severe('Failed to start preview', e);
      if (mounted) {
        setState(() {
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _stopPreview() async {
    try {
      await _camera.closeDevice();
      if (mounted) {
        setState(() {
          _selectedDeviceIndex = null;
        });
      }
    } catch (e) {
      _logger.severe('Failed to stop preview', e);
      if (mounted) {
        setState(() {
          _error = e.toString();
        });
      }
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

    if (_devices == null || _devices!.isEmpty) {
      return const Text('No cameras found');
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (_selectedDeviceIndex == null) ...[
          const Text('Select a camera:'),
          const SizedBox(height: 16),
          ...List.generate(
            _devices!.length,
            (index) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: ElevatedButton(
                onPressed: () => _startPreview(index),
                child: Text(_devices![index]),
              ),
            ),
          ),
        ] else ...[
          Expanded(
            child: Container(
              color: Colors.black,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (_camera.isPreviewStarted)
                    const Text(
                      'Preview Active',
                      style: TextStyle(color: Colors.white),
                    )
                  else
                    const CircularProgressIndicator(),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: _stopPreview,
                  child: const Text('Stop Preview'),
                ),
                ElevatedButton(
                  onPressed: () => _startPreview(_selectedDeviceIndex!),
                  child: const Text('Restart Preview'),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
