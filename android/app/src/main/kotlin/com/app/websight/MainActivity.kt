package com.app.websight

import android.app.Activity
import android.app.DownloadManager
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.provider.MediaStore
import android.util.Base64
import android.util.Log
import android.webkit.MimeTypeMap
import com.app.websight.platform.ScannerActivity
import com.app.websight.platform.UmpConsent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.GeneratedPluginRegistrant
import java.io.File
import java.io.FileOutputStream
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {

    companion object {
        private const val CHANNEL = "websight/method_channel"
        private const val SCANNER_REQUEST_CODE = 2001
        private const val FILE_CHOOSER_REQUEST_CODE = 2002
        private const val TAG = "WebSightMainActivity"
        // Refuses blobs decoded larger than this. Web pages can request
        // arbitrarily-large blobs; 50 MiB is generous for the kinds of
        // documents a typical WebView app would hand off.
        private const val MAX_BLOB_BYTES = 50L * 1024 * 1024
    }

    private lateinit var umpConsent: UmpConsent
    private var pendingBarcodeResult: MethodChannel.Result? = null
    private var pendingFilePickResult: MethodChannel.Result? = null

    /** Dedicated worker for blob/disk IO so we never block the UI thread. */
    private lateinit var ioExecutor: ExecutorService

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        GeneratedPluginRegistrant.registerWith(flutterEngine)
        umpConsent = UmpConsent(this)
        ioExecutor = Executors.newSingleThreadExecutor()

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result -> handleMethodCall(call.method, call.arguments, result) }
    }

    override fun onDestroy() {
        super.onDestroy()
        if (::ioExecutor.isInitialized) {
            ioExecutor.shutdown()
        }
    }

    private fun handleMethodCall(method: String, args: Any?, result: MethodChannel.Result) {
        when (method) {
            "gatherConsent" -> umpConsent.gatherConsent { ok, err ->
                if (ok) result.success(null) else result.error("E_CONSENT", err, null)
            }

            "scanBarcode" -> startBarcodeScan(result)

            "downloadBlob" -> {
                @Suppress("UNCHECKED_CAST") val params = args as? Map<String, Any?>
                if (params == null) {
                    result.error("E_ARGS", "Expected map { base64data, filename, mimeType }", null)
                    return
                }
                downloadBlob(
                    base64data = params["base64data"] as? String,
                    filename = params["filename"] as? String,
                    mimeType = params["mimeType"] as? String,
                    result = result,
                )
            }

            "registerHttpDownload" -> {
                @Suppress("UNCHECKED_CAST") val params = args as? Map<String, Any?>
                if (params == null) {
                    result.error("E_ARGS", "Expected map { url, userAgent, contentDisposition, mimeType }", null)
                    return
                }
                registerHttpDownload(
                    url = params["url"] as? String,
                    userAgent = params["userAgent"] as? String,
                    contentDisposition = params["contentDisposition"] as? String,
                    mimeType = params["mimeType"] as? String,
                    result = result,
                )
            }

            "pickFiles" -> {
                @Suppress("UNCHECKED_CAST") val params = args as? Map<String, Any?>
                if (params == null) {
                    result.error("E_ARGS", "Expected map { mimeTypes, allowMultiple, captureCamera }", null)
                    return
                }
                pickFiles(
                    mimeTypes = (params["mimeTypes"] as? List<*>)
                        ?.filterIsInstance<String>() ?: listOf("*/*"),
                    allowMultiple = (params["allowMultiple"] as? Boolean) ?: false,
                    captureCamera = (params["captureCamera"] as? Boolean) ?: false,
                    result = result,
                )
            }

            else -> result.notImplemented()
        }
    }

    // --- Barcode scanning ---

    private fun startBarcodeScan(result: MethodChannel.Result) {
        if (pendingBarcodeResult != null) {
            result.error("E_BUSY", "A scan is already in progress", null)
            return
        }
        pendingBarcodeResult = result
        startActivityForResult(Intent(this, ScannerActivity::class.java), SCANNER_REQUEST_CODE)
    }

    // --- File uploads ---
    //
    // Driven from Dart's WebsightWebViewController._onShowFileSelector. The
    // Dart side hands us an allow-list of MIME types, whether multi-select is
    // permitted, and whether camera capture should be offered alongside the
    // file picker. We launch the system chooser, await the result, and send
    // back a List<String> of content URIs — webview_flutter_android hands
    // those URIs to the underlying WebView which the page then receives.

    private fun pickFiles(
        mimeTypes: List<String>,
        allowMultiple: Boolean,
        captureCamera: Boolean,
        result: MethodChannel.Result,
    ) {
        if (pendingFilePickResult != null) {
            // A previous picker is still open. Reject the new request rather
            // than stomping on the in-flight callback.
            result.error("E_BUSY", "A file picker is already open", null)
            return
        }
        pendingFilePickResult = result

        val contentIntent = Intent(Intent.ACTION_GET_CONTENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            putExtra(Intent.EXTRA_ALLOW_MULTIPLE, allowMultiple)
            type = if (mimeTypes.size == 1) mimeTypes.first() else "*/*"
            if (mimeTypes.size > 1) {
                putExtra(Intent.EXTRA_MIME_TYPES, mimeTypes.toTypedArray())
            }
        }

        // Optionally let the user capture a new photo/video instead of picking.
        val extraInitialIntents = if (captureCamera) {
            buildList<Intent> {
                if (mimeTypes.any { it.startsWith("image/") || it == "*/*" }) {
                    add(Intent(MediaStore.ACTION_IMAGE_CAPTURE))
                }
                if (mimeTypes.any { it.startsWith("video/") || it == "*/*" }) {
                    add(Intent(MediaStore.ACTION_VIDEO_CAPTURE))
                }
            }.toTypedArray()
        } else {
            emptyArray()
        }

        val chooser = Intent.createChooser(contentIntent, "Select file").apply {
            if (extraInitialIntents.isNotEmpty()) {
                putExtra(Intent.EXTRA_INITIAL_INTENTS, extraInitialIntents)
            }
        }

        try {
            startActivityForResult(chooser, FILE_CHOOSER_REQUEST_CODE)
        } catch (e: Exception) {
            pendingFilePickResult = null
            result.error("E_INTERNAL", "Failed to launch file chooser: ${e.message}", null)
        }
    }

    @Deprecated("Deprecated in superclass; routed via startActivityForResult")
    @Suppress("DEPRECATION")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        when (requestCode) {
            SCANNER_REQUEST_CODE -> {
                val r = pendingBarcodeResult
                pendingBarcodeResult = null
                if (r == null) return
                if (resultCode == Activity.RESULT_OK) {
                    r.success(data?.getStringExtra("barcode") ?: "")
                } else {
                    r.error("E_CANCELED", "Scan canceled", null)
                }
            }
            FILE_CHOOSER_REQUEST_CODE -> {
                val r = pendingFilePickResult
                pendingFilePickResult = null
                if (r == null) return
                if (resultCode != Activity.RESULT_OK) {
                    r.success(emptyList<String>())
                    return
                }
                r.success(extractUris(data))
            }
        }
    }

    /**
     * Extracts content URIs from the chooser result. Handles single-select
     * (`data.data`), multi-select (`data.clipData`), and the camera-capture
     * fallback where the camera intent returned no [Intent] but stored the
     * image at the `MediaStore.EXTRA_OUTPUT` URI.
     */
    private fun extractUris(data: Intent?): List<String> {
        if (data == null) return emptyList()
        val uris = mutableListOf<Uri>()
        val clip = data.clipData
        if (clip != null) {
            for (i in 0 until clip.itemCount) {
                clip.getItemAt(i).uri?.let { uris.add(it) }
            }
        } else {
            data.data?.let { uris.add(it) }
        }
        return uris.map { it.toString() }
    }

    // --- Blob downloads ---
    //
    // Blob URLs (`blob:https://...`) cannot be intercepted by Android's DownloadManager.
    // The JS bridge fetches the blob, base64-encodes it, and forwards it here. We decode
    // and write to public Downloads via MediaStore (API 29+) or to legacy storage path.

    private fun downloadBlob(
        base64data: String?,
        filename: String?,
        mimeType: String?,
        result: MethodChannel.Result,
    ) {
        if (base64data.isNullOrEmpty() || filename.isNullOrEmpty()) {
            result.error("E_ARGS", "base64data and filename are required", null)
            return
        }
        // Bound the work to a worker thread; Base64.decode + MediaStore
        // insert + file write all hit disk and easily span tens of MB.
        ioExecutor.execute {
            try {
                val payload = base64data.substringAfter(",", base64data)
                // Cheap upper bound on decoded size from the encoded length;
                // refuse early instead of letting Base64.decode allocate.
                if (payload.length.toLong() > MAX_BLOB_BYTES * 4 / 3 + 16) {
                    runOnUiThread {
                        result.error(
                            "E_INTERNAL",
                            "Blob exceeds ${MAX_BLOB_BYTES / (1024 * 1024)} MB cap",
                            null,
                        )
                    }
                    return@execute
                }
                val bytes = Base64.decode(payload, Base64.DEFAULT)
                if (bytes.size.toLong() > MAX_BLOB_BYTES) {
                    runOnUiThread {
                        result.error(
                            "E_INTERNAL",
                            "Blob exceeds ${MAX_BLOB_BYTES / (1024 * 1024)} MB cap",
                            null,
                        )
                    }
                    return@execute
                }
                val resolvedMime = mimeType?.takeIf { it.isNotBlank() }
                    ?: MimeTypeMap.getSingleton()
                        .getMimeTypeFromExtension(filename.substringAfterLast('.', ""))
                    ?: "application/octet-stream"

                val savedUri = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    writeViaMediaStore(filename, resolvedMime, bytes)
                } else {
                    writeToLegacyDownloads(filename, resolvedMime, bytes)
                }
                runOnUiThread { result.success(savedUri) }
            } catch (e: Exception) {
                Log.e(TAG, "downloadBlob failed", e)
                runOnUiThread {
                    result.error("E_INTERNAL", e.message ?: "downloadBlob failed", null)
                }
            }
        }
    }

    private fun writeViaMediaStore(filename: String, mime: String, bytes: ByteArray): String {
        val resolver = contentResolver
        val values = ContentValues().apply {
            put(MediaStore.Downloads.DISPLAY_NAME, filename)
            put(MediaStore.Downloads.MIME_TYPE, mime)
            put(MediaStore.Downloads.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS)
            put(MediaStore.Downloads.IS_PENDING, 1)
        }
        val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
            ?: throw IllegalStateException("MediaStore returned null URI")
        try {
            resolver.openOutputStream(uri)?.use { it.write(bytes) }
                ?: throw IllegalStateException("Could not open output stream for $uri")
            val cleared = ContentValues().apply { put(MediaStore.Downloads.IS_PENDING, 0) }
            resolver.update(uri, cleared, null, null)
            return uri.toString()
        } catch (e: Exception) {
            // Roll back the pending row so it doesn't appear stuck in Downloads.
            resolver.delete(uri, null, null)
            throw e
        }
    }

    @Suppress("DEPRECATION")
    private fun writeToLegacyDownloads(filename: String, mime: String, bytes: ByteArray): String {
        val downloadsDir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
        if (!downloadsDir.exists()) downloadsDir.mkdirs()
        val outFile = File(downloadsDir, filename)
        FileOutputStream(outFile).use { it.write(bytes) }
        val dm = getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager
        dm.addCompletedDownload(
            filename, filename, true, mime, outFile.absolutePath, bytes.size.toLong(), true,
        )
        return outFile.toURI().toString()
    }

    // --- HTTPS downloads ---
    //
    // Triggered from the WebView's onNavigationRequest path on Dart side when a
    // download-content URL is detected. We hand off to Android's DownloadManager
    // so the user gets a system tray notification and standard Downloads/ landing.

    private fun registerHttpDownload(
        url: String?,
        userAgent: String?,
        contentDisposition: String?,
        mimeType: String?,
        result: MethodChannel.Result,
    ) {
        if (url.isNullOrEmpty()) {
            result.error("E_ARGS", "url is required", null)
            return
        }
        try {
            val uri = Uri.parse(url)
            val filename = guessFilename(url, contentDisposition, mimeType)
            val request = DownloadManager.Request(uri)
                .setTitle(filename)
                .setNotificationVisibility(DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED)
                .setAllowedOverMetered(true)
                .setAllowedOverRoaming(true)
                .setDestinationInExternalPublicDir(Environment.DIRECTORY_DOWNLOADS, filename)

            if (!userAgent.isNullOrEmpty()) request.addRequestHeader("User-Agent", userAgent)
            if (!mimeType.isNullOrEmpty()) request.setMimeType(mimeType)
            if (!contentDisposition.isNullOrEmpty()) {
                // Some servers depend on cookies for auth; CookieManager is propagated
                // automatically by the WebView, but a manual cookie header is sometimes
                // required. The integrator can extend here if needed.
            }

            val dm = getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager
            val id = dm.enqueue(request)
            result.success(mapOf("id" to id, "filename" to filename))
        } catch (e: Exception) {
            Log.e(TAG, "registerHttpDownload failed", e)
            result.error("E_INTERNAL", e.message, null)
        }
    }

    private fun guessFilename(url: String, disposition: String?, mime: String?): String {
        // Mirror DownloadManager's URLUtil.guessFileName but with safer defaults.
        val urlGuess = android.webkit.URLUtil.guessFileName(url, disposition, mime)
        return if (urlGuess.isNullOrBlank()) "download" else urlGuess
    }

    override fun onSaveInstanceState(outState: Bundle) {
        // Nothing to persist; explicit override silences static analysis.
        super.onSaveInstanceState(outState)
    }
}
