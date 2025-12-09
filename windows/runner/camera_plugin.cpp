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
            pSample->ConvertToContiguousBuffer(&pBuffer);
            
            if (pBuffer) {
                BYTE *pData = nullptr;
                DWORD cbMaxLength, cbCurrentLength;
                pBuffer->Lock(&pData, &cbMaxLength, &cbCurrentLength);
                
                {
                    std::lock_guard<std::mutex> lock(mutex_);
                    if (buffer_size_ != cbCurrentLength) {
                        buffer_size_ = cbCurrentLength;
                        pixel_buffer_ = std::make_unique<uint8_t[]>(buffer_size_);
                    }
                    memcpy(pixel_buffer_.get(), pData, cbCurrentLength);
                }
                
                pBuffer->Unlock();
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
