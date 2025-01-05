import 'dart:async';
import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart' as win32;
import 'win32_uvc.dart';

class UVCCamera {
  static const int VENDOR_ID = 0x2BDF;
  static const int PRODUCT_ID = 0x0101;

  bool _isInitialized = false;
  Pointer<win32.COMObject>? _deviceHandle;
  Pointer<win32.COMObject>? _graphBuilder;
  Pointer<win32.COMObject>? _mediaControl;
  StreamController<List<int>>? _frameController;

  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      final result = await _initializeDevice();
      _isInitialized = result;
      return result;
    } catch (e) {
      print('Failed to initialize camera: $e');
      return false;
    }
  }

  Future<bool> _initializeDevice() async {
    // Initialize COM with apartment threading
    final hr = win32.CoInitializeEx(nullptr, win32.COINIT_APARTMENTTHREADED);
    if (win32.FAILED(hr)) {
      if (hr == win32.RPC_E_CHANGED_MODE) {
        // COM was already initialized with a different threading model
        // We can continue in this case
        print('COM already initialized with different threading model');
      } else {
        throw Exception('Failed to initialize COM: ${hr.toRadixString(16)}');
      }
    }

    // Initialize DirectShow GUIDs
    initializeGUIDs();

    // Create system device enumerator with retry
    final ppDevEnum = calloc<Pointer<win32.COMObject>>();
    int retryCount = 0;
    int createHr;

    do {
      createHr = win32.CoCreateInstance(
        clsidSystemDeviceEnum,
        nullptr,
        win32.CLSCTX_INPROC_SERVER,
        iidCreateDevEnum,
        ppDevEnum.cast(),
      );

      if (win32.FAILED(createHr)) {
        retryCount++;
        if (retryCount >= 3) {
          throw Exception(
              'Failed to create system device enumerator after 3 attempts: ${createHr.toRadixString(16)}');
        }
        await Future.delayed(Duration(milliseconds: 100));
      }
    } while (win32.FAILED(createHr) && retryCount < 3);

    final devEnum = ICreateDevEnum(ppDevEnum.value);

    // Create class enumerator for video input devices
    final ppEnumMoniker = calloc<Pointer<win32.COMObject>>();
    try {
      final hr = devEnum.createClassEnumerator(
          clsidVideoInputDeviceCategory, ppEnumMoniker, 0);

      if (win32.FAILED(hr)) {
        throw Exception('Failed to create class enumerator');
      }

      final enumMoniker = IEnumMoniker(ppEnumMoniker.value);

      // Enumerate video input devices
      final ppMoniker = calloc<Pointer<win32.COMObject>>();
      final pFetched = calloc<Uint32>();
      try {
        while (enumMoniker.next(1, ppMoniker, pFetched) == win32.S_OK) {
          if (pFetched.value == 0) break;

          final moniker = IMoniker(ppMoniker.value);
          final ppPropertyBag = calloc<Pointer<win32.COMObject>>();
          try {
            final hr = moniker.bindToStorage(
                nullptr, nullptr, iidPropertyBag, ppPropertyBag);

            if (win32.SUCCEEDED(hr)) {
              final propertyBag = IPropertyBag(ppPropertyBag.value);
              final variant = calloc<win32.VARIANT>();
              try {
                final propName = 'DevicePath'.toNativeUtf16();
                final hr = propertyBag.read(propName, variant, nullptr);
                calloc.free(propName);

                if (win32.SUCCEEDED(hr)) {
                  final devicePath = variant.ref.bstrVal.toDartString();
                  if (devicePath
                          .contains('VID_${VENDOR_ID.toRadixString(16)}') &&
                      devicePath
                          .contains('PID_${PRODUCT_ID.toRadixString(16)}')) {
                    _deviceHandle = ppMoniker.value;
                    return true;
                  }
                }
              } finally {
                calloc.free(variant);
                propertyBag.release();
              }
            }
          } finally {
            calloc.free(ppPropertyBag);
            moniker.release();
          }
        }
      } finally {
        calloc.free(ppMoniker);
        calloc.free(pFetched);
        enumMoniker.release();
      }
    } finally {
      calloc.free(ppEnumMoniker);
      devEnum.release();
    }

    return false;
  }

  Future<void> startPreview() async {
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
    } catch (e) {
      print('Failed to start preview: $e');
      await stopPreview();
      rethrow;
    }
  }

  Future<void> stopPreview() async {
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

  bool get isInitialized => _isInitialized;
}
