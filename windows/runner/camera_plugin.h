#ifndef CAMERA_PLUGIN_H_
#define CAMERA_PLUGIN_H_

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>
#include <flutter/texture_registrar.h>

#include <mfapi.h>
#include <mfidl.h>
#include <mfreadwrite.h>
#include <shlwapi.h>
#include <vector>
#include <string>
#include <memory>
#include <mutex>
#include <functional>

class CameraPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

  CameraPlugin(flutter::PluginRegistrarWindows *registrar);
  virtual ~CameraPlugin();

 private:
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue> &method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  // Texture callback
  const FlutterDesktopPixelBuffer *CopyPixelBuffer(size_t width, size_t height);

  // Camera methods
  void EnumerateDevices(std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void StartPreview(const flutter::EncodableMap *args, std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void CloseDevice(std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void GetDeviceStatus(const flutter::EncodableMap *args, std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  // WMF helpers
  HRESULT InitializeMediaFoundation();
  HRESULT OpenDevice(int index);
  void ReadSampleLoop();

  flutter::PluginRegistrarWindows *registrar_;
  flutter::TextureRegistrar *texture_registrar_;
  std::unique_ptr<flutter::TextureVariant> texture_variant_;
  int64_t texture_id_ = -1;
  
  // Camera State
  IMFSourceReader *source_reader_ = nullptr;
  IMFMediaSource* media_source_ = nullptr;
  bool is_reading_ = false;
  std::mutex mutex_;
  std::unique_ptr<uint8_t[]> pixel_buffer_;
  size_t buffer_size_ = 0;
  size_t video_width_ = 640;
  size_t video_height_ = 480;
  FlutterDesktopPixelBuffer flutter_pixel_buffer_;
};

#endif  // CAMERA_PLUGIN_H_
