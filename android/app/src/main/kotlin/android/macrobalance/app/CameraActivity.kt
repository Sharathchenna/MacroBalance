package android.macrobalance.app

import android.Manifest
import android.annotation.SuppressLint
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Color
import android.graphics.Matrix
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.net.Uri
import android.os.Bundle
import android.provider.Settings
import android.text.InputType
import android.util.TypedValue
import android.view.Gravity
import android.view.ScaleGestureDetector
import android.view.View
import android.view.ViewGroup.LayoutParams.MATCH_PARENT
import android.view.ViewGroup.LayoutParams.WRAP_CONTENT
import android.widget.EditText
import android.widget.FrameLayout
import android.widget.ImageButton
import android.widget.LinearLayout
import android.widget.TextView
import androidx.activity.OnBackPressedCallback
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.appcompat.app.AlertDialog
import androidx.appcompat.app.AppCompatActivity
import androidx.camera.core.Camera
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.ImageCapture
import androidx.camera.core.ImageCaptureException
import androidx.camera.core.Preview
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.core.content.ContextCompat
import androidx.core.view.ViewCompat
import androidx.core.view.WindowInsetsCompat
import androidx.exifinterface.media.ExifInterface
import com.google.mlkit.vision.barcode.BarcodeScannerOptions
import com.google.mlkit.vision.barcode.BarcodeScanning
import com.google.mlkit.vision.barcode.common.Barcode
import com.google.mlkit.vision.common.InputImage
import java.io.File
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

/**
 * The Android counterpart of the iOS NativeCameraViewController: food photo,
 * barcode and nutrition-label modes over CameraX, barcodes read with ML Kit.
 *
 * It finishes exactly once with a result for [MainActivity] to forward as
 * cameraResult: [EXTRA_TYPE] "barcode" (+ [EXTRA_VALUE]), "photo" (+ a JPEG
 * at [EXTRA_PHOTO_PATH]) or "cancel", and [EXTRA_MODE]. Photos travel as a
 * file because intent extras are limited to about 1 MB.
 */
class CameraActivity : AppCompatActivity() {

    companion object {
        const val EXTRA_INITIAL_MODE = "initialMode"
        const val EXTRA_TYPE = "type"
        const val EXTRA_VALUE = "value"
        const val EXTRA_PHOTO_PATH = "photoPath"
        const val EXTRA_MODE = "mode"

        private const val MODE_BARCODE = "barcode"
        private const val MODE_CAMERA = "camera"
        private const val MODE_LABEL = "label"
        private val MODES = listOf(MODE_BARCODE to "Barcode", MODE_CAMERA to "Photo", MODE_LABEL to "Label")

        /** Longest side of a returned photo; enough for food analysis. */
        private const val MAX_PHOTO_SIDE = 1600
        private const val ACCENT = 0xFF34C85A.toInt()
    }

    private var mode = MODE_CAMERA
    private val finished = AtomicBoolean(false)

    private lateinit var previewView: PreviewView
    private lateinit var guide: View
    private lateinit var hint: TextView
    private lateinit var shutter: View
    private lateinit var manualButton: ImageButton
    private lateinit var torchButton: ImageButton
    private lateinit var permissionPanel: LinearLayout
    private val modeLabels = mutableMapOf<String, TextView>()

    private var camera: Camera? = null
    private var imageCapture: ImageCapture? = null
    private var torchOn = false
    private lateinit var analysisExecutor: ExecutorService
    private val scanner by lazy {
        BarcodeScanning.getClient(
            BarcodeScannerOptions.Builder()
                .setBarcodeFormats(
                    Barcode.FORMAT_EAN_13, Barcode.FORMAT_EAN_8,
                    Barcode.FORMAT_UPC_A, Barcode.FORMAT_UPC_E,
                )
                .build()
        )
    }

