import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart' as win32;

// Helper function for string conversion
String _convertFromUtf16(Pointer<Utf16> utf16String) {
  if (utf16String.address == 0) return '';
  return utf16String.toDartString();
}

// Windows Media Foundation GUIDs
final mfDevSourceAttrSourceType =
    win32.GUIDFromString('{C60AC5A1-4D31-4242-BFB3-8A11A7A87F48}');
final mfDevSourceAttrSourceTypeVidcapGuid =
    win32.GUIDFromString('{8AC3587A-4AE7-42D8-99E0-0A6013EE9E43}');
final mfDevSourceAttrFriendlyName =
    win32.GUIDFromString('{60D0E559-52F8-4FA2-BBCE-ACDB34A8EC01}');
final mfMtFrameSizeGuid =
    win32.GUIDFromString('{1652C33D-D6B2-4012-B834-72030849A37D}');

// Define missing constants
const int mfVersion = 0x00020070;

// Windows Media Foundation interfaces
base class IMFAttributes extends Opaque {}

base class IMFActivate extends Opaque {}

base class IMFMediaSource extends Opaque {}

base class IMFSourceReader extends Opaque {}

base class IMFMediaType extends Opaque {}

// Windows Media Foundation function types
typedef MFStartupNative = Int32 Function(Int32 version, Int32 flags);
typedef MFStartupDart = int Function(int version, int flags);

typedef MFShutdownNative = Int32 Function();
typedef MFShutdownDart = int Function();

typedef MFEnumDeviceSourcesNative = Int32 Function(
    Pointer<win32.GUID> guidCategory,
    Pointer<Pointer<Pointer<Void>>> ppDevices,
    Pointer<Uint32> pCount);
typedef MFEnumDeviceSourcesDart = int Function(Pointer<win32.GUID> guidCategory,
    Pointer<Pointer<Pointer<Void>>> ppDevices, Pointer<Uint32> pCount);

typedef MFCreateSourceReaderFromMediaSourceNative = Int32 Function(
    Pointer<Void> pMediaSource,
    Pointer<win32.GUID> pAttributes,
    Pointer<Pointer<Void>> ppSourceReader);
typedef MFCreateSourceReaderFromMediaSourceDart = int Function(
    Pointer<Void> pMediaSource,
    Pointer<win32.GUID> pAttributes,
    Pointer<Pointer<Void>> ppSourceReader);

typedef MFCreateMediaTypeNative = Int32 Function(
    Pointer<Pointer<Void>> ppMediaType);
typedef MFCreateMediaTypeDart = int Function(
    Pointer<Pointer<Void>> ppMediaType);

// Load the MF DLL
final _mfplat = DynamicLibrary.open('mfplat.dll');

// Get function pointers
final _mfStartup =
    _mfplat.lookupFunction<MFStartupNative, MFStartupDart>('MFStartup');
final _mfShutdown =
    _mfplat.lookupFunction<MFShutdownNative, MFShutdownDart>('MFShutdown');
final _mfEnumDeviceSources =
    _mfplat.lookupFunction<MFEnumDeviceSourcesNative, MFEnumDeviceSourcesDart>(
        'MFEnumDeviceSources');
final _mfCreateSourceReaderFromMediaSource = _mfplat.lookupFunction<
        MFCreateSourceReaderFromMediaSourceNative,
        MFCreateSourceReaderFromMediaSourceDart>(
    'MFCreateSourceReaderFromMediaSource');
final _mfCreateMediaType =
    _mfplat.lookupFunction<MFCreateMediaTypeNative, MFCreateMediaTypeDart>(
        'MFCreateMediaType');

extension IMFAttributesMethods on Pointer<IMFAttributes> {
  int getString(Pointer<win32.GUID> guidKey, Pointer<win32.PWSTR> ppwszValue) {
    final vtable = cast<Pointer<IntPtr>>().value;
    final getString = (vtable + 15 * sizeOf<IntPtr>())
        .cast<
            NativeFunction<
                Int32 Function(Pointer<Void>, Pointer<win32.GUID>,
                    Pointer<win32.PWSTR>)>>()
        .asFunction<
            int Function(
                Pointer<Void>, Pointer<win32.GUID>, Pointer<win32.PWSTR>)>();
    return getString(cast(), guidKey, ppwszValue);
  }

