package com.app.websight.platform

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.webkit.ValueCallback
import android.webkit.WebChromeClient
import io.flutter.plugin.common.MethodChannel

class WebBridge(private val activity: Activity, private val channel: MethodChannel) {

    private var filePathCallback: ValueCallback<Array<Uri>>? = null

    fun onShowFileChooser(
        filePathCallback: ValueCallback<Array<Uri>>?,
        fileChooserParams: WebChromeClient.FileChooserParams
    ): Boolean {
        this.filePathCallback = filePathCallback
        val intent = fileChooserParams.createIntent()
        try {
            activity.startActivityForResult(intent, FILE_CHOOSER_REQUEST_CODE)
        } catch (e: Exception) {
            this.filePathCallback = null
            return false
        }
        return true
    }

    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode == FILE_CHOOSER_REQUEST_CODE) {
            if (resultCode == Activity.RESULT_OK) {
                if (data != null) {
                    filePathCallback?.onReceiveValue(WebChromeClient.FileChooserParams.parseResult(resultCode, data))
                }
            } else {
                filePathCallback?.onReceiveValue(null)
            }
            filePathCallback = null
        }
    }

    companion object {
        const val FILE_CHOOSER_REQUEST_CODE = 101
    }
}
