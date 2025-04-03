package com.example.macrotracker

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.GeneratedPluginRegistrant

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.macrotracker/native_camera_view"
    private lateinit var channel: MethodChannel
    private val CAMERA_REQUEST_CODE = 101

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        GeneratedPluginRegistrant.registerWith(flutterEngine)

        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        channel.setMethodCallHandler { call, result ->
            if (call.method == "showNativeCamera") {
                val intent = Intent(this, CameraActivity::class.java)
                startActivityForResult(intent, CAMERA_REQUEST_CODE)
                // We don't send a result back immediately, we wait for CameraActivity
            } else {
                result.notImplemented()
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)

        if (requestCode == CAMERA_REQUEST_CODE) {
            if (resultCode == Activity.RESULT_OK && data != null) {
                val resultType = data.getStringExtra("type")
                val resultValue = data.getStringExtra("value") // For barcode
                val photoData = data.getByteArrayExtra("value") // For photo

                val resultData = mutableMapOf<String, Any?>("type" to resultType)
                if (resultType == "barcode") {
                    resultData["value"] = resultValue
                } else if (resultType == "photo") {
                    resultData["value"] = photoData
                }
                // For "cancel", resultType will be "cancel", value will be null

                println("[Native MainActivity] Sending result to Flutter: $resultData")
                channel.invokeMethod("cameraResult", resultData)

            } else if (resultCode == Activity.RESULT_CANCELED) {
                 // Handle cancellation, send a specific result type back
                 println("[Native MainActivity] Camera cancelled, sending cancel result to Flutter")
                 channel.invokeMethod("cameraResult", mapOf("type" to "cancel"))
            } else {
                // Handle other potential results or errors if needed
                println("[Native MainActivity] Unknown camera result: resultCode=$resultCode")
                channel.invokeMethod("cameraResult", mapOf("type" to "error", "value" to "Unknown camera result code: $resultCode"))
            }
        }
    }
}
