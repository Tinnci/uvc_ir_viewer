package com.example.uvc_ir_viewer

import android.content.Context
import android.hardware.camera2.CameraAccessException
import android.hardware.camera2.CameraCaptureSession
import android.hardware.camera2.CameraDevice
import android.hardware.camera2.CameraManager
import android.hardware.camera2.CaptureRequest
import android.hardware.usb.UsbManager
import android.os.Handler
import android.os.HandlerThread
import android.view.Surface
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.view.TextureRegistry

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.example.uvc_ir_viewer/camera"
    
    private var cameraDevice: CameraDevice? = null
    private var cameraCaptureSession: CameraCaptureSession? = null
    private var textureEntry: TextureRegistry.SurfaceTextureEntry? = null
    private var backgroundHandler: Handler? = null
    private var backgroundThread: HandlerThread? = null

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler {
            call, result ->
            when (call.method) {
                "enumerateDevices" -> {
                    val devices = enumerateUsbDevices()
                    result.success(devices)
                }
                "startPreview" -> {
                    startPreview(flutterEngine.renderer.textures, result)
                }
                "closeDevice" -> {
                    closeCamera()
                    result.success(null)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun enumerateUsbDevices(): List<String> {
        val usbManager = getSystemService(Context.USB_SERVICE) as UsbManager
        val deviceList = usbManager.deviceList
        val devices = mutableListOf<String>()
        // Also add internal cameras for testing if no USB camera
        val cameraManager = getSystemService(Context.CAMERA_SERVICE) as CameraManager
        try {
            for (cameraId in cameraManager.cameraIdList) {
                // Just listing IDs for now, or separating by type
                // devices.add("Camera2 ID: $cameraId") 
            }
        } catch (e: Exception) {
            // Ignore
        }

        for (device in deviceList.values) {
            devices.add("${device.deviceName} (VID:${device.vendorId} PID:${device.productId})")
        }
        return devices
    }

    private fun startBackgroundThread() {
        backgroundThread = HandlerThread("CameraBackground").also { it.start() }
        backgroundHandler = Handler(backgroundThread!!.looper)
    }

    private fun stopBackgroundThread() {
        backgroundThread?.quitSafely()
        try {
            backgroundThread?.join()
            backgroundThread = null
            backgroundHandler = null
        } catch (e: InterruptedException) {
            e.printStackTrace()
        }
    }

    private fun startPreview(textures: TextureRegistry, result: MethodChannel.Result) {
        closeCamera()
        startBackgroundThread()

        textureEntry = textures.createSurfaceTexture()
        val surfaceTexture = textureEntry!!.surfaceTexture()
        // Default size, should be configurable
        surfaceTexture.setDefaultBufferSize(640, 480) 
        val surface = Surface(surfaceTexture)

        val cameraManager = getSystemService(Context.CAMERA_SERVICE) as CameraManager
        try {
            // Simply pick the first camera for now or logic to find external
            // For true external/USB, we look for LENS_FACING_EXTERNAL usually
            var targetCameraId: String? = null
            for (id in cameraManager.cameraIdList) {
                 // For now just pick first one for simplicity, or specific logic
                 targetCameraId = id
                 break 
            }

            if (targetCameraId == null) {
                result.error("NO_CAMERA", "No camera found", null)
                return
            }

            cameraManager.openCamera(targetCameraId, object : CameraDevice.StateCallback() {
                override fun onOpened(camera: CameraDevice) {
                    cameraDevice = camera
                    createCameraPreviewSession(camera, surface)
                    result.success(textureEntry!!.id())
                }

                override fun onDisconnected(camera: CameraDevice) {
                    camera.close()
                    cameraDevice = null
                }

                override fun onError(camera: CameraDevice, error: Int) {
                    camera.close()
                    cameraDevice = null
                    // If result not sent yet, could send error, but this is callback
                }
            }, backgroundHandler)

        } catch (e: CameraAccessException) {
            result.error("CAMERA_ACCESS", e.message, null)
        } catch (e: SecurityException) {
            result.error("PERMISSION_DENIED", e.message, null)
        }
    }

    private fun createCameraPreviewSession(camera: CameraDevice, surface: Surface) {
        try {
            val captureRequestBuilder = camera.createCaptureRequest(CameraDevice.TEMPLATE_PREVIEW)
            captureRequestBuilder.addTarget(surface)

            camera.createCaptureSession(listOf(surface), object : CameraCaptureSession.StateCallback() {
                override fun onConfigured(session: CameraCaptureSession) {
                    if (cameraDevice == null) return
                    cameraCaptureSession = session
                    try {
                        captureRequestBuilder.set(CaptureRequest.CONTROL_AF_MODE, CaptureRequest.CONTROL_AF_MODE_CONTINUOUS_PICTURE)
                        session.setRepeatingRequest(captureRequestBuilder.build(), null, backgroundHandler)
                    } catch (e: CameraAccessException) {
                        e.printStackTrace()
                    }
                }

                override fun onConfigureFailed(session: CameraCaptureSession) {
                    // Handle failure
                }
            }, backgroundHandler)
        } catch (e: CameraAccessException) {
            e.printStackTrace()
        }
    }

    private fun closeCamera() {
        try {
            cameraCaptureSession?.close()
            cameraCaptureSession = null
            cameraDevice?.close()
            cameraDevice = null
            textureEntry?.release()
            textureEntry = null
            stopBackgroundThread()
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }
}
