#include "camera_plugin.h"

#include <windows.h>
#include <mfapi.h>
#include <mfidl.h>
#include <mfreadwrite.h>
#include <shlwapi.h>
#include <thread>
#include <iostream>

#pragma comment(lib, "mf.lib")
#pragma comment(lib, "mfplat.lib")
#pragma comment(lib, "mfreadwrite.lib")
#pragma comment(lib, "mfuuid.lib")
#pragma comment(lib, "shlwapi.lib")

// Helper template for safe release
template <class T> void SafeRelease(T **ppT) {
    if (*ppT) {
        (*ppT)->Release();
        *ppT = nullptr;
    }
}

void CameraPlugin::RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar) {
  auto plugin = std::make_unique<CameraPlugin>(registrar);

  auto channel =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          registrar->messenger(), 
          "com.example.uvc_viewer/camera",
          &flutter::StandardMethodCodec::GetInstance());

  channel->SetMethodCallHandler(
      [plugin_ptr = plugin.get()](const auto &call, auto result) {
        plugin_ptr->HandleMethodCall(call, std::move(result));
      });

  registrar->AddPlugin(std::move(plugin));
}

CameraPlugin::CameraPlugin(flutter::PluginRegistrarWindows *registrar)
    : registrar_(registrar), 
      texture_registrar_(registrar->texture_registrar()) {
    InitializeMediaFoundation();
    memset(&flutter_pixel_buffer_, 0, sizeof(flutter_pixel_buffer_));
}

CameraPlugin::~CameraPlugin() {
    is_reading_ = false;
    std::this_thread::sleep_for(std::chrono::milliseconds(100));
    CloseDevice(nullptr);
    MFShutdown();
}

HRESULT CameraPlugin::InitializeMediaFoundation() {
    return MFStartup(MF_VERSION);
}

void CameraPlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue> &method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (method_call.method_name().compare("enumerateDevices") == 0) {
    EnumerateDevices(std::move(result));
  } else if (method_call.method_name().compare("startPreview") == 0) {
    const auto *args = std::get_if<flutter::EncodableMap>(method_call.arguments());
    StartPreview(args, std::move(result));
  } else if (method_call.method_name().compare("closeDevice") == 0) {
    CloseDevice(std::move(result));
  } else if (method_call.method_name().compare("getDeviceStatus") == 0) {
    const auto *args = std::get_if<flutter::EncodableMap>(method_call.arguments());
    GetDeviceStatus(args, std::move(result));
  } else if (method_call.method_name().compare("getSupportedResolutions") == 0) {
    const auto *args = std::get_if<flutter::EncodableMap>(method_call.arguments());
    GetSupportedResolutions(args, std::move(result));
  } else if (method_call.method_name().compare("capturePhoto") == 0) {
    CapturePhoto(std::move(result));
  } else if (method_call.method_name().compare("setBrightness") == 0) {
      result->Success();
  } else if (method_call.method_name().compare("setContrast") == 0) {
      result->Success();
  } else {
    result->NotImplemented();
  }
}

void CameraPlugin::EnumerateDevices(std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
    IMFAttributes *pAttributes = nullptr;
    IMFActivate **ppDevices = nullptr;
    UINT32 count = 0;

    HRESULT hr = MFCreateAttributes(&pAttributes, 1);
    if (SUCCEEDED(hr)) {
        hr = pAttributes->SetGUID(
            MF_DEVSOURCE_ATTRIBUTE_SOURCE_TYPE,
            MF_DEVSOURCE_ATTRIBUTE_SOURCE_TYPE_VIDCAP_GUID
        );
    }

    if (SUCCEEDED(hr)) {
        hr = MFEnumDeviceSources(pAttributes, &ppDevices, &count);
    }

    if (SUCCEEDED(hr)) {
        flutter::EncodableList devices;
        for (UINT32 i = 0; i < count; i++) {
            WCHAR *szFriendlyName = nullptr;
            UINT32 cchName;
            hr = ppDevices[i]->GetAllocatedString(
                MF_DEVSOURCE_ATTRIBUTE_FRIENDLY_NAME,
                &szFriendlyName, 
                &cchName
            );

            if (SUCCEEDED(hr) && szFriendlyName) {
                int size_needed = WideCharToMultiByte(CP_UTF8, 0, szFriendlyName, (int)cchName, nullptr, 0, nullptr, nullptr);
                std::string strTo(size_needed, 0);
                WideCharToMultiByte(CP_UTF8, 0, szFriendlyName, (int)cchName, &strTo[0], size_needed, nullptr, nullptr);
                devices.push_back(flutter::EncodableValue(strTo));
                CoTaskMemFree(szFriendlyName);
            }
            SafeRelease(&ppDevices[i]);
        }
        CoTaskMemFree(ppDevices);
        result->Success(devices);
    } else {
        result->Error("ENUM_FAILED", "Failed to enumerate devices");
    }
    
    SafeRelease(&pAttributes);
}

