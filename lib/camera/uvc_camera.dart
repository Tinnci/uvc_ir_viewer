import 'dart:async';
import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart' as win32;
import 'package:logging/logging.dart';
import 'win32_uvc.dart';

class UVCCamera {
  static final _logger = Logger('UVCCamera');

  /// 设备供应商 ID
  static const vendorId = 0x2BDF;

  /// 设备产品 ID
  static const productId = 0x0101;

  bool _isInitialized = false;
  bool _isPreviewStarted = false;
  bool _skipComInit = false;
  Pointer<win32.COMObject>? _deviceHandle;
  Pointer<win32.COMObject>? _graphBuilder;
  Pointer<win32.COMObject>? _mediaControl;
  StreamController<List<int>>? _frameController;

  UVCCamera({bool skipComInit = false}) {
    _logger.info('UVCCamera constructor called with skipComInit: $skipComInit');
    _skipComInit = skipComInit;
    try {
      // Initialize GUIDs first
      _logger.info('Initializing GUIDs in constructor...');
      initializeGUIDs();
      _logger.info('GUIDs initialized successfully in constructor');
    } catch (e, stackTrace) {
      _logger.severe(
          'Error initializing GUIDs in constructor: $e', e, stackTrace);
      rethrow;
    }
  }

  bool get isInitialized => _isInitialized;
  bool get isPreviewStarted => _isPreviewStarted;

  Future<bool> initialize() async {
    _logger.info(
        'Initialize called, current state: isInitialized=$_isInitialized');
    if (_isInitialized) {
      _logger.info('Camera already initialized, returning true');
      return true;
    }

    try {
      _logger.info('Starting camera initialization...');
      final result = await _initializeDevice();
      _isInitialized = result;
      _logger.info('Camera initialization completed with result: $result');
      return result;
    } catch (e, stackTrace) {
      _logger.severe('Failed to initialize camera', e, stackTrace);
      _isInitialized = false;
      return false;
    }
  }

