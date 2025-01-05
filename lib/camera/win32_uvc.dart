import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart' as win32;

// DirectShow GUID definitions
final clsidVideoInputDeviceCategory = calloc<win32.GUID>();
final iidBaseFilter = calloc<win32.GUID>();
final iidCreateDevEnum = calloc<win32.GUID>();
final clsidSystemDeviceEnum = calloc<win32.GUID>();
final iidMoniker = calloc<win32.GUID>();
final iidPropertyBag = calloc<win32.GUID>();
final iidAMStreamConfig = calloc<win32.GUID>();
final iidMediaControl = calloc<win32.GUID>();
final iidGraphBuilder = calloc<win32.GUID>();
final clsidFilterGraph = calloc<win32.GUID>();

// DirectShow interface definitions
typedef CreateBindCtxNative = Int32 Function(
    Uint32 reserved, Pointer<Pointer> ppbc);
typedef CreateBindCtxDart = int Function(int reserved, Pointer<Pointer> ppbc);

// UVC specific structures
base class VideoStreamConfigCaps extends Struct {
  @Int32()
  external int guid;
  @Int32()
  external int videoStandard;
  @Int32()
  external int width;
  @Int32()
  external int height;
  @Int32()
  external int minFrameInterval;
  @Int32()
  external int maxFrameInterval;
  @Int32()
  external int maxBitsPerSecond;
  @Int32()
  external int inputSize;
}

// DirectShow COM interfaces
final class IBaseFilter extends win32.IUnknown {
  IBaseFilter(super.ptr);

  external factory IBaseFilter.fromRawPointer(Pointer<win32.COMObject> ptr);

  @override
  int release() {
    final vtable = ptr.ref.vtable;
    final funcPtr =
        Pointer<IntPtr>.fromAddress(vtable.address + 2 * sizeOf<IntPtr>())
            .value;
    final func = Pointer<
            NativeFunction<
                Int32 Function(Pointer<win32.COMObject>)>>.fromAddress(funcPtr)
        .asFunction<int Function(Pointer<win32.COMObject>)>();
    return func(ptr);
  }
}

final class ICreateDevEnum extends win32.IUnknown {
  ICreateDevEnum(super.ptr);

  external factory ICreateDevEnum.fromRawPointer(Pointer<win32.COMObject> ptr);

  @override
  int release() {
    final vtable = ptr.ref.vtable;
    final funcPtr =
        Pointer<IntPtr>.fromAddress(vtable.address + 2 * sizeOf<IntPtr>())
            .value;
    final func = Pointer<
            NativeFunction<
                Int32 Function(Pointer<win32.COMObject>)>>.fromAddress(funcPtr)
        .asFunction<int Function(Pointer<win32.COMObject>)>();
    return func(ptr);
  }

  int createClassEnumerator(Pointer<win32.GUID> clsid,
      Pointer<Pointer<win32.COMObject>> ppEnumMoniker, int flags) {
    final vtable = ptr.ref.vtable;
    final funcPtr =
        Pointer<IntPtr>.fromAddress(vtable.address + 3 * sizeOf<IntPtr>())
            .value;
    final func = Pointer<
            NativeFunction<
                Int32 Function(
                    Pointer<win32.COMObject>,
                    Pointer<win32.GUID>,
                    Pointer<Pointer<win32.COMObject>>,
                    Uint32)>>.fromAddress(funcPtr)
        .asFunction<
            int Function(Pointer<win32.COMObject>, Pointer<win32.GUID>,
                Pointer<Pointer<win32.COMObject>>, int)>();
    return func(ptr, clsid, ppEnumMoniker, flags);
  }
}

final class IMoniker extends win32.IUnknown {
  IMoniker(super.ptr);

  external factory IMoniker.fromRawPointer(Pointer<win32.COMObject> ptr);

  @override
  int release() {
    final vtable = ptr.ref.vtable;
    final funcPtr =
        Pointer<IntPtr>.fromAddress(vtable.address + 2 * sizeOf<IntPtr>())
            .value;
    final func = Pointer<
            NativeFunction<
                Int32 Function(Pointer<win32.COMObject>)>>.fromAddress(funcPtr)
        .asFunction<int Function(Pointer<win32.COMObject>)>();
    return func(ptr);
  }

