package com.app.websight.platform

import android.Manifest
import android.annotation.SuppressLint
import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Bundle
import android.util.Log
import androidx.activity.result.contract.ActivityResultContracts
import androidx.appcompat.app.AppCompatActivity
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.ImageProxy
import androidx.camera.core.Preview
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.core.content.ContextCompat
import com.app.websight.R
import com.google.mlkit.vision.barcode.BarcodeScanner
import com.google.mlkit.vision.barcode.BarcodeScannerOptions
import com.google.mlkit.vision.barcode.BarcodeScanning
import com.google.mlkit.vision.barcode.common.Barcode
import com.google.mlkit.vision.common.InputImage
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean

class ScannerActivity : AppCompatActivity() {

    companion object {
        private const val TAG = "ScannerActivity"
    }

    private val cameraExecutor = Executors.newSingleThreadExecutor()
    private val scanner: BarcodeScanner by lazy {
        BarcodeScanning.getClient(
            BarcodeScannerOptions.Builder()
                .setBarcodeFormats(Barcode.FORMAT_ALL_FORMATS)
                .build()
        )
    }

    /** Latched once a barcode is delivered so duplicate frames cannot
     *  fire the listener twice or call finish() multiple times. */
    private val finished = AtomicBoolean(false)
    private var cameraProvider: ProcessCameraProvider? = null

    private val requestCameraPermission =
        registerForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
            if (granted) {
                bindCamera()
            } else {
                cancelAndFinish("E_PERMISSION", "Camera permission denied")
            }
        }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_scanner)
        when {
            ContextCompat.checkSelfPermission(this, Manifest.permission.CAMERA)
                == PackageManager.PERMISSION_GRANTED -> bindCamera()
            else -> requestCameraPermission.launch(Manifest.permission.CAMERA)
        }
    }

    private fun bindCamera() {
        val future = ProcessCameraProvider.getInstance(this)
        future.addListener({
            try {
                val provider = future.get()
                cameraProvider = provider
                val preview = Preview.Builder().build().also {
                    it.setSurfaceProvider(
                        findViewById<androidx.camera.view.PreviewView>(R.id.previewView)
                            .surfaceProvider
                    )
                }
                val analyzer = ImageAnalysis.Builder()
                    .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                    .build()
                    .also {
                        it.setAnalyzer(cameraExecutor, BarcodeAnalyzer(scanner) { barcode ->
                            // Only the first detected barcode wins; all later
                            // calls become no-ops thanks to AtomicBoolean.
                            if (finished.compareAndSet(false, true)) {
                                runOnUiThread {
                                    val intent = Intent().putExtra("barcode", barcode)
                                    setResult(Activity.RESULT_OK, intent)
                                    finish()
                                }
                            }
                        })
                    }
                provider.unbindAll()
                provider.bindToLifecycle(
                    this, CameraSelector.DEFAULT_BACK_CAMERA, preview, analyzer,
                )
            } catch (e: Exception) {
                Log.e(TAG, "Camera bind failed", e)
                cancelAndFinish("E_INTERNAL", "Camera bind failed: ${e.message}")
            }
        }, ContextCompat.getMainExecutor(this))
    }

    private fun cancelAndFinish(code: String, message: String) {
        if (finished.compareAndSet(false, true)) {
            val intent = Intent()
                .putExtra("error_code", code)
                .putExtra("error_message", message)
            setResult(Activity.RESULT_CANCELED, intent)
            finish()
        }
    }

    override fun onPause() {
        super.onPause()
        // Free the camera as soon as we leave the foreground (e.g. permission
        // dialog, system overlay) so other apps can use it; rebind on resume.
        cameraProvider?.unbindAll()
    }

    override fun onResume() {
        super.onResume()
        if (!finished.get() &&
            ContextCompat.checkSelfPermission(this, Manifest.permission.CAMERA)
            == PackageManager.PERMISSION_GRANTED
        ) {
            bindCamera()
        }
    }

    override fun onBackPressed() {
        // Explicit cancel so the Dart pendingBarcodeResult resolves with
        // E_CANCELED instead of leaking forever.
        cancelAndFinish("E_CANCELED", "Scan canceled")
        super.onBackPressed()
    }

    override fun onDestroy() {
        super.onDestroy()
        cameraProvider?.unbindAll()
        cameraProvider = null
        // Drain in-flight analysis tasks before we tear the executor down so
        // shutdownNow doesn't strand a frame mid-decode.
        cameraExecutor.shutdown()
        try {
            if (!cameraExecutor.awaitTermination(500, TimeUnit.MILLISECONDS)) {
                cameraExecutor.shutdownNow()
            }
        } catch (_: InterruptedException) {
            cameraExecutor.shutdownNow()
            Thread.currentThread().interrupt()
        }
        scanner.close()
    }
}

private class BarcodeAnalyzer(
    private val scanner: BarcodeScanner,
    private val onBarcode: (String) -> Unit,
) : ImageAnalysis.Analyzer {

    @SuppressLint("UnsafeOptInUsageError")
    override fun analyze(imageProxy: ImageProxy) {
        val media = imageProxy.image
        if (media == null) {
            imageProxy.close()
            return
        }
        val image = InputImage.fromMediaImage(media, imageProxy.imageInfo.rotationDegrees)
        scanner.process(image)
            .addOnSuccessListener { barcodes ->
                // First non-empty value wins — onBarcode is one-shot anyway.
                val match = barcodes.asSequence()
                    .mapNotNull { it.rawValue }
                    .firstOrNull { it.isNotEmpty() }
                if (match != null) onBarcode(match)
            }
            .addOnFailureListener { e ->
                Log.w("BarcodeAnalyzer", "scan failed", e)
            }
            .addOnCompleteListener { imageProxy.close() }
    }
}
