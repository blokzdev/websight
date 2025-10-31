package com.example.websight.platform

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.webkit.ValueCallback
import android.webkit.WebChromeClient
import android.webkit.WebView

class WebSightChromeClient(private val activity: Activity, private val fileUploadCallback: (ValueCallback<Array<Uri>>?) -> Unit) : WebChromeClient() {

    override fun onShowFileChooser(
        webView: WebView?,
        filePathCallback: ValueCallback<Array<Uri>>?,
        fileChooserParams: FileChooserParams?
    ): Boolean {
        fileUploadCallback(filePathCallback)
        val intent = fileChooserParams?.createIntent()
        try {
            activity.startActivityForResult(intent, FILE_CHOOSER_REQUEST_CODE)
        } catch (e: Exception) {
            return false
        }
        return true
    }

    companion object {
        const val FILE_CHOOSER_REQUEST_CODE = 1001
    }
}
