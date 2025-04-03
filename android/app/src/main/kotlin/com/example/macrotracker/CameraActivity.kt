package com.example.macrotracker

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import android.widget.Button
import androidx.appcompat.app.AppCompatActivity
import java.nio.charset.StandardCharsets

class CameraActivity : AppCompatActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // We'll set a simple layout programmatically for now
        // In a real app, you'd inflate an XML layout (e.g., setContentView(R.layout.activity_camera))

        val layout = android.widget.LinearLayout(this).apply {
            orientation = android.widget.LinearLayout.VERTICAL
            gravity = android.view.Gravity.CENTER
            setPadding(50, 50, 50, 50)
        }

        val barcodeButton = Button(this).apply {
            text = "Simulate Barcode Scan"
            setOnClickListener {
                sendResult("barcode", "123456789012") // Example barcode
            }
        }

        val photoButton = Button(this).apply {
            text = "Simulate Photo Capture"
            setOnClickListener {
                // Simulate sending back some dummy byte data for a photo
                val dummyPhotoData = "Fake photo data".toByteArray(StandardCharsets.UTF_8)
                sendResult("photo", dummyPhotoData)
            }
        }

        val cancelButton = Button(this).apply {
            text = "Cancel"
            setOnClickListener {
                sendCancelResult()
            }
        }

        layout.addView(barcodeButton)
        layout.addView(photoButton)
        layout.addView(cancelButton)

        setContentView(layout)

        println("[Native CameraActivity] CameraActivity created.")
    }

    private fun sendResult(type: String, value: Any?) {
        println("[Native CameraActivity] Sending result: type=$type")
        val resultIntent = Intent()
        resultIntent.putExtra("type", type)
        if (value is String) {
            resultIntent.putExtra("value", value)
        } else if (value is ByteArray) {
            resultIntent.putExtra("value", value)
        }
        setResult(Activity.RESULT_OK, resultIntent)
        finish() // Close this activity
    }

     private fun sendCancelResult() {
        println("[Native CameraActivity] Sending cancel result")
        setResult(Activity.RESULT_CANCELED)
        finish() // Close this activity
    }

    // Handle back press to also send cancel
    override fun onBackPressed() {
        sendCancelResult()
        super.onBackPressed() // Although finish() is called, it's good practice
    }
}
