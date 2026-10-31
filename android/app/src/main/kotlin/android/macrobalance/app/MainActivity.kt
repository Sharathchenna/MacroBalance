package android.macrobalance.app

import android.content.Intent
import androidx.activity.result.contract.ActivityResultContracts
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterFragmentActivity() {
    private val cameraChannelName = "com.macrotracker/native_camera_view"
    private var cameraChannel: MethodChannel? = null

    /** CameraActivity's one result, forwarded to Dart as cameraResult. */
    private val camera =
        registerForActivityResult(ActivityResultContracts.StartActivityForResult()) { result ->
            cameraChannel?.invokeMethod("cameraResult", cameraResult(result.data))
        }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        cameraChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, cameraChannelName).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "showNativeCamera" -> {
                        val initialMode = call.argument<String>("initialMode")
                        camera.launch(Intent(this@MainActivity, CameraActivity::class.java).apply {
                            initialMode?.let { putExtra(CameraActivity.EXTRA_INITIAL_MODE, it) }
                        })
                        // Shown; the capture arrives later as cameraResult.
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    /** The same shape iOS sends: type, value (String or JPEG bytes) and mode. */
    private fun cameraResult(data: Intent?): Map<String, Any?> {
        val type = data?.getStringExtra(CameraActivity.EXTRA_TYPE) ?: return mapOf("type" to "cancel")
        val mode = data.getStringExtra(CameraActivity.EXTRA_MODE)
        return when (type) {
            "barcode" -> mapOf("type" to type, "value" to data.getStringExtra(CameraActivity.EXTRA_VALUE), "mode" to mode)
            "photo" -> {
                val file = data.getStringExtra(CameraActivity.EXTRA_PHOTO_PATH)?.let(::File)
                val bytes = file?.takeIf { it.exists() }?.readBytes().also { file?.delete() }
                    ?: return mapOf("type" to "error", "value" to "The photo couldn’t be read")
                mapOf("type" to "photo", "value" to bytes, "mode" to mode)
            }
            else -> mapOf("type" to "cancel")
        }
    }
}
