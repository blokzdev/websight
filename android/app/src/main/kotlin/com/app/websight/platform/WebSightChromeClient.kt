package com.app.websight.platform

import android.content.Intent
import android.net.Uri
import android.webkit.ValueCallback
import android.webkit.WebChromeClient
import android.webkit.WebView
import com.app.websight.MainActivity

/**
 * Bridges native `<input type="file">` invocations to [MainActivity.launchFileChooser].
 *
 * This class is consumed by the Android-specific webview controller from Dart
 * (see `webview_controller.dart` -> `setOnShowFileSelector` mapping). The
 * `webview_flutter_android` plugin will call [onShowFileChooser] when the
 * embedded WebView surfaces a file input.
 */
class WebSightChromeClient(private val activity: MainActivity) : WebChromeClient() {

    override fun onShowFileChooser(
        webView: WebView?,
        filePathCallback: ValueCallback<Array<Uri>>?,
        fileChooserParams: FileChooserParams?,
    ): Boolean {
        val intent: Intent = fileChooserParams?.createIntent() ?: return false
        return activity.launchFileChooser(filePathCallback, intent)
    }
}
