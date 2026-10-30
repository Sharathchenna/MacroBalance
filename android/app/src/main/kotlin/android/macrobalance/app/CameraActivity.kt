package android.macrobalance.app

import android.Manifest
import android.annotation.SuppressLint
import android.app.Dialog
import android.content.Intent
import android.content.pm.PackageManager
import android.content.res.ColorStateList
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Color
import android.graphics.Matrix
import android.graphics.Rect
import android.graphics.RectF
import android.graphics.Typeface
import android.graphics.drawable.ColorDrawable
import android.graphics.drawable.GradientDrawable
import android.graphics.drawable.LayerDrawable
import android.net.Uri
import android.os.Bundle
import android.provider.Settings
import android.text.Editable
import android.text.InputType
import android.text.SpannableStringBuilder
import android.text.Spanned
import android.text.TextWatcher
import android.text.style.AbsoluteSizeSpan
import android.text.style.ForegroundColorSpan
import android.util.TypedValue
import android.view.Gravity
import android.view.HapticFeedbackConstants
import android.view.ScaleGestureDetector
import android.view.View
import android.view.ViewGroup.LayoutParams.MATCH_PARENT
import android.view.ViewGroup.LayoutParams.WRAP_CONTENT
import android.view.Window
import android.view.WindowManager
import android.view.inputmethod.EditorInfo
import android.view.inputmethod.InputMethodManager
import android.widget.EditText
import android.widget.FrameLayout
import android.widget.ImageButton
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import android.widget.Toast
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
import androidx.camera.core.ImageProxy
import androidx.camera.core.Preview
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.core.content.ContextCompat
import androidx.core.view.ViewCompat
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.WindowInsetsControllerCompat
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
 * The Android counterpart of the iOS NativeCameraViewController, laid out
 * the same way: a dark top band (close, info, flash, instruction), scan
 * guides for barcode and label modes, an icon segmented control, and gallery
 * / shutter / manual-entry buttons. CameraX for preview and capture, ML Kit
 * for barcodes.
 *
 * It finishes exactly once with a result for [MainActivity] to forward as
 * cameraResult: [EXTRA_TYPE] "barcode" (+ [EXTRA_VALUE]), "photo" (+ a JPEG
 * at [EXTRA_PHOTO_PATH]) or none for cancel, and [EXTRA_MODE]. Photos travel
 * as a file because intent extras are limited to about 1 MB.
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
        private val MODES = listOf(
            MODE_BARCODE to R.drawable.ic_camera_mode_barcode,
            MODE_CAMERA to R.drawable.ic_camera_mode_photo,
            MODE_LABEL to R.drawable.ic_camera_mode_label,
        )

        /** Longest side of a returned photo; enough for food analysis. */
        private const val MAX_PHOTO_SIDE = 1600

        // The iOS camera's colours.
        private const val GOLD = 0xFFEDC954.toInt()
        private const val PANEL = 0xD91F1F1F.toInt() // white 0.12, alpha 0.85
        private const val OVERLAY = 0x66000000 // black, alpha 0.4
        private const val SUCCESS = 0xFF34C759.toInt()
    }

    private var mode = MODE_CAMERA
    private val finished = AtomicBoolean(false)

    /** A barcode was seen in the guide; the screen is about to close. */
    private val barcodeFound = AtomicBoolean(false)

    private lateinit var previewView: PreviewView
    private lateinit var barcodeGuide: View
    private lateinit var labelGuide: View
    private lateinit var instruction: TextView
    private lateinit var shutter: View
    private lateinit var flashButton: ImageButton
    private val modeSegments = mutableMapOf<String, ImageView>()

    private var camera: Camera? = null
    private var imageCapture: ImageCapture? = null
    private var torchOn = false
    private var permissionDialogShown = false
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
            if (granted) startCamera() else showPermissionError()
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

        // Full screen with the status bar hidden, as on iOS.
        WindowCompat.setDecorFitsSystemWindows(window, false)
        WindowInsetsControllerCompat(window, window.decorView).apply {
            hide(WindowInsetsCompat.Type.statusBars())
            systemBarsBehavior = WindowInsetsControllerCompat.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
        }

        setContentView(buildLayout())
        selectMode(mode, animate = false)
        onBackPressedDispatcher.addCallback(this, object : OnBackPressedCallback(true) {
            override fun handleOnBackPressed() = cancel()
        })
    }

    override fun onResume() {
        super.onResume()
        // Also covers coming back from Settings after granting access.
        if (hasCameraPermission()) {
            if (camera == null) startCamera()
        } else if (!permissionDialogShown) {
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
            analysis.setAnalyzer(analysisExecutor, ::analyzeFrame)
            try {
                provider.unbindAll()
                camera = provider.bindToLifecycle(
                    this, CameraSelector.DEFAULT_BACK_CAMERA, preview, capture, analysis,
                )
                imageCapture = capture
                camera?.cameraControl?.enableTorch(torchOn)
            } catch (e: Exception) {
                showError("Camera Error", "Could not start the camera.")
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

    /** Continuous scanning in barcode mode; only barcodes mostly inside the guide count (as on iOS). */
    @SuppressLint("UnsafeOptInUsageError")
    private fun analyzeFrame(proxy: ImageProxy) {
        val media = proxy.image
        if (mode != MODE_BARCODE || media == null || barcodeFound.get() || finished.get()) {
            proxy.close()
            return
        }
        val rotation = proxy.imageInfo.rotationDegrees
        val upright = if (rotation % 180 == 0) proxy.width to proxy.height else proxy.height to proxy.width
        scanner.process(InputImage.fromMediaImage(media, rotation))
            .addOnSuccessListener { codes ->
                val hit = codes.firstOrNull { code ->
                    code.rawValue != null && code.boundingBox?.let { insideGuide(it, upright) } == true
                }
                hit?.rawValue?.let(::barcodeDetected)
            }
            .addOnCompleteListener { proxy.close() }
    }

    /** Maps a box from the upright analysis image onto the screen (the preview fills it, centre-cropped). */
    private fun insideGuide(box: Rect, image: Pair<Int, Int>): Boolean {
        val (imageW, imageH) = image
        val viewW = previewView.width.toFloat()
        val viewH = previewView.height.toFloat()
        if (viewW == 0f || imageW == 0) return false
        val scale = maxOf(viewW / imageW, viewH / imageH)
        val dx = (viewW - imageW * scale) / 2
        val dy = (viewH - imageH * scale) / 2
        val onScreen = RectF(box.left * scale + dx, box.top * scale + dy, box.right * scale + dx, box.bottom * scale + dy)
        val guide = RectF(
            barcodeGuide.left.toFloat(), barcodeGuide.top.toFloat(),
            barcodeGuide.right.toFloat(), barcodeGuide.bottom.toFloat(),
        )
        val overlap = RectF()
        if (!overlap.setIntersect(onScreen, guide)) return false
        return overlap.width() * overlap.height() > 0.5f * onScreen.width() * onScreen.height()
    }

    /** Guide flashes green and pulses, then the result goes back (iOS timing). */
    private fun barcodeDetected(barcode: String) {
        if (!barcodeFound.compareAndSet(false, true)) return
        runOnUiThread {
            haptic()
            barcodeGuide.background = guideDrawable(SUCCESS)
            barcodeGuide.animate().scaleX(1.05f).scaleY(1.05f).setDuration(150).withEndAction {
                barcodeGuide.animate().scaleX(1f).scaleY(1f).setDuration(100).start()
            }.start()
            barcodeGuide.postDelayed({ finishWith("barcode", value = barcode) }, 600)
        }
    }

    private fun onShutter() {
        haptic()
        shutter.animate().scaleX(0.9f).scaleY(0.9f).setDuration(100).withEndAction {
            shutter.animate().scaleX(1f).scaleY(1f).setDuration(100).start()
        }.start()
        if (mode == MODE_BARCODE) scanStill() else takePhoto()
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
                    showError("Camera Error", "Could not take the photo. Please try again.")
                }
            },
        )
    }

    /** Barcode mode's shutter: look for a barcode anywhere in a still, for when live scanning struggles. */
    @SuppressLint("UnsafeOptInUsageError")
    private fun scanStill() {
        val capture = imageCapture ?: return
        capture.takePicture(ContextCompat.getMainExecutor(this), object : ImageCapture.OnImageCapturedCallback() {
            override fun onCaptureSuccess(image: ImageProxy) {
                val media = image.image ?: return image.close()
                scanner.process(InputImage.fromMediaImage(media, image.imageInfo.rotationDegrees))
                    .addOnSuccessListener { codes ->
                        val code = codes.firstNotNullOfOrNull { it.rawValue }
                        if (code != null) barcodeDetected(code)
                        else Toast.makeText(this@CameraActivity, "No barcode found", Toast.LENGTH_SHORT).show()
                    }
                    .addOnCompleteListener { image.close() }
            }

            override fun onError(exception: ImageCaptureException) {}
        })
    }

    /** Downscales and rotates upright off the main thread, then finishes. */
    private fun returnPhoto(readJpeg: () -> ByteArray) {
        shutter.isEnabled = false
        analysisExecutor.execute {
            val path = try {
                normalizedJpeg(readJpeg()).absolutePath
            } catch (e: Exception) {
                null
            }
            runOnUiThread {
                if (path == null) {
                    shutter.isEnabled = true
                    showError("Camera Error", "Could not read that photo.")
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

    private fun toggleFlash() {
        haptic()
        if (camera?.cameraInfo?.hasFlashUnit() != true) return
        torchOn = !torchOn
        camera?.cameraControl?.enableTorch(torchOn)
        flashButton.setImageResource(if (torchOn) R.drawable.ic_camera_flash_on else R.drawable.ic_camera_flash_off)
        flashButton.imageTintList = ColorStateList.valueOf(if (torchOn) GOLD else withAlpha(GOLD, 0.8f))
        val pulse = if (torchOn) 1.2f else 0.9f
        flashButton.animate().scaleX(pulse).scaleY(pulse).setDuration(if (torchOn) 200 else 150).withEndAction {
            flashButton.animate().scaleX(1f).scaleY(1f).setDuration(if (torchOn) 200 else 150).start()
        }.start()
    }

    // endregion

    // region Results

    private fun finishWith(type: String, value: String? = null, photoPath: String? = null) {
        if (!finished.compareAndSet(false, true)) return
        runOnUiThread {
            setResult(RESULT_OK, Intent().apply {
                putExtra(EXTRA_TYPE, type)
                putExtra(EXTRA_MODE, if (type == "barcode") MODE_BARCODE else mode)
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

    // endregion

    // region Dialogs

    /** iOS shows "Camera Error / Camera access denied." and closes; here Settings is offered too. */
    private fun showPermissionError() {
        permissionDialogShown = true
        AlertDialog.Builder(this, android.R.style.Theme_DeviceDefault_Dialog_Alert)
            .setTitle("Camera Error")
            .setMessage("Camera access denied. You can allow it in Settings.")
            .setCancelable(false)
            .setNegativeButton("OK") { _, _ -> cancel() }
            .setPositiveButton("Open Settings") { _, _ ->
                permissionDialogShown = false
                startActivity(
                    Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.fromParts("package", packageName, null))
                )
            }
            .show()
    }

    private fun showError(title: String, message: String) {
        AlertDialog.Builder(this, android.R.style.Theme_DeviceDefault_Dialog_Alert)
            .setTitle(title)
            .setMessage(message)
            .setPositiveButton("OK", null)
            .show()
    }

    private fun showInfo() {
        haptic()
        val (title, message, disclaimer) = when (mode) {
            MODE_BARCODE -> Triple(
                "Barcode Scanner",
                "Position the barcode within the highlighted area. Hold the device steady, and the scanner will automatically detect and process valid barcodes.",
                "Note: Some barcodes may not be recognized. You can use manual entry if scanning fails.",
            )
            MODE_LABEL -> Triple(
                "Nutrition Label Scanner",
                "Position the entire nutrition label within the highlighted area. Try to capture the full label with good lighting for best results.",
                "AI results are estimates and should be verified for accuracy.",
            )
            else -> Triple(
                "Photo Mode",
                "Take a clear photo of your food or product. Make sure there's good lighting for best results.",
                "AI results are estimates and should be verified for accuracy.",
            )
        }
        val text = SpannableStringBuilder(message).append("\n\n")
        val start = text.length
        text.append(disclaimer)
        text.setSpan(ForegroundColorSpan(0xCCFF3B30.toInt()), start, text.length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
        text.setSpan(AbsoluteSizeSpan(12, true), start, text.length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
        AlertDialog.Builder(this, android.R.style.Theme_DeviceDefault_Dialog_Alert)
            .setTitle(title)
            .setMessage(text)
            .setPositiveButton("Got it", null)
            .show()
    }

    /** Full-screen sheet like iOS's ManualBarcodeEntryViewController. */
    private fun showManualEntry() {
        haptic()
        val dialog = Dialog(this, android.R.style.Theme_DeviceDefault_NoActionBar)
        dialog.requestWindowFeature(Window.FEATURE_NO_TITLE)
        val dark = (resources.configuration.uiMode and android.content.res.Configuration.UI_MODE_NIGHT_MASK) ==
            android.content.res.Configuration.UI_MODE_NIGHT_YES
        val screenColor = if (dark) Color.BLACK else 0xFFF2F2F7.toInt()
        val cardColor = if (dark) 0xFF1C1C1E.toInt() else Color.WHITE
        val label = if (dark) Color.WHITE else Color.BLACK
        val secondary = if (dark) 0x99EBEBF5.toInt() else 0x993C3C43.toInt()

        val field = EditText(this).apply {
            hint = "Enter barcode number"
            inputType = InputType.TYPE_CLASS_NUMBER
            imeOptions = EditorInfo.IME_ACTION_DONE
            typeface = Typeface.MONOSPACE
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 24f)
            setTextColor(label)
            setHintTextColor(secondary)
            gravity = Gravity.CENTER
            background = GradientDrawable().apply {
                cornerRadius = dp(12).toFloat()
                setColor(if (dark) Color.BLACK else Color.WHITE)
                setStroke(dp(1), if (dark) 0xFF3A3A3C.toInt() else 0xFFD1D1D6.toInt())
            }
            setPadding(dp(12), dp(14), dp(12), dp(14))
        }
        val submit = navIcon(R.drawable.ic_camera_check, "Done")
        submit.isEnabled = false
        submit.alpha = 0.4f
        fun done() {
            val code = field.text.toString().trim()
            if (code.isEmpty()) return
            haptic()
            dialog.dismiss()
            finishWith("barcode", value = code)
        }
        submit.setOnClickListener { done() }
        field.addTextChangedListener(object : TextWatcher {
            override fun beforeTextChanged(s: CharSequence?, start: Int, count: Int, after: Int) {}
            override fun onTextChanged(s: CharSequence?, start: Int, before: Int, count: Int) {}
            override fun afterTextChanged(s: Editable?) {
                submit.isEnabled = !s.isNullOrBlank()
                submit.alpha = if (submit.isEnabled) 1f else 0.4f
            }
        })
        field.setOnEditorActionListener { _, _, _ -> done(); true }

        val close = navIcon(R.drawable.ic_camera_close, "Cancel").apply { setOnClickListener { dialog.dismiss() } }
        val bar = FrameLayout(this).apply {
            addView(close, FrameLayout.LayoutParams(dp(44), dp(44), Gravity.START or Gravity.CENTER_VERTICAL))
            addView(TextView(context).apply {
                text = "Enter Barcode"
                setTextColor(label)
                setTextSize(TypedValue.COMPLEX_UNIT_SP, 17f)
                setTypeface(typeface, Typeface.BOLD)
            }, FrameLayout.LayoutParams(WRAP_CONTENT, WRAP_CONTENT, Gravity.CENTER))
            addView(submit, FrameLayout.LayoutParams(dp(44), dp(44), Gravity.END or Gravity.CENTER_VERTICAL))
        }
        val content = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_HORIZONTAL
            background = GradientDrawable().apply {
                cornerRadius = dp(16).toFloat()
                setColor(cardColor)
            }
            elevation = dp(4).toFloat()
            setPadding(dp(16), dp(24), dp(16), dp(24))
            addView(ImageView(context).apply {
                setImageResource(R.drawable.ic_camera_mode_barcode)
                imageTintList = ColorStateList.valueOf(GOLD)
            }, LinearLayout.LayoutParams(dp(60), dp(60)))
            addView(TextView(context).apply {
                text = "Manual Barcode Entry"
                setTextColor(label)
                setTextSize(TypedValue.COMPLEX_UNIT_SP, 20f)
                setTypeface(typeface, Typeface.BOLD)
                gravity = Gravity.CENTER
            }, LinearLayout.LayoutParams(MATCH_PARENT, WRAP_CONTENT).apply { topMargin = dp(16) })
            addView(TextView(context).apply {
                text = "Enter the barcode number below"
                setTextColor(secondary)
                setTextSize(TypedValue.COMPLEX_UNIT_SP, 14f)
                gravity = Gravity.CENTER
            }, LinearLayout.LayoutParams(MATCH_PARENT, WRAP_CONTENT).apply { topMargin = dp(8) })
            addView(field, LinearLayout.LayoutParams(MATCH_PARENT, WRAP_CONTENT).apply { topMargin = dp(24) })
        }
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundColor(screenColor)
            setPadding(dp(8), dp(8), dp(8), 0)
            addView(bar, LinearLayout.LayoutParams(MATCH_PARENT, dp(52)))
            addView(content, LinearLayout.LayoutParams(MATCH_PARENT, WRAP_CONTENT).apply {
                setMargins(dp(12), dp(24), dp(12), 0)
            })
        }
        ViewCompat.setOnApplyWindowInsetsListener(root) { v, insets ->
            val top = insets.getInsets(WindowInsetsCompat.Type.systemBars() or WindowInsetsCompat.Type.displayCutout()).top
            v.setPadding(dp(8), top + dp(8), dp(8), 0)
            insets
        }
        dialog.setContentView(root)
        dialog.window?.apply {
            setLayout(MATCH_PARENT, MATCH_PARENT)
            setBackgroundDrawable(ColorDrawable(screenColor))
            setWindowAnimations(android.R.style.Animation_InputMethod)
            setSoftInputMode(WindowManager.LayoutParams.SOFT_INPUT_STATE_ALWAYS_VISIBLE)
        }
        dialog.setOnShowListener {
            field.requestFocus()
            getSystemService(InputMethodManager::class.java).showSoftInput(field, InputMethodManager.SHOW_IMPLICIT)
        }
        dialog.show()
    }

    private fun navIcon(icon: Int, description: String) = ImageButton(this).apply {
        setImageResource(icon)
        imageTintList = ColorStateList.valueOf(GOLD)
        contentDescription = description
        background = null
    }

    // endregion

    // region Layout

    private fun selectMode(newMode: String, animate: Boolean = true) {
        if (animate && newMode != mode) haptic()
        mode = newMode
        modeSegments.forEach { (m, icon) ->
            val on = m == mode
            icon.imageTintList = ColorStateList.valueOf(if (on) Color.BLACK else Color.WHITE)
            icon.background = if (on) rounded(GOLD, 12) else null
        }
        barcodeGuide.visibility = if (mode == MODE_BARCODE) View.VISIBLE else View.GONE
        labelGuide.visibility = if (mode == MODE_LABEL) View.VISIBLE else View.GONE
        instruction.text = when (mode) {
            MODE_BARCODE -> "Scan a barcode"
            MODE_LABEL -> "Scan a nutrition label"
            else -> "Take a photo"
        }
    }

    private fun buildLayout(): View {
        val root = FrameLayout(this).apply { setBackgroundColor(Color.BLACK) }

        previewView = PreviewView(this).apply { scaleType = PreviewView.ScaleType.FILL_CENTER }
        root.addView(previewView, FrameLayout.LayoutParams(MATCH_PARENT, MATCH_PARENT))

        // Scan guides, sized like iOS's (fractions of the screen).
        val screenW = resources.displayMetrics.widthPixels
        val screenH = resources.displayMetrics.heightPixels
        barcodeGuide = View(this).apply { background = guideDrawable(GOLD) }
        root.addView(barcodeGuide, FrameLayout.LayoutParams((screenW * 0.7f).toInt(), (screenH * 0.15f).toInt(), Gravity.CENTER))
        labelGuide = View(this).apply { background = guideDrawable(GOLD) }
        root.addView(labelGuide, FrameLayout.LayoutParams((screenW * 0.85f).toInt(), (screenH * 0.4f).toInt(), Gravity.CENTER))

        // Top band: close, info, flash, then the instruction.
        val topBar = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            background = LayerDrawable(arrayOf(
                GradientDrawable(
                    GradientDrawable.Orientation.TOP_BOTTOM,
                    intArrayOf(0x8C000000.toInt(), 0x59000000),
                ),
                GradientDrawable().apply { setColor(withAlpha(GOLD, 0.2f)) },
            )).apply {
                setLayerGravity(1, Gravity.BOTTOM)
                setLayerHeight(1, dp(1))
            }
        }
        val buttons = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
        }
        buttons.addView(roundButton(R.drawable.ic_camera_close, "Close", Color.WHITE) { haptic(); cancel() })
        buttons.addView(View(this), LinearLayout.LayoutParams(0, 1, 1f))
        buttons.addView(roundButton(R.drawable.ic_camera_info, "Help", Color.WHITE) { showInfo() })
        buttons.addView(View(this), LinearLayout.LayoutParams(dp(15), 1))
        flashButton = roundButton(R.drawable.ic_camera_flash_off, "Flashlight", withAlpha(GOLD, 0.8f)) { toggleFlash() }
        buttons.addView(flashButton)
        topBar.addView(buttons, LinearLayout.LayoutParams(MATCH_PARENT, WRAP_CONTENT))
        instruction = TextView(this).apply {
            setTextColor(Color.WHITE)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 16f)
            setTypeface(typeface, Typeface.BOLD)
            letterSpacing = 0.05f
            gravity = Gravity.CENTER
            setShadowLayer(6f, 0f, 3f, withAlpha(GOLD, 0.4f))
        }
        topBar.addView(instruction, LinearLayout.LayoutParams(MATCH_PARENT, WRAP_CONTENT).apply {
            topMargin = dp(15)
            bottomMargin = dp(15)
        })
        root.addView(topBar, FrameLayout.LayoutParams(MATCH_PARENT, WRAP_CONTENT, Gravity.TOP))

        // Bottom: mode control above gallery / shutter / manual entry.
        val bottom = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_HORIZONTAL
        }
        val modes = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            background = rounded(PANEL, 16).apply { setStroke(dp(1) / 2, withAlpha(GOLD, 0.3f)) }
            elevation = dp(6).toFloat()
            setPadding(dp(3), dp(3), dp(3), dp(3))
        }
        MODES.forEach { (m, icon) ->
            val segment = ImageView(this).apply {
                setImageResource(icon)
                scaleType = ImageView.ScaleType.CENTER
                contentDescription = when (m) { MODE_BARCODE -> "Barcode"; MODE_LABEL -> "Nutrition label"; else -> "Photo" }
                setOnClickListener { selectMode(m) }
            }
            modeSegments[m] = segment
            modes.addView(segment, LinearLayout.LayoutParams(0, MATCH_PARENT, 1f))
        }
        bottom.addView(modes, LinearLayout.LayoutParams((screenW * 0.7f).toInt(), dp(40)).apply { bottomMargin = dp(20) })

        val controls = FrameLayout(this)
        controls.addView(
            roundButton(R.drawable.ic_camera_gallery, "Choose from photos", Color.WHITE, OVERLAY, size = 48) {
                haptic()
                pickPhoto.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly))
            },
            FrameLayout.LayoutParams(dp(48), dp(48), Gravity.START or Gravity.CENTER_VERTICAL).apply { marginStart = dp(10) },
        )
        shutter = View(this).apply {
            contentDescription = "Take photo"
            background = LayerDrawable(arrayOf(
                GradientDrawable().apply { shape = GradientDrawable.OVAL; setColor(Color.WHITE) },
                GradientDrawable().apply { shape = GradientDrawable.OVAL; setColor(0xFFD3D3D3.toInt()) },
            )).apply { setLayerInset(1, dp(10), dp(10), dp(10), dp(10)) }
            elevation = dp(5).toFloat()
            setOnClickListener { onShutter() }
        }
        controls.addView(shutter, FrameLayout.LayoutParams(dp(76), dp(76), Gravity.CENTER))
        controls.addView(
            roundButton(R.drawable.ic_camera_keyboard, "Enter barcode", Color.WHITE, OVERLAY, size = 48) { showManualEntry() },
            FrameLayout.LayoutParams(dp(48), dp(48), Gravity.END or Gravity.CENTER_VERTICAL).apply { marginEnd = dp(10) },
        )
        bottom.addView(controls, LinearLayout.LayoutParams(MATCH_PARENT, dp(80)))
        root.addView(bottom, FrameLayout.LayoutParams(MATCH_PARENT, WRAP_CONTENT, Gravity.BOTTOM))

        // Keep controls clear of the cutout and navigation bar.
        ViewCompat.setOnApplyWindowInsetsListener(root) { _, insets ->
            val safe = insets.getInsets(WindowInsetsCompat.Type.systemBars() or WindowInsetsCompat.Type.displayCutout())
            buttons.setPadding(dp(20), safe.top + dp(15), dp(20), 0)
            bottom.setPadding(dp(20), 0, dp(20), safe.bottom + dp(20))
            insets
        }
        return root
    }

    private fun guideDrawable(color: Int) = LayerDrawable(arrayOf(
        // A soft outer stroke stands in for iOS's glow.
        GradientDrawable().apply {
            cornerRadius = dp(14).toFloat()
            setStroke(dp(6), withAlpha(color, 0.25f))
        },
        GradientDrawable().apply {
            cornerRadius = dp(12).toFloat()
            setStroke(dp(3), color)
        },
    )).apply { setLayerInset(1, dp(2), dp(2), dp(2), dp(2)) }

    private fun roundButton(
        icon: Int,
        description: String,
        tint: Int,
        fill: Int = PANEL,
        size: Int = 44,
        onClick: () -> Unit,
    ) = ImageButton(this).apply {
        setImageResource(icon)
        imageTintList = ColorStateList.valueOf(tint)
        contentDescription = description
        background = GradientDrawable().apply {
            shape = GradientDrawable.OVAL
            setColor(fill)
            if (fill == PANEL) setStroke(dp(1), withAlpha(GOLD, 0.2f))
        }
        elevation = dp(4).toFloat()
        layoutParams = LinearLayout.LayoutParams(dp(size), dp(size))
        setOnClickListener { onClick() }
    }

    private fun rounded(color: Int, radiusDp: Int) = GradientDrawable().apply {
        cornerRadius = dp(radiusDp).toFloat()
        setColor(color)
    }

    private fun withAlpha(color: Int, alpha: Float) = (color and 0x00FFFFFF) or ((alpha * 255).toInt() shl 24)

    private fun haptic() {
        window.decorView.performHapticFeedback(HapticFeedbackConstants.KEYBOARD_TAP)
    }

    private fun dp(value: Int) = TypedValue.applyDimension(
        TypedValue.COMPLEX_UNIT_DIP, value.toFloat(), resources.displayMetrics,
    ).toInt()

    // endregion
}