void CameraPlugin::StartPreview(const flutter::EncodableMap *args, std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
    int index = 0;
    if (args) {
        auto index_it = args->find(flutter::EncodableValue("index"));
        if (index_it != args->end()) {
            index = std::get<int>(index_it->second);
        }
    }

    CloseDevice(nullptr);

    HRESULT hr = OpenDevice(index);
    if(FAILED(hr)) {
        result->Error("OPEN_FAILED", "Failed to open device");
        return;
    }

    // Create texture variant with callback
    texture_variant_ = std::make_unique<flutter::TextureVariant>(
        flutter::PixelBufferTexture([this](size_t width, size_t height) -> const FlutterDesktopPixelBuffer* {
            return this->CopyPixelBuffer(width, height);
        })
    );
    texture_id_ = texture_registrar_->RegisterTexture(texture_variant_.get());
    
    is_reading_ = true;
    std::thread([this]() {
        this->ReadSampleLoop();
    }).detach();

    result->Success(flutter::EncodableValue(texture_id_));
}

HRESULT CameraPlugin::OpenDevice(int index) {
    IMFAttributes *pAttributes = nullptr;
    IMFActivate **ppDevices = nullptr;
    UINT32 count = 0;
    HRESULT hr = S_OK;

    hr = MFCreateAttributes(&pAttributes, 1);
    
    if (SUCCEEDED(hr)) {
        hr = pAttributes->SetGUID(MF_DEVSOURCE_ATTRIBUTE_SOURCE_TYPE, MF_DEVSOURCE_ATTRIBUTE_SOURCE_TYPE_VIDCAP_GUID);
    }
    
    if (SUCCEEDED(hr)) {
        hr = MFEnumDeviceSources(pAttributes, &ppDevices, &count);
    }

    if (SUCCEEDED(hr) && (UINT32)index < count) {
        hr = ppDevices[index]->ActivateObject(IID_PPV_ARGS(&media_source_));
    } else if ((UINT32)index >= count) {
        hr = E_FAIL;
    }

    if (SUCCEEDED(hr)) {
        IMFAttributes *pReaderAttributes = nullptr;
        MFCreateAttributes(&pReaderAttributes, 1);
        pReaderAttributes->SetUINT32(MF_SOURCE_READER_ENABLE_VIDEO_PROCESSING, 1);
        
        hr = MFCreateSourceReaderFromMediaSource(media_source_, pReaderAttributes, &source_reader_);
        SafeRelease(&pReaderAttributes);
    }
    
    if (SUCCEEDED(hr)) {
        IMFMediaType *pType = nullptr;
        MFCreateMediaType(&pType);
        pType->SetGUID(MF_MT_MAJOR_TYPE, MFMediaType_Video);
        pType->SetGUID(MF_MT_SUBTYPE, MFVideoFormat_RGB32);
        
        hr = source_reader_->SetCurrentMediaType((DWORD)MF_SOURCE_READER_FIRST_VIDEO_STREAM, nullptr, pType);
        SafeRelease(&pType);
    }
    
    // Get the actual media type to determine video dimensions
    if (SUCCEEDED(hr)) {
        IMFMediaType *pCurrentType = nullptr;
        hr = source_reader_->GetCurrentMediaType((DWORD)MF_SOURCE_READER_FIRST_VIDEO_STREAM, &pCurrentType);
        if (SUCCEEDED(hr) && pCurrentType) {
            UINT32 width = 0, height = 0;
            MFGetAttributeSize(pCurrentType, MF_MT_FRAME_SIZE, &width, &height);
            if (width > 0 && height > 0) {
                video_width_ = width;
                video_height_ = height;
            }
            SafeRelease(&pCurrentType);
        }
    }

    // Clean up enumeration
    for (UINT32 i = 0; i < count; i++) {
        SafeRelease(&ppDevices[i]);
    }
    CoTaskMemFree(ppDevices);
    SafeRelease(&pAttributes);

    return hr;
}

