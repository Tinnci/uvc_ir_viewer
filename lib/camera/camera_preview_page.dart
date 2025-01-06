import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'dart:async';
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
  double _brightness = 0.5;
  double _contrast = 0.5;
  bool _isSettingsOpen = false;
  Timer? _statusCheckTimer;
  Map<String, dynamic>? _selectedDeviceStatus;

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
    _statusCheckTimer =
        Timer.periodic(const Duration(seconds: 2), (timer) async {
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
      if (mounted) {
        setState(() {
          _selectedDeviceIndex = deviceIndex;
          _selectedDeviceStatus = status;
          _error = null;
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
    _statusCheckTimer?.cancel();
    _camera.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('UVC IR Camera Preview'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          if (_selectedDeviceIndex != null)
            IconButton(
              icon: Icon(
                  _isSettingsOpen ? Icons.settings_outlined : Icons.settings),
              onPressed: () =>
                  setState(() => _isSettingsOpen = !_isSettingsOpen),
              tooltip: '相机设置',
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isInitializing) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('正在初始化相机...'),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Card(
          margin: const EdgeInsets.all(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                Text(_error!, style: const TextStyle(color: Colors.red)),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () {
                    setState(() {
                      _error = null;
                      _isInitializing = true;
                    });
                    _initializeCamera();
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('重试'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (!_camera.isInitialized) {
      return const Center(child: Text('相机未初始化'));
    }

    if (_devices == null || _devices!.isEmpty) {
      return Center(
        child: Card(
          margin: const EdgeInsets.all(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.camera_alt_outlined,
                    size: 48, color: Colors.grey),
                const SizedBox(height: 16),
                const Text('未找到可用的相机设备'),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _initializeCamera,
                  icon: const Icon(Icons.refresh),
                  label: const Text('刷新'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        Expanded(
          flex: 3,
          child: _buildPreviewArea(),
        ),
        if (_isSettingsOpen && _selectedDeviceIndex != null)
          SizedBox(
            width: 300,
            child: Card(
              margin: const EdgeInsets.all(8),
              child: _buildSettingsPanel(),
            ),
          ),
      ],
    );
  }

  Widget _buildPreviewArea() {
    if (_selectedDeviceIndex == null) {
      return Card(
        margin: const EdgeInsets.all(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('选择相机设备：',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: _devices?.length ?? 0,
                  itemBuilder: (context, index) => Card(
                    margin:
                        const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                    child: ListTile(
                      leading: const Icon(Icons.camera),
                      title: Text(_devices![index]),
                      onTap: () => _startPreview(index),
                      trailing: FutureBuilder<Map<String, dynamic>>(
                        future: _camera.getDeviceStatus(index),
                        builder: (context, snapshot) {
                          if (snapshot.hasData) {
                            final status = snapshot.data!;
                            final isAvailable = status['isAvailable'] as bool;
                            return Icon(
                              isAvailable ? Icons.check_circle : Icons.error,
                              color: isAvailable ? Colors.green : Colors.red,
                            );
                          }
                          return const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildDeviceStatus(),
          Expanded(
            child: Container(
              color: Colors.black,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (_camera.isPreviewStarted)
                    const Center(
                        child:
                            Text('预览画面', style: TextStyle(color: Colors.white)))
                  else
                    const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: Colors.white),
                        SizedBox(height: 16),
                        Text('正在启动预览...',
                            style: TextStyle(color: Colors.white)),
                      ],
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FilledButton.icon(
                  onPressed: _stopPreview,
                  icon: const Icon(Icons.stop),
                  label: const Text('停止预览'),
                ),
                const SizedBox(width: 16),
                FilledButton.icon(
                  onPressed: () => _startPreview(_selectedDeviceIndex!),
                  icon: const Icon(Icons.refresh),
                  label: const Text('重新启动'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsPanel() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('相机设置',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const Divider(),
        const SizedBox(height: 16),
        _buildSettingSlider(
          label: '亮度',
          value: _brightness,
          icon: Icons.brightness_6,
          onChanged: (value) => setState(() => _brightness = value),
        ),
        const SizedBox(height: 16),
        _buildSettingSlider(
          label: '对比度',
          value: _contrast,
          icon: Icons.contrast,
          onChanged: (value) => setState(() => _contrast = value),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: () {
            // TODO: 实现图像保存功能
          },
          icon: const Icon(Icons.photo_camera),
          label: const Text('拍照'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () {
            // TODO: 实现录制功能
          },
          icon: const Icon(Icons.videocam),
          label: const Text('录制'),
        ),
      ],
    );
  }

  Widget _buildSettingSlider({
    required String label,
    required double value,
    required IconData icon,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20),
            const SizedBox(width: 8),
            Text(label),
          ],
        ),
        Slider(
          value: value,
          onChanged: onChanged,
          divisions: 100,
          label: (value * 100).toStringAsFixed(0),
        ),
      ],
    );
  }

  Widget _buildDeviceStatus() {
    if (_selectedDeviceStatus == null) return const SizedBox.shrink();

    final status = _selectedDeviceStatus!;
    final isConnected = status['isConnected'] as bool;
    final isAvailable = status['isAvailable'] as bool;
    final deviceName = status['deviceName'] as String;
    final error = status['error'] as String?;

    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('设备名称: $deviceName',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  isConnected ? Icons.check_circle : Icons.error,
                  color: isConnected ? Colors.green : Colors.red,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text('连接状态: ${isConnected ? "已连接" : "未连接"}'),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  isAvailable ? Icons.check_circle : Icons.error,
                  color: isAvailable ? Colors.green : Colors.red,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text('设备状态: ${isAvailable ? "正常" : "异常"}'),
              ],
            ),
            if (error != null) ...[
              const SizedBox(height: 8),
              Text('错误信息: $error',
                  style: const TextStyle(color: Colors.red, fontSize: 12)),
            ],
          ],
        ),
      ),
    );
  }
}
