import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'uvc_camera.dart';
import 'camera_interface.dart';
import 'package:uvc_ir_viewer/l10n/app_localizations.dart';

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
  double _brightness = 0.5;
  double _contrast = 0.5;
  Timer? _statusCheckTimer;
  Map<String, dynamic>? _selectedDeviceStatus;
  int? _textureId;
  bool _isCapturing = false;
  List<CameraResolution> _supportedResolutions = [];
  CameraResolution? _selectedResolution;
  StreamSubscription<String>? _deviceChangeSubscription;

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
        _startStatusCheck();
        _subscribeToDeviceChanges();
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

  void _startStatusCheck() {
    _statusCheckTimer?.cancel();
    _statusCheckTimer = Timer.periodic(const Duration(seconds: 2), (
      timer,
    ) async {
      if (_selectedDeviceIndex != null) {
        final status = await _camera.getDeviceStatus(_selectedDeviceIndex!);
        if (mounted) {
          setState(() {
            _selectedDeviceStatus = status;
            if (!status['isConnected'] || !status['isAvailable']) {
              _error = status['error'] ?? '设备已断开连接';
              _selectedDeviceIndex = null;
            }
          });
        }
      }
    });
  }

  Future<void> _startPreview(int deviceIndex) async {
    try {
      final status = await _camera.getDeviceStatus(deviceIndex);
      if (!status['isConnected'] || !status['isAvailable']) {
        throw Exception(status['error'] ?? '设备不可用');
      }

      await _camera.openDevice(deviceIndex);
      final textureId = await _camera.getTextureId();

      if (mounted) {
        setState(() {
          _selectedDeviceIndex = deviceIndex;
          _selectedDeviceStatus = status;
          _textureId = textureId;
          _error = null;
        });
        // 获取支持的分辨率
        final resolutions = await _camera.getSupportedResolutions();
        if (mounted) {
          setState(() {
            _supportedResolutions = resolutions;
            // Set initial resolution if not already set
            if (_selectedResolution == null && resolutions.isNotEmpty) {
              _selectedResolution =
                  _camera.currentResolution ?? resolutions.first;
            }
          });
        }
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
          _textureId = null;
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
    _statusCheckTimer?.cancel();
    _deviceChangeSubscription?.cancel();
    _camera.dispose();
    super.dispose();
  }

  void _subscribeToDeviceChanges() {
    _deviceChangeSubscription =
        _camera.onDeviceChanged.listen((changeType) async {
      _logger.info('Device changed: $changeType');
      // Re-enumerate devices when a device is connected or disconnected
      try {
        final devices = await _camera.enumerateDevices();
        if (mounted) {
          setState(() {
            _devices = devices;
          });
          // If the current device was disconnected, show error
          if (changeType == 'disconnected' && _selectedDeviceIndex != null) {
            final status = await _camera.getDeviceStatus(_selectedDeviceIndex!);
            if (!status['isConnected'] || !status['isAvailable']) {
              setState(() {
                _error = 'Device disconnected';
                _selectedDeviceIndex = null;
                _textureId = null;
              });
            }
          }
          // Show snackbar notification
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(changeType == 'connected'
                    ? 'Device connected'
                    : 'Device disconnected'),
                duration: const Duration(seconds: 2),
                backgroundColor:
                    changeType == 'connected' ? Colors.green : Colors.orange,
              ),
            );
          }
        }
      } catch (e) {
        _logger.severe('Failed to handle device change', e);
      }
    });
  }

  Future<void> _capturePhoto() async {
    if (_isCapturing) return;

    setState(() => _isCapturing = true);

    try {
      final photoData = await _camera.capturePhoto();
      if (photoData != null && photoData.isNotEmpty) {
        // 保存到文件
        final directory = await getApplicationDocumentsDirectory();
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final filePath = '${directory.path}/capture_$timestamp.bmp';

        // 创建BMP文件头（简化版，假设是BGRA格式）
        final width = _camera.currentResolution?.width ?? 640;
        final height = _camera.currentResolution?.height ?? 480;
        final bmpData = _createBmpFromRgba(photoData, width, height);

        final file = File(filePath);
        await file.writeAsBytes(bmpData);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('照片已保存: $filePath'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } else {
        throw Exception('Failed to capture photo');
      }
    } catch (e) {
      _logger.severe('Failed to capture photo', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('拍照失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCapturing = false);
      }
    }
  }

  Uint8List _createBmpFromRgba(Uint8List rgbaData, int width, int height) {
    // BMP文件头
    final fileSize = 54 + rgbaData.length;
    final bmp = ByteData(fileSize);

    // BMP文件头 (14 bytes)
    bmp.setUint8(0, 0x42); // 'B'
    bmp.setUint8(1, 0x4D); // 'M'
    bmp.setUint32(2, fileSize, Endian.little);
    bmp.setUint32(6, 0, Endian.little); // Reserved
    bmp.setUint32(10, 54, Endian.little); // Pixel data offset

    // DIB头 (40 bytes)
    bmp.setUint32(14, 40, Endian.little); // DIB header size
    bmp.setInt32(18, width, Endian.little);
    bmp.setInt32(22, -height, Endian.little); // 负值表示自顶向下
    bmp.setUint16(26, 1, Endian.little); // Color planes
    bmp.setUint16(28, 32, Endian.little); // Bits per pixel
    bmp.setUint32(30, 0, Endian.little); // Compression (none)
    bmp.setUint32(34, rgbaData.length, Endian.little); // Image size
    bmp.setInt32(38, 2835, Endian.little); // Horizontal resolution
    bmp.setInt32(42, 2835, Endian.little); // Vertical resolution
    bmp.setUint32(46, 0, Endian.little); // Colors in palette
    bmp.setUint32(50, 0, Endian.little); // Important colors

    // 像素数据
    final result = Uint8List(fileSize);
    result.setRange(0, 54, bmp.buffer.asUint8List());
    result.setRange(54, fileSize, rgbaData);

    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          Expanded(
            child: Container(
              color: Colors.black, // Dark background for camera preview
              child: _buildPreviewContent(context),
            ),
          ),
          _buildSidePanel(context),
        ],
      ),
    );
  }

  Widget _buildPreviewContent(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (_isInitializing) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(l10n.initializingCamera,
                style: const TextStyle(color: Colors.white70)),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
            const SizedBox(height: 16),
            Text(_error!,
                style: const TextStyle(color: Colors.redAccent),
                textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              onPressed: () {
                setState(() {
                  _error = null;
                  _isInitializing = true;
                });
                _initializeCamera();
              },
              icon: const Icon(Icons.refresh),
              label: Text(l10n.retry),
            ),
          ],
        ),
      );
    }

    if (_selectedDeviceIndex == null) {
      if (_devices == null || _devices!.isEmpty) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.camera_alt_outlined,
                  size: 64, color: Colors.white24),
              const SizedBox(height: 16),
              Text(l10n.noDevicesFound,
                  style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 16),
              FilledButton.tonalIcon(
                onPressed: _initializeCamera,
                icon: const Icon(Icons.refresh),
                label: Text(l10n.refresh),
              ),
            ],
          ),
        );
      }
      return Center(
        child: Text(l10n.selectDevice,
            style: const TextStyle(color: Colors.white70, fontSize: 18)),
      );
    }

    return Stack(
      children: [
        Center(
          child: _textureId != null
              ? AspectRatio(
                  aspectRatio: (_selectedResolution?.width ?? 640) /
                      (_selectedResolution?.height ?? 480),
                  child: Texture(textureId: _textureId!),
                )
              : const CircularProgressIndicator(),
        ),
        if (_selectedDeviceStatus != null &&
            (!_selectedDeviceStatus!['isConnected'] ||
                !_selectedDeviceStatus!['isAvailable']))
          Container(
            color: Colors.black54,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.link_off,
                      size: 64, color: Colors.orangeAccent),
                  const SizedBox(height: 16),
                  Text(
                    _selectedDeviceStatus!['error'] ?? l10n.deviceDisconnected,
                    style: const TextStyle(color: Colors.white, fontSize: 18),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSidePanel(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    // Filter out only video devices for now, or use all if logic allows
    final devicesList = _devices ?? [];

    return Container(
      width: 320,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border:
            Border(left: BorderSide(color: theme.colorScheme.outlineVariant)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // App Title Area
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Text(
              l10n.appTitle,
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                // Device Selection
                Text(l10n.selectDevice,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(color: theme.colorScheme.primary)),
                const SizedBox(height: 8),
                Card(
                  elevation: 0,
                  color: theme.colorScheme.surfaceContainer,
                  child: Column(
                    children: devicesList.asMap().entries.map((entry) {
                      final index = entry.key;
                      final name = entry.value;
                      final isSelected = index == _selectedDeviceIndex;

                      return RadioListTile<int>(
                        value: index,
                        groupValue: _selectedDeviceIndex,
                        onChanged: (val) => _startPreview(val!),
                        title: Text(name,
                            style: theme.textTheme.bodyMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        selected: isSelected,
                        activeColor: theme.colorScheme.primary,
                        secondary: isSelected && _selectedDeviceStatus != null
                            ? Icon(
                                _selectedDeviceStatus!['isConnected']
                                    ? Icons.check_circle
                                    : Icons.error,
                                color: _selectedDeviceStatus!['isConnected']
                                    ? Colors.green
                                    : Colors.red,
                                size: 16,
                              )
                            : null,
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 24),

                // Camera Settings (Resolution, Controls)
                if (_selectedDeviceIndex != null) ...[
                  Text(l10n.cameraSettings,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(color: theme.colorScheme.primary)),
                  const SizedBox(height: 8),

                  // Resolution Dropdown
                  DropdownButtonFormField<CameraResolution>(
                    value: _selectedResolution,
                    decoration: InputDecoration(
                      labelText: 'Resolution', // TODO: Add to l10n
                      border: const OutlineInputBorder(),
                      filled: true,
                      fillColor: theme.colorScheme.surfaceContainer,
                    ),
                    isExpanded: true,
                    items: _supportedResolutions.map((res) {
                      return DropdownMenuItem(
                        value: res,
                        child: Text(res.displayName),
                      );
                    }).toList(),
                    onChanged: (CameraResolution? newValue) async {
                      if (newValue != null && newValue != _selectedResolution) {
                        final deviceIndex = _selectedDeviceIndex;
                        setState(() => _selectedResolution = newValue);
                        await _camera.setResolution(newValue);
                        if (deviceIndex != null) {
                          await _stopPreview();
                          await _startPreview(deviceIndex);
                        }
                      }
                    },
                  ),
                  const SizedBox(height: 16),

                  // Image Controls
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.brightness_6, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Slider(
                          value: _brightness,
                          label: l10n.brightness,
                          onChanged: (val) {
                            setState(() => _brightness = val);
                            _camera.setBrightness(val);
                          },
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      const Icon(Icons.contrast, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Slider(
                          value: _contrast,
                          label: l10n.contrast,
                          onChanged: (val) {
                            setState(() => _contrast = val);
                            _camera.setContrast(val);
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // Bottom Controls Area
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLow,
              border: Border(
                  top: BorderSide(color: theme.colorScheme.outlineVariant)),
            ),
            child: Column(
              children: [
                if (_selectedDeviceIndex != null)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Capture Button
                      FloatingActionButton.large(
                        onPressed: _isCapturing ? null : _capturePhoto,
                        heroTag: 'capture',
                        tooltip: 'Capture Photo',
                        child: _isCapturing
                            ? const CircularProgressIndicator()
                            : const Icon(Icons.camera, size: 36),
                      ),

                      // Stop/Start Button
                      IconButton.filledTonal(
                        onPressed: _stopPreview,
                        icon: const Icon(Icons.stop),
                        tooltip: l10n.stopPreview,
                        iconSize: 28,
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
