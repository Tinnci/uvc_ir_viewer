import 'dart:async';
import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart' as win32;
import 'win32_uvc.dart';

class UVCCamera {
  /// 设备供应商 ID
  static const int VENDOR_ID = 0x2BDF;

  /// 设备产品 ID
  static const int PRODUCT_ID = 0x0101;

  bool _isInitialized = false;
  bool _isPreviewStarted = false;
  bool _skipComInit = false;
  Pointer<win32.COMObject>? _deviceHandle;
  Pointer<win32.COMObject>? _graphBuilder;
  Pointer<win32.COMObject>? _mediaControl;
  StreamController<List<int>>? _frameController;

  UVCCamera({bool skipComInit = false}) {
    _skipComInit = skipComInit;
    // Initialize GUIDs first
    initializeGUIDs();
  }

  bool get isInitialized => _isInitialized;
  bool get isPreviewStarted => _isPreviewStarted;

  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      print('Starting camera initialization...');
      final result = await _initializeDevice();
      _isInitialized = result;
      print('Camera initialization completed with result: $result');
      return result;
    } catch (e, stackTrace) {
      print('Failed to initialize camera: $e');
      print('Stack trace: $stackTrace');
      return false;
    }
  }

  Future<bool> _initializeDevice() async {
    if (!_skipComInit) {
      print('Initializing COM...');
      // Initialize COM with multi-threaded model
      final hr = win32.CoInitializeEx(nullptr, win32.COINIT_MULTITHREADED);
      if (win32.FAILED(hr)) {
        if (hr == win32.RPC_E_CHANGED_MODE) {
          // COM was already initialized with a different threading model
          print(
              'COM already initialized with different threading model: 0x${hr.toRadixString(16)}');
        } else {
          final errorMsg =
              'Failed to initialize COM: 0x${hr.toRadixString(16)}';
          print(errorMsg);
          throw Exception(errorMsg);
        }
      } else {
        print(
            'COM initialized successfully with hr: 0x${hr.toRadixString(16)}');
      }
    } else {
      print('Skipping COM initialization as requested');
    }

    Pointer<win32.COMObject>? devEnum;
    Pointer<win32.COMObject>? enumMoniker;
    bool success = false;

    try {
      // Initialize DirectShow GUIDs
      print('Initializing DirectShow GUIDs...');
      initializeGUIDs();
      print('DirectShow GUIDs initialized successfully');

      // Create system device enumerator with retry
      print('Creating system device enumerator...');
      final ppDevEnum = calloc<Pointer<win32.COMObject>>();
      try {
        int retryCount = 0;
        int createHr;

        do {
          print(
              'Attempt ${retryCount + 1} to create system device enumerator...');
          createHr = win32.CoCreateInstance(
            clsidSystemDeviceEnum,
            nullptr,
            win32.CLSCTX_INPROC_SERVER,
            iidCreateDevEnum,
            ppDevEnum.cast(),
          );

          if (win32.FAILED(createHr)) {
            print(
                'Failed to create system device enumerator, attempt ${retryCount + 1}: 0x${createHr.toRadixString(16)}');
            print(
                'CLSID_SystemDeviceEnum: ${clsidSystemDeviceEnum.toString()}');
            print('IID_ICreateDevEnum: ${iidCreateDevEnum.toString()}');
            retryCount++;
            if (retryCount >= 3) {
              throw Exception(
                  'Failed to create system device enumerator after 3 attempts: 0x${createHr.toRadixString(16)}');
            }
            await Future.delayed(Duration(milliseconds: 100));
          } else {
            print(
                'System device enumerator created successfully with hr: 0x${createHr.toRadixString(16)}');
            devEnum = ppDevEnum.value;
          }
        } while (win32.FAILED(createHr) && retryCount < 3);

        final createDevEnum = ICreateDevEnum(devEnum!);

        // Create class enumerator for video input devices
        print('Creating class enumerator for video input devices...');
        final ppEnumMoniker = calloc<Pointer<win32.COMObject>>();
        try {
          final hr = createDevEnum.createClassEnumerator(
              clsidVideoInputDeviceCategory, ppEnumMoniker, 0);

          if (win32.FAILED(hr)) {
            final errorMsg =
                'Failed to create class enumerator: 0x${hr.toRadixString(16)}';
            print(errorMsg);
            throw Exception(errorMsg);
          }
          print(
              'Class enumerator created successfully with hr: 0x${hr.toRadixString(16)}');

          enumMoniker = ppEnumMoniker.value;
          final enumMonikerInterface = IEnumMoniker(enumMoniker!);

          // Enumerate video input devices
          final ppMoniker = calloc<Pointer<win32.COMObject>>();
          final pFetched = calloc<Uint32>();
          try {
            print('Starting to enumerate video input devices');
            while (enumMonikerInterface.next(1, ppMoniker, pFetched) ==
                win32.S_OK) {
              if (pFetched.value == 0) break;
              print('Found a video input device');

              final moniker = IMoniker(ppMoniker.value);
              final ppPropertyBag = calloc<Pointer<win32.COMObject>>();
              try {
                print('Binding moniker to storage...');
                final hr = moniker.bindToStorage(
                    nullptr, nullptr, iidPropertyBag, ppPropertyBag);

                if (win32.SUCCEEDED(hr)) {
                  print('Successfully bound moniker to storage');
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
                      print('Device friendly name: $friendlyName');
                    }

                    final propName = 'DevicePath'.toNativeUtf16();
                    final hr = propertyBag.read(propName, variant, nullptr);
                    calloc.free(propName);

                    if (win32.SUCCEEDED(hr)) {
                      final devicePath = variant.ref.bstrVal.toDartString();
                      print('Device path: $devicePath');
                      print(
                          'Checking against VID_${VENDOR_ID.toRadixString(16).padLeft(4, '0')} and PID_${PRODUCT_ID.toRadixString(16).padLeft(4, '0')}');

                      final vidPattern =
                          'VID_${VENDOR_ID.toRadixString(16).padLeft(4, '0')}';
                      final pidPattern =
                          'PID_${PRODUCT_ID.toRadixString(16).padLeft(4, '0')}';

                      final hasVid = devicePath
                          .toUpperCase()
                          .contains(vidPattern.toUpperCase());
                      final hasPid = devicePath
                          .toUpperCase()
                          .contains(pidPattern.toUpperCase());

                      print('VID match: $hasVid');
                      print('PID match: $hasPid');

                      if (hasVid && hasPid) {
                        print('Found matching device: $friendlyName');
                        print('Device path: $devicePath');
                        _deviceHandle = ppMoniker.value;
                        success = true;
                        break;
                      }
                    } else {
                      print(
                          'Failed to read device path: 0x${hr.toRadixString(16)}');
                    }
                  } finally {
                    calloc.free(variant);
                    propertyBag.release();
                  }
                } else {
                  print('Failed to bind to storage: 0x${hr.toRadixString(16)}');
                }
              } finally {
                calloc.free(ppPropertyBag);
                if (!success) {
                  moniker.release();
                }
              }
            }
            if (!success) {
              print('No matching device found');
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
      print('Error in _initializeDevice: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    } finally {
      if (enumMoniker != null && !success) {
        final enumMonikerInterface = IEnumMoniker(enumMoniker);
        enumMonikerInterface.release();
      }
      if (devEnum != null && !success) {
        final createDevEnum = ICreateDevEnum(devEnum);
        createDevEnum.release();
      }
    }

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
          win32.CLSCTX_INPROC_SERVER,
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
            win32.CLSCTX_INPROC_SERVER,
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
      print('Failed to start preview: $e');
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
      print('Failed to stop preview: $e');
      return false;
    }
  }

  void dispose() {
    stopPreview();
    if (_deviceHandle != null) {
      final moniker = IMoniker(_deviceHandle!);
      moniker.release();
      _deviceHandle = null;
    }
    win32.CoUninitialize();
    _isInitialized = false;
  }
}