  int bindToStorage(
      Pointer<win32.COMObject> pbc,
      Pointer<win32.COMObject> pmkToLeft,
      Pointer<win32.GUID> riid,
      Pointer<Pointer<win32.COMObject>> ppvObj) {
    final vtable = ptr.ref.vtable;
    final funcPtr =
        Pointer<IntPtr>.fromAddress(vtable.address + 5 * sizeOf<IntPtr>())
            .value;
    final func = Pointer<
            NativeFunction<
                Int32 Function(
                    Pointer<win32.COMObject>,
                    Pointer<win32.COMObject>,
                    Pointer<win32.COMObject>,
                    Pointer<win32.GUID>,
                    Pointer<Pointer<win32.COMObject>>)>>.fromAddress(funcPtr)
        .asFunction<
            int Function(
                Pointer<win32.COMObject>,
                Pointer<win32.COMObject>,
                Pointer<win32.COMObject>,
                Pointer<win32.GUID>,
                Pointer<Pointer<win32.COMObject>>)>();
    return func(ptr, pbc, pmkToLeft, riid, ppvObj);
  }
}

final class IPropertyBag extends win32.IUnknown {
  IPropertyBag(super.ptr);

  external factory IPropertyBag.fromRawPointer(Pointer<win32.COMObject> ptr);

  @override
  int release() {
    final vtable = ptr.ref.vtable;
    final funcPtr =
        Pointer<IntPtr>.fromAddress(vtable.address + 2 * sizeOf<IntPtr>())
            .value;
    final func = Pointer<
            NativeFunction<
                Int32 Function(Pointer<win32.COMObject>)>>.fromAddress(funcPtr)
        .asFunction<int Function(Pointer<win32.COMObject>)>();
    return func(ptr);
  }

  int read(Pointer<Utf16> pszPropName, Pointer<win32.VARIANT> pVar,
      Pointer<win32.COMObject> pErrorLog) {
    final vtable = ptr.ref.vtable;
    final funcPtr =
        Pointer<IntPtr>.fromAddress(vtable.address + 3 * sizeOf<IntPtr>())
            .value;
    final func = Pointer<
            NativeFunction<
                Int32 Function(
                    Pointer<win32.COMObject>,
                    Pointer<Utf16>,
                    Pointer<win32.VARIANT>,
                    Pointer<win32.COMObject>)>>.fromAddress(funcPtr)
        .asFunction<
            int Function(Pointer<win32.COMObject>, Pointer<Utf16>,
                Pointer<win32.VARIANT>, Pointer<win32.COMObject>)>();
    return func(ptr, pszPropName, pVar, pErrorLog);
  }
}

final class IGraphBuilder extends win32.IUnknown {
  IGraphBuilder(super.ptr);

  external factory IGraphBuilder.fromRawPointer(Pointer<win32.COMObject> ptr);

  @override
  int release() {
    final vtable = ptr.ref.vtable;
    final funcPtr =
        Pointer<IntPtr>.fromAddress(vtable.address + 2 * sizeOf<IntPtr>())
            .value;
    final func = Pointer<
            NativeFunction<
                Int32 Function(Pointer<win32.COMObject>)>>.fromAddress(funcPtr)
        .asFunction<int Function(Pointer<win32.COMObject>)>();
    return func(ptr);
  }

  int addFilter(Pointer<win32.COMObject> pFilter, Pointer<Utf16> pName) {
    final vtable = ptr.ref.vtable;
    final funcPtr =
        Pointer<IntPtr>.fromAddress(vtable.address + 3 * sizeOf<IntPtr>())
            .value;
    final func = Pointer<
            NativeFunction<
                Int32 Function(
                    Pointer<win32.COMObject>,
                    Pointer<win32.COMObject>,
                    Pointer<Utf16>)>>.fromAddress(funcPtr)
        .asFunction<
            int Function(Pointer<win32.COMObject>, Pointer<win32.COMObject>,
                Pointer<Utf16>)>();
    return func(ptr, pFilter, pName);
  }
}

final class IMediaControl extends win32.IUnknown {
  IMediaControl(super.ptr);

  external factory IMediaControl.fromRawPointer(Pointer<win32.COMObject> ptr);

