/*
 * WebSight bridge helper script.
 *
 * This file is injected into the WebView on every page load (when bridge is
 * enabled and the current origin is in security.restrict_to_hosts). It exposes
 * a Promise-based API for native features.
 *
 * Naming: the global is window.<jsBridge.name> (default: WebSightBridge). It
 * is constructed at the bottom of webview_controller's inject() step:
 *   window.WebSightBridge = new WebSightBridgeInternal('WebSightBridge');
 *
 * Public API:
 *   await WebSightBridge.scanBarcode()                       -> string
 *   await WebSightBridge.share(text)                         -> true
 *   await WebSightBridge.getDeviceInfo()                     -> object
 *   await WebSightBridge.downloadBlob(blobUrl, filename?, mimeType?) -> uri string
 *   await WebSightBridge.openExternal(url)                   -> true
 *
 * Inbound (native -> JS) events the host may dispatch on `window`:
 *   onPush         CustomEvent({ detail: { title, body, data } })
 *
 * Errors reject with { code, message } where code matches BridgeErrorCodes:
 *   E_PERMISSION, E_CANCELED, E_ARGS, E_INTERNAL, E_ORIGIN, E_UNSUPPORTED.
 */
class WebSightBridgeInternal {
    constructor(channelName) {
        this.channelName = channelName;
        this.callbacks = {};
        this.errorCallbacks = {};
        this._seq = 0;
    }

    _postMessage(method, params) {
        const safeParams = params || {};
        const message = JSON.stringify({ method, params: safeParams });
        // The Dart side registers a JavaScript channel under `channelName`.
        const channel = window[this.channelName];
        if (!channel || typeof channel.postMessage !== 'function') {
            console.warn('WebSightBridge: channel not available; message dropped:', message);
            return;
        }
        channel.postMessage(message);
    }

    _withCallback(method, params) {
        return new Promise((resolve, reject) => {
            const callbackId = this._generateCallbackId(method);
            this.callbacks[callbackId] = resolve;
            this.errorCallbacks[callbackId] = reject;
            this._postMessage(method, Object.assign({}, params || {}, { callbackId }));
        });
    }

    // --- Public API ---

    scanBarcode() {
        return this._withCallback('scanBarcode');
    }

    share(text) {
        return this._withCallback('share', { text: String(text || '') });
    }

    getDeviceInfo() {
        return this._withCallback('getDeviceInfo');
    }

    /**
     * Reads a blob: or http(s): URL via fetch, base64-encodes it, and forwards
     * to the native side which writes to MediaStore.Downloads (API 29+) or to
     * the legacy Downloads directory.
     */
    async downloadBlob(blobUrl, filename, mimeType) {
        try {
            const response = await fetch(blobUrl);
            if (!response.ok) {
                throw new Error('HTTP ' + response.status);
            }
            const blob = await response.blob();
            const base64data = await this._blobToBase64(blob);
            return this._withCallback('downloadBlob', {
                base64data,
                filename: filename || 'download',
                mimeType: mimeType || blob.type || 'application/octet-stream',
            });
        } catch (e) {
            return Promise.reject({ code: 'E_INTERNAL', message: 'Failed to fetch blob: ' + (e && e.message || e) });
        }
    }

    openExternal(url) {
        return this._withCallback('openExternal', { url: String(url || '') });
    }

    // --- Internal callback handling (called from Dart) ---

    resolveCallback(callbackId, result) {
        const cb = this.callbacks[callbackId];
        if (cb) {
            try { cb(result); } finally { this._cleanupCallbacks(callbackId); }
        }
    }

    rejectCallback(callbackId, error) {
        const cb = this.errorCallbacks[callbackId];
        if (cb) {
            try { cb(error); } finally { this._cleanupCallbacks(callbackId); }
        }
    }

    // --- Internal helpers ---

    _generateCallbackId(prefix) {
        this._seq = (this._seq + 1) >>> 0;
        return `${prefix}_${Date.now()}_${this._seq}`;
    }

    _cleanupCallbacks(callbackId) {
        delete this.callbacks[callbackId];
        delete this.errorCallbacks[callbackId];
    }

    _blobToBase64(blob) {
        return new Promise((resolve, reject) => {
            const reader = new FileReader();
            reader.onloadend = () => resolve(reader.result);
            reader.onerror = () => reject(reader.error || new Error('FileReader error'));
            reader.readAsDataURL(blob);
        });
    }
}
