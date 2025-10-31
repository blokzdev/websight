package com.example.websight

import android.app.Activity
import android.app.DownloadManager
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import android.util.Base64
import android.webkit.ValueCallback
import com.example.websight.platform.ScannerActivity
import com.example.websight.platform.UmpConsent
import com.example.websight.platform.WebSightChromeClient
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.GeneratedPluginRegistrant

class MainActivity : FlutterActivity() {
    private var fileUploadCallback: ValueCallback<Array<Uri>>? = null
    private val CHANNEL = "websight/method_channel"
    private var barcodeResult: MethodChannel.Result? = null
    private lateinit var umpConsent: UmpConsent

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        GeneratedPluginRegistrant.registerWith(flutterEngine)
        umpConsent = UmpConsent(this)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "gatherConsent" -> {
                    umpConsent.gatherConsent { success, errorMessage ->
                        if (success) {
                            result.success(null)
                        } else {
                            result.error("CONSENT_ERROR", errorMessage, null)
                        }
                    }
                }
                // ... other method calls
                else -> result.notImplemented()
            }
        }
    }
    // ... rest of MainActivity
}
