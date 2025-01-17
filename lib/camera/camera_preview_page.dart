import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'dart:async';
import 'uvc_camera.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

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
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.appTitle,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        elevation: 2,
        actions: [
          if (_selectedDeviceIndex != null)
            Tooltip(
              message: l10n.cameraSettings,
              child: IconButton(
                icon: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    _isSettingsOpen ? Icons.settings : Icons.settings_outlined,
                    key: ValueKey(_isSettingsOpen),
                  ),
                ),
                onPressed: () =>
                    setState(() => _isSettingsOpen = !_isSettingsOpen),
              ),
            ),
        ],
      ),
      body: Container(
        color: Theme.of(context).colorScheme.surface,
        child: _buildBody(context),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (_isInitializing) {
      return Center(
        child: Card(
          elevation: 4,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(
                  width: 48,
                  height: 48,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  l10n.initializingCamera,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Card(
          margin: const EdgeInsets.all(16),
          elevation: 4,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Colors.red,
                ),
                const SizedBox(height: 24),
                Text(
                  _error!,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.red,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () {
                    setState(() {
                      _error = null;
                      _isInitializing = true;
                    });
                    _initializeCamera();
                  },
                  icon: const Icon(Icons.refresh),
                  label: Text(l10n.retry),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(120, 48),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (!_camera.isInitialized) {
      return Center(
        child: Card(
          margin: const EdgeInsets.all(16),
          elevation: 4,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  size: 64,
                  color: Colors.orange,
                ),
                const SizedBox(height: 24),
                Text(
                  l10n.cameraNotInitialized,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.orange,
                      ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_devices == null || _devices!.isEmpty) {
      return Center(
        child: Card(
          margin: const EdgeInsets.all(16),
          elevation: 4,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.camera_alt_outlined,
                  size: 64,
                  color: Colors.grey,
                ),
                const SizedBox(height: 24),
                Text(
                  l10n.noDevicesFound,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _initializeCamera,
                  icon: const Icon(Icons.refresh),
                  label: Text(l10n.refresh),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(120, 48),
                  ),
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
          child: _buildPreviewArea(context),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          child: SizedBox(
            width: _isSettingsOpen && _selectedDeviceIndex != null ? 300 : 0,
            child: Card(
              margin: const EdgeInsets.all(8),
              elevation: 4,
              child: _isSettingsOpen && _selectedDeviceIndex != null
                  ? _buildSettingsPanel(context)
                  : null,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPreviewArea(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (_selectedDeviceIndex == null) {
      return Card(
        margin: const EdgeInsets.all(16),
        elevation: 4,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                l10n.selectDevice,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: _devices!.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.camera_alt_outlined,
                              size: 64,
                              color: Colors.grey,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              l10n.noDevicesFound,
                              style: Theme.of(context).textTheme.titleMedium,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            FilledButton.icon(
                              onPressed: _initializeCamera,
                              icon: const Icon(Icons.refresh),
                              label: Text(l10n.refresh),
                              style: FilledButton.styleFrom(
                                minimumSize: const Size(120, 48),
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _devices!.length,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemBuilder: (context, index) {
                          return Card(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 4,
                            ),
                            child: ListTile(
                              leading: const Icon(Icons.camera),
                              title: Text(_devices![index]),
                              subtitle: FutureBuilder<Map<String, dynamic>>(
                                future: _camera.getDeviceStatus(index),
                                builder: (context, snapshot) {
                                  if (snapshot.hasData) {
                                    final status = snapshot.data!;
                                    final isConnected =
                                        status['isConnected'] ?? false;
                                    final isAvailable =
                                        status['isAvailable'] ?? false;
                                    final error = status['error'];

                                    if (error != null) {
                                      return Text(
                                        error.toString(),
                                        style:
                                            const TextStyle(color: Colors.red),
                                      );
                                    }

                                    return Row(
                                      children: [
                                        Icon(
                                          isConnected
                                              ? Icons.check_circle
                                              : Icons.error,
                                          size: 16,
                                          color: isConnected
                                              ? Colors.green
                                              : Colors.red,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          isConnected
                                              ? (isAvailable
                                                  ? l10n.deviceNotAvailable
                                                  : l10n.deviceDisconnected)
                                              : l10n.deviceDisconnected,
                                        ),
                                      ],
                                    );
                                  }
                                  return Text(l10n.checkingDeviceStatus);
                                },
                              ),
                              onTap: () => _startPreview(index),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 4,
      child: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                Container(
                  color: Colors.black,
                  child: Center(
                    child: Text(
                      l10n.previewArea,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
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
                          const Icon(
                            Icons.warning_amber_rounded,
                            size: 64,
                            color: Colors.orange,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _selectedDeviceStatus!['error'] ?? '设备已断开连接',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: () =>
                                _startPreview(_selectedDeviceIndex!),
                            icon: const Icon(Icons.refresh),
                            label: Text(l10n.retry),
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(120, 48),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
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
                  label: Text(l10n.stopPreview),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.red,
                    minimumSize: const Size(120, 48),
                  ),
                ),
                const SizedBox(width: 16),
                FilledButton.icon(
                  onPressed: () => _startPreview(_selectedDeviceIndex!),
                  icon: const Icon(Icons.refresh),
                  label: Text(l10n.restart),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(120, 48),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsPanel(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.cameraSettings,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => setState(() => _isSettingsOpen = false),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_selectedDeviceStatus != null) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.deviceStatus,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          _selectedDeviceStatus!['isConnected']
                              ? Icons.check_circle
                              : Icons.error,
                          size: 16,
                          color: _selectedDeviceStatus!['isConnected']
                              ? Colors.green
                              : Colors.red,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _selectedDeviceStatus!['isConnected']
                              ? l10n.deviceConnected
                              : l10n.deviceDisconnected,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          _selectedDeviceStatus!['isAvailable']
                              ? Icons.check_circle
                              : Icons.error,
                          size: 16,
                          color: _selectedDeviceStatus!['isAvailable']
                              ? Colors.green
                              : Colors.orange,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _selectedDeviceStatus!['isAvailable']
                              ? l10n.deviceAvailable
                              : l10n.deviceNotAvailable,
                        ),
                      ],
                    ),
                    if (_selectedDeviceStatus!['error'] != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        l10n.errorMessage,
                        style: const TextStyle(color: Colors.red),
                      ),
                      Text(
                        _selectedDeviceStatus!['error']!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.brightness,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Slider(
                    value: _brightness,
                    onChanged: _selectedDeviceStatus != null &&
                            _selectedDeviceStatus!['isConnected'] &&
                            _selectedDeviceStatus!['isAvailable']
                        ? (value) {
                            setState(() => _brightness = value);
                            _camera.setBrightness(value);
                          }
                        : null,
                  ),
                  Text(
                    l10n.contrast,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Slider(
                    value: _contrast,
                    onChanged: _selectedDeviceStatus != null &&
                            _selectedDeviceStatus!['isConnected'] &&
                            _selectedDeviceStatus!['isAvailable']
                        ? (value) {
                            setState(() => _contrast = value);
                            _camera.setContrast(value);
                          }
                        : null,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