void CameraPlugin::CloseDevice(std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
    is_reading_ = false;

    if (texture_id_ != -1 && texture_registrar_) {
        texture_registrar_->UnregisterTexture(texture_id_);
        texture_id_ = -1;
        texture_variant_.reset();
    }
    
    SafeRelease(&source_reader_);
    SafeRelease(&media_source_);

    if (result) {
        result->Success();
    }
}

void CameraPlugin::ReadSampleLoop() {
    while (is_reading_ && source_reader_) {
        IMFSample *pSample = nullptr;
        DWORD streamIndex, flags;
        LONGLONG llTimeStamp;
        
        HRESULT hr = source_reader_->ReadSample(
            (DWORD)MF_SOURCE_READER_FIRST_VIDEO_STREAM,
            0,
            &streamIndex,
            &flags,
            &llTimeStamp,
            &pSample
        );

        if (FAILED(hr)) {
            break;
        }

        if (pSample) {
            IMFMediaBuffer *pBuffer = nullptr;
            hr = pSample->ConvertToContiguousBuffer(&pBuffer);
            
            if (SUCCEEDED(hr) && pBuffer) {
                BYTE *pData = nullptr;
                DWORD cbMaxLength, cbCurrentLength;
                LONG lPitch = 0;
                
                // Try to get 2D buffer interface for stride information
                IMF2DBuffer *p2DBuffer = nullptr;
                hr = pBuffer->QueryInterface(IID_PPV_ARGS(&p2DBuffer));
                
                if (SUCCEEDED(hr) && p2DBuffer) {
                    BYTE *pScanline0 = nullptr;
                    hr = p2DBuffer->Lock2D(&pScanline0, &lPitch);
                    if (SUCCEEDED(hr)) {
                        pData = pScanline0;
                    }
                } else {
                    // Fallback to regular Lock
                    hr = pBuffer->Lock(&pData, &cbMaxLength, &cbCurrentLength);
                    // Assume default pitch if not available
                    lPitch = static_cast<LONG>(video_width_ * 4); 
                }

                if (SUCCEEDED(hr) && pData) {
                    std::lock_guard<std::mutex> lock(mutex_);
                    
                    size_t expected_size = video_width_ * video_height_ * 4;
                    if (buffer_size_ != expected_size) {
                        buffer_size_ = expected_size;
                        pixel_buffer_ = std::make_unique<uint8_t[]>(buffer_size_);
                    }

                    // Handle stride (pitch) mismatch
                    // Usually pitch can be negative (bottom-up) or positive (top-down)
                    // We need abs(pitch) for copying
                    LONG absPitch = lPitch > 0 ? lPitch : -lPitch;
                    size_t rowBytes = video_width_ * 4;
                    
                    if (absPitch == rowBytes) {
                        // Fast path: contiguous block
                        memcpy(pixel_buffer_.get(), pData, expected_size);
                    } else {
                        // Slow path: row by row copy to remove padding
                        uint8_t* src = pData;
                        uint8_t* dst = pixel_buffer_.get();
                        for (size_t y = 0; y < video_height_; y++) {
                            memcpy(dst, src, rowBytes);
                            dst += rowBytes; // Advance dist by exact row width
                            src += absPitch; // Advance src by pitch (including padding)
                        }
                    }

                    if (p2DBuffer) {
                        p2DBuffer->Unlock2D();
                        p2DBuffer->Release();
                    } else {
                        pBuffer->Unlock();
                    }
                }
                
                pBuffer->Release();
                
                if (texture_registrar_ && texture_id_ != -1) {
                    texture_registrar_->MarkTextureFrameAvailable(texture_id_);
                }
            }
            pSample->Release();
        }
    }
}