  @override
  int release() {
    final vtable = ptr.ref.vtable;
    final funcPtr =
        Pointer<IntPtr>.fromAddress(vtable.address + 2 * sizeOf<IntPtr>())
            .value;
    final func = Pointer<
            NativeFunction<
                Int32 Function(Pointer<win32.COMObject>)>>.fromAddress(funcPtr)
        .asFunction<int Function(Pointer<win32.COMObject>)>();
    return func(ptr);
  }

  int run() {
    final vtable = ptr.ref.vtable;
    final funcPtr =
        Pointer<IntPtr>.fromAddress(vtable.address + 3 * sizeOf<IntPtr>())
            .value;
    final func = Pointer<
            NativeFunction<
                Int32 Function(Pointer<win32.COMObject>)>>.fromAddress(funcPtr)
        .asFunction<int Function(Pointer<win32.COMObject>)>();
    return func(ptr);
  }

  int stop() {
    final vtable = ptr.ref.vtable;
    final funcPtr =
        Pointer<IntPtr>.fromAddress(vtable.address + 4 * sizeOf<IntPtr>())
            .value;
    final func = Pointer<
            NativeFunction<
                Int32 Function(Pointer<win32.COMObject>)>>.fromAddress(funcPtr)
        .asFunction<int Function(Pointer<win32.COMObject>)>();
    return func(ptr);
  }
}

final class IEnumMoniker extends win32.IUnknown {
  IEnumMoniker(super.ptr);

  external factory IEnumMoniker.fromRawPointer(Pointer<win32.COMObject> ptr);

  @override
  int release() {
    final vtable = ptr.ref.vtable;
    final funcPtr =
        Pointer<IntPtr>.fromAddress(vtable.address + 2 * sizeOf<IntPtr>())
            .value;
    final func = Pointer<
            NativeFunction<
                Int32 Function(Pointer<win32.COMObject>)>>.fromAddress(funcPtr)
        .asFunction<int Function(Pointer<win32.COMObject>)>();
    return func(ptr);
  }

  int next(int celt, Pointer<Pointer<win32.COMObject>> rgelt,
      Pointer<Uint32> pceltFetched) {
    final vtable = ptr.ref.vtable;
    final funcPtr =
        Pointer<IntPtr>.fromAddress(vtable.address + 3 * sizeOf<IntPtr>())
            .value;
    final func = Pointer<
            NativeFunction<
                Int32 Function(
                    Pointer<win32.COMObject>,
                    Uint32,
                    Pointer<Pointer<win32.COMObject>>,
                    Pointer<Uint32>)>>.fromAddress(funcPtr)
        .asFunction<
            int Function(Pointer<win32.COMObject>, int,
                Pointer<Pointer<win32.COMObject>>, Pointer<Uint32>)>();
    return func(ptr, celt, rgelt, pceltFetched);
  }
}

// Helper functions
void setGUID(Pointer<win32.GUID> guid, String guidString) {
  final hr = win32.IIDFromString(guidString.toNativeUtf16(), guid);
  if (win32.FAILED(hr)) {
    throw Exception('Failed to initialize GUID: $guidString');
  }
}

void initializeGUIDs() {
  // Initialize DirectShow GUIDs
  setGUID(
      clsidVideoInputDeviceCategory, '{860BB310-5D01-11d0-BD3B-00A0C911CE86}');
  setGUID(iidBaseFilter, '{56a86895-0ad4-11ce-b03a-0020af0ba770}');
  setGUID(iidCreateDevEnum, '{29840822-5b84-11d0-bd3b-00a0c911ce86}');
  setGUID(clsidSystemDeviceEnum, '{62BE5D10-60EB-11d0-BD3B-00A0C911CE86}');
  setGUID(iidMoniker, '{0000000f-0000-0000-C000-000000000046}');
  setGUID(iidPropertyBag, '{55272A00-42CB-11CE-8135-00AA004BB851}');
  setGUID(iidAMStreamConfig, '{C6E13340-30AC-11d0-A18C-00A0C9118956}');
  setGUID(iidMediaControl, '{56a868b1-0ad4-11ce-b03a-0020af0ba770}');
  setGUID(iidGraphBuilder, '{56a868a9-0ad4-11ce-b03a-0020af0ba770}');
  setGUID(clsidFilterGraph, '{e436ebb3-524f-11ce-9f53-0020af0ba770}');
}
