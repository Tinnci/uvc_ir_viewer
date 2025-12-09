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

class CameraPlugin : public flutter::Plugin, public flutter::Texture {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

  CameraPlugin(flutter::TextureRegistrar *texture_registrar);
  virtual ~CameraPlugin();

 private:
  // Flutter methods
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue> &method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  // Texture methods
  const FlutterDesktopPixelBuffer *CopyPixelBuffer(size_t width, size_t height) override;

  // Camera methods
  void EnumerateDevices(std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void StartPreview(const flutter::EncodableMap *args, std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void CloseDevice(std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  // WMF helpers
  HRESULT InitializeMediaFoundation();
  HRESULT OpenDevice(int index);
  void ReadSampleLoop();

  flutter::TextureRegistrar *texture_registrar_;
  int64_t texture_id_ = -1;
  
  // Camera State
  IMFSourceReader *source_reader_ = nullptr;
  IMFMediaSource* media_source_ = nullptr;
  bool is_reading_ = false;
  std::mutex mutex_;
  std::unique_ptr<uint8_t[]> pixel_buffer_;
  size_t buffer_size_ = 0;
  long video_width_ = 640;
  long video_height_ = 480;
  std::unique_ptr<FlutterDesktopPixelBuffer> flutter_pixel_buffer_;
};

#endif  // CAMERA_PLUGIN_H_