  int setUINT64(Pointer<win32.GUID> guidKey, int value) {
    final vtable = cast<Pointer<IntPtr>>().value;
    final setUINT64 = (vtable + 21 * sizeOf<IntPtr>())
        .cast<
            NativeFunction<
                Int32 Function(Pointer<Void>, Pointer<win32.GUID>, Uint64)>>()
        .asFunction<int Function(Pointer<Void>, Pointer<win32.GUID>, int)>();
    return setUINT64(cast(), guidKey, value);
  }
}

extension IMFSourceReaderMethods on Pointer<IMFSourceReader> {
  int setCurrentMediaType(int streamIndex, Pointer<win32.GUID> guid,
      Pointer<IMFMediaType> mediaType) {
    final vtable = cast<Pointer<IntPtr>>().value;
    final setCurrentMediaType = (vtable + 15 * sizeOf<IntPtr>())
        .cast<
            NativeFunction<
                Int32 Function(Pointer<Void>, Uint32, Pointer<win32.GUID>,
                    Pointer<Void>)>>()
        .asFunction<
            int Function(
                Pointer<Void>, int, Pointer<win32.GUID>, Pointer<Void>)>();
    return setCurrentMediaType(cast(), streamIndex, guid, mediaType.cast());
  }
}

class WMFCamera {
  Pointer<IMFSourceReader>? _reader;
  bool _isPreviewActive = false;
  bool _isInitialized = false;

  /// Whether the preview is currently active
  bool get isPreviewActive => _isPreviewActive;

  /// Whether the camera system is initialized
  bool get isInitialized => _isInitialized;

  Future<void> initialize() async {
    if (_isInitialized) return;

    final hr = _mfStartup(mfVersion, 0);
    if (win32.FAILED(hr)) {
      throw win32.WindowsException(hr);
    }
    _isInitialized = true;
  }

  static Future<List<String>> enumerateDevices() async {
    final hr = _mfStartup(mfVersion, 0);
    if (win32.FAILED(hr)) {
      throw win32.WindowsException(hr);
    }

    try {
      final devices = <String>[];
      final ppDevices = calloc<Pointer<Pointer<Void>>>();
      final pCount = calloc<Uint32>();

      try {
        final hr = _mfEnumDeviceSources(
            mfDevSourceAttrSourceTypeVidcapGuid.cast(), ppDevices, pCount);

        if (win32.FAILED(hr)) {
          throw win32.WindowsException(hr);
        }

        final count = pCount.value;
        final deviceArray = ppDevices.value;
        final typedDeviceArray = deviceArray.cast<Pointer<IMFActivate>>();

        for (var i = 0; i < count; i++) {
          final device = typedDeviceArray[i];
          final ppName = calloc<win32.PWSTR>();

          try {
            final hr = device
                .cast<IMFAttributes>()
                .getString(mfDevSourceAttrFriendlyName.cast(), ppName);

            if (win32.SUCCEEDED(hr)) {
              devices.add(_convertFromUtf16(ppName.cast()));
            }
          } finally {
            calloc.free(ppName);
          }
        }
      } finally {
        calloc.free(ppDevices);
        calloc.free(pCount);
      }

      return devices;
    } finally {
      _mfShutdown();
    }
  }