  Future<bool> _initializeDevice() async {
    _logger.info('_initializeDevice called');
    if (!_skipComInit) {
      _logger.info('Initializing COM...');
      try {
        // Initialize COM with multi-threaded model
        final hr =
            win32.CoInitializeEx(nullptr, win32.COINIT.COINIT_MULTITHREADED);
        if (win32.FAILED(hr)) {
          if (hr == win32.RPC_E_CHANGED_MODE) {
            // COM was already initialized with a different threading model
            _logger.warning(
                'COM already initialized with different threading model: 0x${hr.toRadixString(16)}');
          } else {
            final errorMsg =
                'Failed to initialize COM: 0x${hr.toRadixString(16)}';
            _logger.severe(errorMsg);
            throw Exception(errorMsg);
          }
        } else {
          _logger.info(
              'COM initialized successfully with hr: 0x${hr.toRadixString(16)}');
        }
      } catch (e, stackTrace) {
        _logger.severe('Error during COM initialization', e, stackTrace);
        rethrow;
      }
    } else {
      _logger.info('Skipping COM initialization as requested');
    }

    Pointer<win32.COMObject>? devEnum;
    Pointer<win32.COMObject>? enumMoniker;
    bool success = false;

    try {
      // Initialize DirectShow GUIDs
      _logger.info('Initializing DirectShow GUIDs...');
      try {
        initializeGUIDs();
        _logger.info('DirectShow GUIDs initialized successfully');
      } catch (e, stackTrace) {
        _logger.severe('Error initializing DirectShow GUIDs', e, stackTrace);
        rethrow;
      }

      // Create system device enumerator with retry
      _logger.info('Creating system device enumerator...');
      final ppDevEnum = calloc<Pointer<win32.COMObject>>();
      try {
        int retryCount = 0;
        int createHr;

        do {
          _logger.info(
              'Attempt ${retryCount + 1} to create system device enumerator...');
          try {
            createHr = win32.CoCreateInstance(
              clsidSystemDeviceEnum,
              nullptr,
              win32.CLSCTX.CLSCTX_INPROC_SERVER,
              iidCreateDevEnum,
              ppDevEnum.cast(),
            );

            if (win32.FAILED(createHr)) {
              _logger.warning(
                  'Failed to create system device enumerator, attempt ${retryCount + 1}: 0x${createHr.toRadixString(16)}');
              _logger.info(
                  'CLSID_SystemDeviceEnum: ${clsidSystemDeviceEnum.toString()}');
              _logger
                  .info('IID_ICreateDevEnum: ${iidCreateDevEnum.toString()}');
              retryCount++;
              if (retryCount >= 3) {
                throw Exception(
                    'Failed to create system device enumerator after 3 attempts: 0x${createHr.toRadixString(16)}');
              }
              await Future.delayed(const Duration(milliseconds: 100));
            } else {
              _logger.info(
                  'System device enumerator created successfully with hr: 0x${createHr.toRadixString(16)}');
              devEnum = ppDevEnum.value;
              break;
            }
          } catch (e, stackTrace) {
            _logger.severe('Error during system device enumerator creation', e,
                stackTrace);
            rethrow;
          }
        } while (retryCount < 3);

        if (devEnum == null) {
          throw Exception('Failed to create system device enumerator');
        }

        final createDevEnum = ICreateDevEnum(devEnum);

        // Create class enumerator for video input devices
        _logger.info('Creating class enumerator for video input devices...');
        final ppEnumMoniker = calloc<Pointer<win32.COMObject>>();
        try {
          final hr = createDevEnum.createClassEnumerator(
              clsidVideoInputDeviceCategory, ppEnumMoniker, 0);

          if (win32.FAILED(hr)) {
            final errorMsg =
                'Failed to create class enumerator: 0x${hr.toRadixString(16)}';
            _logger.severe(errorMsg);
            throw Exception(errorMsg);
          }
          _logger.info(
              'Class enumerator created successfully with hr: 0x${hr.toRadixString(16)}');

          enumMoniker = ppEnumMoniker.value;
          final enumMonikerInterface = IEnumMoniker(enumMoniker);

          // Enumerate video input devices
          final ppMoniker = calloc<Pointer<win32.COMObject>>();
          final pFetched = calloc<Uint32>();
          try {
            _logger.info('Starting to enumerate video input devices');
            while (enumMonikerInterface.next(1, ppMoniker, pFetched) ==
                win32.S_OK) {
              if (pFetched.value == 0) {
                _logger.info('No more devices to enumerate');
                break;
              }
              _logger.info('Found a video input device');

              final moniker = IMoniker(ppMoniker.value);
              final ppPropertyBag = calloc<Pointer<win32.COMObject>>();
              try {
                _logger.info('Binding moniker to storage...');
                final hr = moniker.bindToStorage(
                    nullptr, nullptr, iidPropertyBag, ppPropertyBag);

                if (win32.SUCCEEDED(hr)) {
                  _logger.info('Successfully bound moniker to storage');
                  final propertyBag = IPropertyBag(ppPropertyBag.value);
                  final variant = calloc<win32.VARIANT>();
                  try {
                    // Read friendly name first for better logging
                    final friendlyNameProp = 'FriendlyName'.toNativeUtf16();
                    final hrName =
                        propertyBag.read(friendlyNameProp, variant, nullptr);
                    calloc.free(friendlyNameProp);

                    String friendlyName = 'Unknown';
                    if (win32.SUCCEEDED(hrName)) {
                      friendlyName = variant.ref.bstrVal.toDartString();
                      _logger.info('Device friendly name: $friendlyName');
                    }

                    final propName = 'DevicePath'.toNativeUtf16();
                    final hr = propertyBag.read(propName, variant, nullptr);
                    calloc.free(propName);

                    if (win32.SUCCEEDED(hr)) {
                      final devicePath = variant.ref.bstrVal.toDartString();
                      _logger.info('Device path: $devicePath');
                      _logger.info(
                          'Checking against VID_${vendorId.toRadixString(16).padLeft(4, '0')} and PID_${productId.toRadixString(16).padLeft(4, '0')}');

                      final vidPattern =
                          'VID_${vendorId.toRadixString(16).padLeft(4, '0')}';
                      final pidPattern =
                          'PID_${productId.toRadixString(16).padLeft(4, '0')}';

                      final hasVid = devicePath
                          .toUpperCase()
                          .contains(vidPattern.toUpperCase());
                      final hasPid = devicePath
                          .toUpperCase()
                          .contains(pidPattern.toUpperCase());

                      _logger.info('VID match: $hasVid');
                      _logger.info('PID match: $hasPid');

                      if (hasVid && hasPid) {
                        _logger.info('Found matching device: $friendlyName');
                        _logger.info('Device path: $devicePath');
                        _deviceHandle = ppMoniker.value;
                        success = true;
                        break;
                      }
                    } else {
                      _logger.warning(
                          'Failed to read device path: 0x${hr.toRadixString(16)}');
                    }
                  } finally {
                    calloc.free(variant);
                    propertyBag.release();
                  }
                } else {
                  _logger.warning(
                      'Failed to bind to storage: 0x${hr.toRadixString(16)}');
                }
              } finally {
                calloc.free(ppPropertyBag);
                if (!success) {
                  moniker.release();
                }
              }
            }
            if (!success) {
              _logger.warning('No matching device found');
            }
          } finally {
            calloc.free(ppMoniker);
            calloc.free(pFetched);
          }
        } finally {
          calloc.free(ppEnumMoniker);
        }
      } finally {
        calloc.free(ppDevEnum);
      }
    } catch (e, stackTrace) {
      _logger.severe('Error in _initializeDevice', e, stackTrace);
      rethrow;
    } finally {
      if (enumMoniker != null && !success) {
        try {
          final enumMonikerInterface = IEnumMoniker(enumMoniker);
          enumMonikerInterface.release();
        } catch (e) {
          _logger.warning('Error releasing enumMoniker: $e');
        }
      }
      if (devEnum != null && !success) {
        try {
          final createDevEnum = ICreateDevEnum(devEnum);
          createDevEnum.release();
        } catch (e) {
          _logger.warning('Error releasing devEnum: $e');
        }
      }
    }

    _logger.info('_initializeDevice returning with success=$success');
    return success;
  }