    private val requestCamera =
        registerForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
            if (granted) startCamera() else showPermissionPanel()
        }

    private val pickPhoto =
        registerForActivityResult(ActivityResultContracts.PickVisualMedia()) { uri ->
            if (uri != null) returnPhoto { contentResolver.openInputStream(uri)!!.use { it.readBytes() } }
        }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        mode = savedInstanceState?.getString(EXTRA_MODE)
            ?: intent.getStringExtra(EXTRA_INITIAL_MODE)?.takeIf { m -> MODES.any { it.first == m } }
            ?: MODE_CAMERA
        analysisExecutor = Executors.newSingleThreadExecutor()
        setContentView(buildLayout())
        selectMode(mode)
        onBackPressedDispatcher.addCallback(this, object : OnBackPressedCallback(true) {
            override fun handleOnBackPressed() = cancel()
        })
    }

    override fun onResume() {
        super.onResume()
        // Also covers coming back from Settings after granting access.
        if (hasCameraPermission()) {
            permissionPanel.visibility = View.GONE
            if (camera == null) startCamera()
        } else if (permissionPanel.visibility != View.VISIBLE) {
            requestCamera.launch(Manifest.permission.CAMERA)
        }
    }

    override fun onSaveInstanceState(outState: Bundle) {
        super.onSaveInstanceState(outState)
        outState.putString(EXTRA_MODE, mode)
    }

    override fun onDestroy() {
        super.onDestroy()
        analysisExecutor.shutdown()
        scanner.close()
    }

    // region Camera

    private fun hasCameraPermission() =
        ContextCompat.checkSelfPermission(this, Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED

    @SuppressLint("ClickableViewAccessibility")
    private fun startCamera() {
        val providerFuture = ProcessCameraProvider.getInstance(this)
        providerFuture.addListener({
            val provider = providerFuture.get()
            val preview = Preview.Builder().build().also { it.setSurfaceProvider(previewView.surfaceProvider) }
            val capture = ImageCapture.Builder()
                .setCaptureMode(ImageCapture.CAPTURE_MODE_MINIMIZE_LATENCY)
                .build()
            val analysis = ImageAnalysis.Builder()
                .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                .build()
            analysis.setAnalyzer(analysisExecutor) { proxy ->
                val media = proxy.image
                if (mode != MODE_BARCODE || media == null || finished.get()) {
                    proxy.close()
                    return@setAnalyzer
                }
                scanner.process(InputImage.fromMediaImage(media, proxy.imageInfo.rotationDegrees))
                    .addOnSuccessListener { codes ->
                        codes.firstNotNullOfOrNull { it.rawValue }?.let { barcode ->
                            previewView.performHapticFeedback(android.view.HapticFeedbackConstants.CONFIRM)
                            finishWith("barcode", value = barcode)
                        }
                    }
                    .addOnCompleteListener { proxy.close() }
            }
            try {
                provider.unbindAll()
                camera = provider.bindToLifecycle(
                    this, CameraSelector.DEFAULT_BACK_CAMERA, preview, capture, analysis,
                )
                imageCapture = capture
                torchButton.visibility =
                    if (camera?.cameraInfo?.hasFlashUnit() == true) View.VISIBLE else View.GONE
                camera?.cameraControl?.enableTorch(torchOn)
            } catch (e: Exception) {
                hint.text = "Couldn’t start the camera."
            }
        }, ContextCompat.getMainExecutor(this))

        val zoom = ScaleGestureDetector(this, object : ScaleGestureDetector.SimpleOnScaleGestureListener() {
            override fun onScale(detector: ScaleGestureDetector): Boolean {
                val state = camera?.cameraInfo?.zoomState?.value ?: return false
                camera?.cameraControl?.setZoomRatio(
                    (state.zoomRatio * detector.scaleFactor).coerceIn(state.minZoomRatio, state.maxZoomRatio)
                )
                return true
            }
        })
        previewView.setOnTouchListener { _, event -> zoom.onTouchEvent(event) }
    }

    private fun takePhoto() {
        val capture = imageCapture ?: return
        shutter.isEnabled = false
        val file = File.createTempFile("capture", ".jpg", cacheDir)
        capture.takePicture(
            ImageCapture.OutputFileOptions.Builder(file).build(),
            ContextCompat.getMainExecutor(this),
            object : ImageCapture.OnImageSavedCallback {
                override fun onImageSaved(output: ImageCapture.OutputFileResults) {
                    returnPhoto { file.readBytes().also { file.delete() } }
                }

                override fun onError(e: ImageCaptureException) {
                    file.delete()
                    shutter.isEnabled = true
                    hint.text = "Couldn’t take the photo. Try again."
                }
            },
        )
    }

    /** Downscales and rotates upright off the main thread, then finishes. */
    private fun returnPhoto(readJpeg: () -> ByteArray) {
        shutter.isEnabled = false
        hint.text = "Preparing photo…"
        analysisExecutor.execute {
            val path = try {
                normalizedJpeg(readJpeg()).absolutePath
            } catch (e: Exception) {
                null
            }
            runOnUiThread {
                if (path == null) {
                    shutter.isEnabled = true
                    hint.text = "Couldn’t read that photo."
                } else {
                    finishWith("photo", photoPath = path)
                }
            }
        }
    }

    private fun normalizedJpeg(bytes: ByteArray): File {
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeByteArray(bytes, 0, bytes.size, bounds)
        var sample = 1
        while (maxOf(bounds.outWidth, bounds.outHeight) / (sample * 2) >= MAX_PHOTO_SIDE) sample *= 2
        var bitmap = BitmapFactory.decodeByteArray(
            bytes, 0, bytes.size, BitmapFactory.Options().apply { inSampleSize = sample },
        ) ?: error("Not an image")

        val rotation = ExifInterface(bytes.inputStream()).rotationDegrees
        val scale = MAX_PHOTO_SIDE.toFloat() / maxOf(bitmap.width, bitmap.height)
        if (rotation != 0 || scale < 1f) {
            val matrix = Matrix().apply {
                if (scale < 1f) postScale(scale, scale)
                postRotate(rotation.toFloat())
            }
            bitmap = Bitmap.createBitmap(bitmap, 0, 0, bitmap.width, bitmap.height, matrix, true)
        }
        return File.createTempFile("camera_result", ".jpg", cacheDir).also { out ->
            out.outputStream().use { bitmap.compress(Bitmap.CompressFormat.JPEG, 80, it) }
        }
    }

    private fun toggleTorch() {
        torchOn = !torchOn
        camera?.cameraControl?.enableTorch(torchOn)
        torchButton.setImageResource(if (torchOn) R.drawable.ic_camera_flash_on else R.drawable.ic_camera_flash_off)
    }

    // endregion

    // region Results

    private fun finishWith(type: String, value: String? = null, photoPath: String? = null) {
        if (!finished.compareAndSet(false, true)) return
        runOnUiThread {
            setResult(RESULT_OK, Intent().apply {
                putExtra(EXTRA_TYPE, type)
                putExtra(EXTRA_MODE, mode)
                value?.let { putExtra(EXTRA_VALUE, it) }
                photoPath?.let { putExtra(EXTRA_PHOTO_PATH, it) }
            })
            finish()
        }
    }

    private fun cancel() {
        if (!finished.compareAndSet(false, true)) return
        setResult(RESULT_CANCELED)
        finish()
    }

    private fun showManualEntry() {
        val input = EditText(this).apply {
            inputType = InputType.TYPE_CLASS_NUMBER
            hint = "Barcode number"
        }
        val box = FrameLayout(this).apply {
            setPadding(dp(20), dp(8), dp(20), 0)
            addView(input)
        }
        val dialog = AlertDialog.Builder(this)
            .setTitle("Enter barcode")
            .setView(box)
            .setNegativeButton("Cancel", null)
            .setPositiveButton("Search", null)
            .create()
        dialog.setOnShowListener {
            dialog.getButton(AlertDialog.BUTTON_POSITIVE).setOnClickListener {
                val code = input.text.toString().trim()
                if (code.length !in 8..14) {
                    input.error = "Barcodes have 8 to 14 digits"
                } else {
                    dialog.dismiss()
                    finishWith("barcode", value = code)
                }
            }
        }
        dialog.show()
    }

    // endregion

    // region Layout

    private fun selectMode(newMode: String) {
        mode = newMode
        modeLabels.forEach { (m, label) ->
            val on = m == mode
            label.setTextColor(if (on) Color.BLACK else Color.WHITE)
            label.background = if (on) pill(Color.WHITE) else null
        }
        val barcode = mode == MODE_BARCODE
        shutter.visibility = if (barcode) View.INVISIBLE else View.VISIBLE
        manualButton.visibility = if (barcode) View.VISIBLE else View.INVISIBLE
        hint.text = when (mode) {
            MODE_BARCODE -> "Point at a barcode. It scans by itself."
            MODE_LABEL -> "Fit the nutrition label in the frame"
            else -> "Take a photo of your meal"
        }
        guide.layoutParams = (guide.layoutParams as FrameLayout.LayoutParams).apply {
            width = dp(if (barcode) 300 else 290)
            height = dp(when (mode) { MODE_BARCODE -> 150; MODE_LABEL -> 400; else -> 290 })
        }
    }

    private fun buildLayout(): View {
        val root = FrameLayout(this).apply { setBackgroundColor(Color.BLACK) }

        previewView = PreviewView(this).apply { scaleType = PreviewView.ScaleType.FILL_CENTER }
        root.addView(previewView, FrameLayout.LayoutParams(MATCH_PARENT, MATCH_PARENT))

        guide = View(this).apply {
            background = GradientDrawable().apply {
                cornerRadius = dp(20).toFloat()
                setStroke(dp(3), Color.WHITE)
            }
        }
        root.addView(guide, FrameLayout.LayoutParams(dp(290), dp(290), Gravity.CENTER))

        // Top bar: close and torch.
        val top = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            setPadding(dp(16), dp(12), dp(16), 0)
        }
        top.addView(iconButton(R.drawable.ic_camera_close, "Close") { cancel() })
        top.addView(View(this), LinearLayout.LayoutParams(0, 1, 1f))
        torchButton = iconButton(R.drawable.ic_camera_flash_off, "Flashlight") { toggleTorch() }
        top.addView(torchButton)
        root.addView(top, FrameLayout.LayoutParams(MATCH_PARENT, WRAP_CONTENT, Gravity.TOP))

        // Bottom: hint, modes, then gallery / shutter / manual entry.
        val bottom = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_HORIZONTAL
            setPadding(dp(16), 0, dp(16), dp(20))
        }
        hint = TextView(this).apply {
            setTextColor(Color.WHITE)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 15f)
            gravity = Gravity.CENTER
            setShadowLayer(6f, 0f, 1f, Color.BLACK)
        }
        bottom.addView(hint, LinearLayout.LayoutParams(MATCH_PARENT, WRAP_CONTENT).apply { bottomMargin = dp(16) })

        val modes = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            background = pill(0x66000000)
            setPadding(dp(4), dp(4), dp(4), dp(4))
        }
        MODES.forEach { (m, title) ->
            val label = TextView(this).apply {
                text = title
                setTypeface(typeface, Typeface.BOLD)
                setTextSize(TypedValue.COMPLEX_UNIT_SP, 14f)
                setPadding(dp(18), dp(8), dp(18), dp(8))
                setOnClickListener { selectMode(m) }
            }
            modeLabels[m] = label
            modes.addView(label)
        }
        bottom.addView(modes, LinearLayout.LayoutParams(WRAP_CONTENT, WRAP_CONTENT).apply { bottomMargin = dp(20) })

        val controls = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
        }
        controls.addView(iconButton(R.drawable.ic_camera_gallery, "Choose from photos") {
            pickPhoto.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly))
        })
        controls.addView(View(this), LinearLayout.LayoutParams(0, 1, 1f))
        shutter = View(this).apply {
            contentDescription = "Take photo"
            background = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(Color.WHITE)
                setStroke(dp(5), ACCENT)
            }
            setOnClickListener { takePhoto() }
        }
        controls.addView(shutter, LinearLayout.LayoutParams(dp(76), dp(76)))
        controls.addView(View(this), LinearLayout.LayoutParams(0, 1, 1f))
        manualButton = iconButton(R.drawable.ic_camera_keyboard, "Enter barcode") { showManualEntry() }
        controls.addView(manualButton)
        bottom.addView(controls, LinearLayout.LayoutParams(MATCH_PARENT, WRAP_CONTENT))
        root.addView(bottom, FrameLayout.LayoutParams(MATCH_PARENT, WRAP_CONTENT, Gravity.BOTTOM))

        permissionPanel = buildPermissionPanel()
        root.addView(permissionPanel, FrameLayout.LayoutParams(MATCH_PARENT, MATCH_PARENT))

        // Keep controls clear of the status and navigation bars (edge-to-edge).
        ViewCompat.setOnApplyWindowInsetsListener(root) { _, insets ->
            val bars = insets.getInsets(WindowInsetsCompat.Type.systemBars())
            top.setPadding(dp(16), bars.top + dp(12), dp(16), 0)
            bottom.setPadding(dp(16), 0, dp(16), bars.bottom + dp(20))
            insets
        }
        return root
    }

    private fun buildPermissionPanel() = LinearLayout(this).apply {
        orientation = LinearLayout.VERTICAL
        gravity = Gravity.CENTER
        setBackgroundColor(Color.BLACK)
        setPadding(dp(32), 0, dp(32), 0)
        visibility = View.GONE
        isClickable = true
        addView(TextView(context).apply {
            text = "Camera access is off"
            setTextColor(Color.WHITE)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 20f)
            setTypeface(typeface, Typeface.BOLD)
            gravity = Gravity.CENTER
        })
        addView(TextView(context).apply {
            text = "Allow camera access in Settings to photograph meals and scan barcodes. You can still choose a photo or type a barcode."
            setTextColor(0xCCFFFFFF.toInt())
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 15f)
            gravity = Gravity.CENTER
            setPadding(0, dp(12), 0, dp(24))
        })
        addView(textButton("Open Settings", filled = true) {
            startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.fromParts("package", packageName, null)))
        })
        addView(textButton("Choose a photo") {
            pickPhoto.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly))
        })
        addView(textButton("Type a barcode") { showManualEntry() })
        addView(textButton("Close") { cancel() })
    }

    private fun showPermissionPanel() {
        permissionPanel.visibility = View.VISIBLE
    }

    private fun iconButton(icon: Int, description: String, onClick: () -> Unit) = ImageButton(this).apply {
        setImageResource(icon)
        contentDescription = description
        background = GradientDrawable().apply {
            shape = GradientDrawable.OVAL
            setColor(0x80000000.toInt())
        }
        layoutParams = LinearLayout.LayoutParams(dp(48), dp(48))
        setOnClickListener { onClick() }
    }

    private fun textButton(title: String, filled: Boolean = false, onClick: () -> Unit) = TextView(this).apply {
        text = title
        gravity = Gravity.CENTER
        setTextSize(TypedValue.COMPLEX_UNIT_SP, 16f)
        setTypeface(typeface, Typeface.BOLD)
        setTextColor(if (filled) Color.BLACK else Color.WHITE)
        if (filled) background = pill(ACCENT)
        setPadding(dp(24), dp(14), dp(24), dp(14))
        layoutParams = LinearLayout.LayoutParams(MATCH_PARENT, WRAP_CONTENT).apply { topMargin = dp(8) }
        setOnClickListener { onClick() }
    }

    private fun pill(color: Int) = GradientDrawable().apply {
        cornerRadius = dp(100).toFloat()
        setColor(color)
    }

    private fun dp(value: Int) = TypedValue.applyDimension(
        TypedValue.COMPLEX_UNIT_DIP, value.toFloat(), resources.displayMetrics,
    ).toInt()

    // endregion
}