  Future<bool> checkDeviceAvailability(int deviceIndex) async {
    if (!_isInitialized) {
      await initialize();
    }

    final ppDevices = calloc<Pointer<Pointer<Void>>>();
    final pCount = calloc<Uint32>();

    try {
      final hr = _mfEnumDeviceSources(
          mfDevSourceAttrSourceTypeVidcapGuid.cast(), ppDevices, pCount);

      if (win32.FAILED(hr)) {
        return false;
      }

      if (deviceIndex < 0 || deviceIndex >= pCount.value) {
        return false;
      }

      final deviceArray = ppDevices.value;
      final typedDeviceArray = deviceArray.cast<Pointer<IMFActivate>>();
      final device = typedDeviceArray[deviceIndex];

      final ppSource = calloc<Pointer<Void>>();
      try {
        final hr = _mfCreateSourceReaderFromMediaSource(
            device.cast(), nullptr.cast(), ppSource);

        if (win32.FAILED(hr)) {
          return false;
        }

        // 释放测试用的 SourceReader
        final reader = ppSource.cast<IMFSourceReader>();
        final vtable = reader.cast<Pointer<IntPtr>>().value;
        final release = (vtable + 2 * sizeOf<IntPtr>())
            .cast<NativeFunction<Int32 Function(Pointer<Void>)>>()
            .asFunction<int Function(Pointer<Void>)>();
        release(reader.cast());

        return true;
      } finally {
        calloc.free(ppSource);
      }
    } finally {
      calloc.free(ppDevices);
      calloc.free(pCount);
    }
  }

  Future<void> startPreview(int deviceIndex) async {
    if (_isPreviewActive) {
      await stopPreview();
    }

    if (!_isInitialized) {
      await initialize();
    }

    final ppDevices = calloc<Pointer<Pointer<Void>>>();
    final pCount = calloc<Uint32>();

    try {
      final hr = _mfEnumDeviceSources(
          mfDevSourceAttrSourceTypeVidcapGuid.cast(), ppDevices, pCount);

      if (win32.FAILED(hr)) {
        throw win32.WindowsException(hr);
      }

      if (deviceIndex < 0 || deviceIndex >= pCount.value) {
        throw Exception('Invalid device index');
      }

      final deviceArray = ppDevices.value;
      final typedDeviceArray = deviceArray.cast<Pointer<IMFActivate>>();
      final device = typedDeviceArray[deviceIndex];

      final ppSource = calloc<Pointer<Void>>();
      try {
        final hr = _mfCreateSourceReaderFromMediaSource(
            device.cast(), nullptr.cast(), ppSource);

        if (win32.FAILED(hr)) {
          throw win32.WindowsException(hr);
        }

        _reader = ppSource.cast<IMFSourceReader>();
        _isPreviewActive = true;
      } finally {
        calloc.free(ppSource);
      }
    } finally {
      calloc.free(ppDevices);
      calloc.free(pCount);
    }
  }

  Future<void> stopPreview() async {
    if (!_isPreviewActive || _reader == null) return;

    final vtable = _reader!.cast<Pointer<IntPtr>>().value;
    final release = (vtable + 2 * sizeOf<IntPtr>())
        .cast<NativeFunction<Int32 Function(Pointer<Void>)>>()
        .asFunction<int Function(Pointer<Void>)>();
    release(_reader!.cast());

    _reader = null;
    _isPreviewActive = false;
  }

  Future<void> dispose() async {
    if (_isPreviewActive) {
      await stopPreview();
    }

    if (_isInitialized) {
      _mfShutdown();
      _isInitialized = false;
    }
  }

  Future<void> setResolution(int width, int height) async {
    if (!_isPreviewActive || _reader == null) {
      throw Exception('Camera preview is not active');
    }

    final ppMediaType = calloc<Pointer<Void>>();
    try {
      var hr = _mfCreateMediaType(ppMediaType);
      if (win32.FAILED(hr)) {
        throw win32.WindowsException(hr);
      }

      final mediaType = ppMediaType.cast<IMFMediaType>();
      hr = mediaType
          .cast<IMFAttributes>()
          .setUINT64(mfMtFrameSizeGuid.cast(), (width << 32) | height);

      if (win32.FAILED(hr)) {
        throw win32.WindowsException(hr);
      }

      hr = _reader!.setCurrentMediaType(0, nullptr.cast(), mediaType);
      if (win32.FAILED(hr)) {
        throw win32.WindowsException(hr);
      }
    } finally {
      calloc.free(ppMediaType);
    }
  }
}