  Future<bool> startPreview() async {
    if (!_isInitialized || _deviceHandle == null) {
      throw Exception('Camera not initialized');
    }

    try {
      // Create filter graph manager
      final ppGraph = calloc<Pointer<win32.COMObject>>();
      try {
        final hr = win32.CoCreateInstance(
          clsidFilterGraph,
          nullptr,
          win32.CLSCTX.CLSCTX_INPROC_SERVER,
          iidGraphBuilder,
          ppGraph.cast(),
        );

        if (win32.FAILED(hr)) {
          throw Exception('Failed to create filter graph manager');
        }

        _graphBuilder = ppGraph.value;
        final graphBuilder = IGraphBuilder(_graphBuilder!);

        // Add source filter
        final moniker = IMoniker(_deviceHandle!);
        final ppFilter = calloc<Pointer<win32.COMObject>>();
        try {
          final hr =
              moniker.bindToStorage(nullptr, nullptr, iidBaseFilter, ppFilter);

          if (win32.FAILED(hr)) {
            throw Exception('Failed to create source filter');
          }

          final filterName = 'UVC Camera'.toNativeUtf16();
          final hr2 = graphBuilder.addFilter(ppFilter.value, filterName);
          calloc.free(filterName);

          if (win32.FAILED(hr2)) {
            throw Exception('Failed to add source filter to graph');
          }
        } finally {
          calloc.free(ppFilter);
        }

        // Query media control interface
        final ppControl = calloc<Pointer<win32.COMObject>>();
        try {
          final hr = win32.CoCreateInstance(
            clsidFilterGraph,
            nullptr,
            win32.CLSCTX.CLSCTX_INPROC_SERVER,
            iidMediaControl,
            ppControl.cast(),
          );

          if (win32.FAILED(hr)) {
            throw Exception('Failed to create media control');
          }

          _mediaControl = ppControl.value;
          final mediaControl = IMediaControl(_mediaControl!);

          // Run the graph
          final hr2 = mediaControl.run();
          if (win32.FAILED(hr2)) {
            throw Exception('Failed to start media streaming');
          }
        } finally {
          calloc.free(ppControl);
        }
      } finally {
        calloc.free(ppGraph);
      }
      _isPreviewStarted = true;
      return true;
    } catch (e) {
      _logger.severe('Failed to start preview: $e');
      _isPreviewStarted = false;
      await stopPreview();
      return false;
    }
  }

  Future<bool> stopPreview() async {
    try {
      if (_mediaControl != null) {
        final mediaControl = IMediaControl(_mediaControl!);
        mediaControl.stop();
        mediaControl.release();
        _mediaControl = null;
      }

      if (_graphBuilder != null) {
        final graphBuilder = IGraphBuilder(_graphBuilder!);
        graphBuilder.release();
        _graphBuilder = null;
      }

      _frameController?.close();
      _frameController = null;
      _isPreviewStarted = false;
      return true;
    } catch (e) {
      _logger.severe('Failed to stop preview: $e');
      return false;
    }
  }

  void dispose() {
    _logger.info('Dispose called');
    try {
      stopPreview();
      if (_deviceHandle != null) {
        try {
          final moniker = IMoniker(_deviceHandle!);
          moniker.release();
          _deviceHandle = null;
        } catch (e) {
          _logger.warning('Error releasing device handle: $e');
        }
      }
      if (!_skipComInit) {
        try {
          win32.CoUninitialize();
        } catch (e) {
          _logger.warning('Error uninitializing COM: $e');
        }
      }
      _isInitialized = false;
      _logger.info('Dispose completed successfully');
    } catch (e, stackTrace) {
      _logger.severe('Error in dispose', e, stackTrace);
    }
  }
}