const FlutterDesktopPixelBuffer *CameraPlugin::CopyPixelBuffer(size_t width, size_t height) {
    std::lock_guard<std::mutex> lock(mutex_);
    if (!pixel_buffer_) return nullptr;
    
    flutter_pixel_buffer_.buffer = pixel_buffer_.get();
    flutter_pixel_buffer_.width = video_width_;
    flutter_pixel_buffer_.height = video_height_;
    
    return &flutter_pixel_buffer_;
}

void CameraPlugin::GetDeviceStatus(const flutter::EncodableMap *args, std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
    int index = 0;
    if (args) {
        auto index_it = args->find(flutter::EncodableValue("index"));
        if (index_it != args->end()) {
            index = std::get<int>(index_it->second);
        }
    }

    IMFAttributes *pAttributes = nullptr;
    IMFActivate **ppDevices = nullptr;
    UINT32 count = 0;

    HRESULT hr = MFCreateAttributes(&pAttributes, 1);
    if (SUCCEEDED(hr)) {
        hr = pAttributes->SetGUID(
            MF_DEVSOURCE_ATTRIBUTE_SOURCE_TYPE,
            MF_DEVSOURCE_ATTRIBUTE_SOURCE_TYPE_VIDCAP_GUID
        );
    }

    if (SUCCEEDED(hr)) {
        hr = MFEnumDeviceSources(pAttributes, &ppDevices, &count);
    }

    flutter::EncodableMap statusMap;
    
    if (SUCCEEDED(hr)) {
        bool isConnected = (UINT32)index < count;
        bool isAvailable = false;
        std::string deviceName;

        if (isConnected) {
            // Try to get the device name to verify it's still accessible
            WCHAR *szFriendlyName = nullptr;
            UINT32 cchName;
            HRESULT nameHr = ppDevices[index]->GetAllocatedString(
                MF_DEVSOURCE_ATTRIBUTE_FRIENDLY_NAME,
                &szFriendlyName,
                &cchName
            );
            
            if (SUCCEEDED(nameHr) && szFriendlyName) {
                isAvailable = true;
                int size_needed = WideCharToMultiByte(CP_UTF8, 0, szFriendlyName, (int)cchName, nullptr, 0, nullptr, nullptr);
                deviceName.resize(size_needed);
                WideCharToMultiByte(CP_UTF8, 0, szFriendlyName, (int)cchName, &deviceName[0], size_needed, nullptr, nullptr);
                CoTaskMemFree(szFriendlyName);
            }
        }

        statusMap[flutter::EncodableValue("isConnected")] = flutter::EncodableValue(isConnected);
        statusMap[flutter::EncodableValue("isAvailable")] = flutter::EncodableValue(isAvailable);
        statusMap[flutter::EncodableValue("deviceCount")] = flutter::EncodableValue((int)count);
        if (!deviceName.empty()) {
            statusMap[flutter::EncodableValue("deviceName")] = flutter::EncodableValue(deviceName);
        }

        // Clean up device list
        for (UINT32 i = 0; i < count; i++) {
            SafeRelease(&ppDevices[i]);
        }
        CoTaskMemFree(ppDevices);
    } else {
        statusMap[flutter::EncodableValue("isConnected")] = flutter::EncodableValue(false);
        statusMap[flutter::EncodableValue("isAvailable")] = flutter::EncodableValue(false);
        statusMap[flutter::EncodableValue("error")] = flutter::EncodableValue("Failed to enumerate devices");
    }

    SafeRelease(&pAttributes);
    result->Success(flutter::EncodableValue(statusMap));
}

void CameraPlugin::GetSupportedResolutions(const flutter::EncodableMap *args, std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
    int index = 0;
    if (args) {
        auto index_it = args->find(flutter::EncodableValue("index"));
        if (index_it != args->end()) {
            index = std::get<int>(index_it->second);
        }
    }

    IMFAttributes *pAttributes = nullptr;
    IMFActivate **ppDevices = nullptr;
    UINT32 count = 0;
    flutter::EncodableList resolutions;

    HRESULT hr = MFCreateAttributes(&pAttributes, 1);
    if (SUCCEEDED(hr)) {
        hr = pAttributes->SetGUID(
            MF_DEVSOURCE_ATTRIBUTE_SOURCE_TYPE,
            MF_DEVSOURCE_ATTRIBUTE_SOURCE_TYPE_VIDCAP_GUID
        );
    }

    if (SUCCEEDED(hr)) {
        hr = MFEnumDeviceSources(pAttributes, &ppDevices, &count);
    }

    if (SUCCEEDED(hr) && (UINT32)index < count) {
        IMFMediaSource *pSource = nullptr;
        hr = ppDevices[index]->ActivateObject(IID_PPV_ARGS(&pSource));
        
        if (SUCCEEDED(hr)) {
            IMFPresentationDescriptor *pPD = nullptr;
            hr = pSource->CreatePresentationDescriptor(&pPD);
            
            if (SUCCEEDED(hr)) {
                DWORD streamCount = 0;
                pPD->GetStreamDescriptorCount(&streamCount);
                
                for (DWORD i = 0; i < streamCount; i++) {
                    BOOL selected = FALSE;
                    IMFStreamDescriptor *pSD = nullptr;
                    pPD->GetStreamDescriptorByIndex(i, &selected, &pSD);
                    
                    if (pSD) {
                        IMFMediaTypeHandler *pHandler = nullptr;
                        pSD->GetMediaTypeHandler(&pHandler);
                        
                        if (pHandler) {
                            DWORD typeCount = 0;
                            pHandler->GetMediaTypeCount(&typeCount);
                            
                            for (DWORD j = 0; j < typeCount; j++) {
                                IMFMediaType *pType = nullptr;
                                pHandler->GetMediaTypeByIndex(j, &pType);
                                
                                if (pType) {
                                    GUID majorType;
                                    pType->GetMajorType(&majorType);
                                    
                                    if (IsEqualGUID(majorType, MFMediaType_Video)) {
                                        UINT32 width = 0, height = 0;
                                        MFGetAttributeSize(pType, MF_MT_FRAME_SIZE, &width, &height);
                                        
                                        UINT32 numerator = 0, denominator = 1;
                                        MFGetAttributeRatio(pType, MF_MT_FRAME_RATE, &numerator, &denominator);
                                        int frameRate = denominator > 0 ? (int)(numerator / denominator) : 30;
                                        
                                        if (width > 0 && height > 0) {
                                            flutter::EncodableMap resMap;
                                            resMap[flutter::EncodableValue("width")] = flutter::EncodableValue((int)width);
                                            resMap[flutter::EncodableValue("height")] = flutter::EncodableValue((int)height);
                                            resMap[flutter::EncodableValue("frameRate")] = flutter::EncodableValue(frameRate);
                                            
                                            // Avoid duplicates
                                            bool exists = false;
                                            for (const auto& r : resolutions) {
                                                const auto& m = std::get<flutter::EncodableMap>(r);
                                                auto w_it = m.find(flutter::EncodableValue("width"));
                                                auto h_it = m.find(flutter::EncodableValue("height"));
                                                if (w_it != m.end() && h_it != m.end()) {
                                                    if (std::get<int>(w_it->second) == (int)width && 
                                                        std::get<int>(h_it->second) == (int)height) {
                                                        exists = true;
                                                        break;
                                                    }
                                                }
                                            }
                                            if (!exists) {
                                                resolutions.push_back(flutter::EncodableValue(resMap));
                                            }
                                        }
                                    }
                                    pType->Release();
                                }
                            }
                            pHandler->Release();
                        }
                        pSD->Release();
                    }
                }
                pPD->Release();
            }
            pSource->Shutdown();
            pSource->Release();
        }
    }

    // Clean up
    for (UINT32 i = 0; i < count; i++) {
        SafeRelease(&ppDevices[i]);
    }
    CoTaskMemFree(ppDevices);
    SafeRelease(&pAttributes);

    result->Success(flutter::EncodableValue(resolutions));
}

void CameraPlugin::CapturePhoto(std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
    std::lock_guard<std::mutex> lock(mutex_);
    
    if (!pixel_buffer_ || buffer_size_ == 0) {
        result->Error("NO_FRAME", "No frame available to capture");
        return;
    }
    
    // Copy current frame data
    std::vector<uint8_t> photoData(pixel_buffer_.get(), pixel_buffer_.get() + buffer_size_);
    
    result->Success(flutter::EncodableValue(photoData));
}
