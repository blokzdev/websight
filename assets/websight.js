class WebSightBridgeInternal {
    constructor(channelName) {
        this.channelName = channelName;
        this.callbacks = {};
        this.errorCallbacks = {};
    }

    _postMessage(method, params = {}) {
        const message = { method, params };
        // In Dart, we receive this via the `addJavaScriptChannel` handler
        window.WebSightBridge.postMessage(JSON.stringify(message));
    }

    // --- Public API Methods ---

    scanBarcode() {
        return new Promise((resolve, reject) => {
            const callbackId = this._generateCallbackId('scanBarcode');
            this.callbacks[callbackId] = resolve;
            this.errorCallbacks[callbackId] = reject;
            this._postMessage('scanBarcode', { callbackId });
        });
    }

    share(text) {
        this._postMessage('share', { text });
    }

    getDeviceInfo() {
        return new Promise((resolve, reject) => {
            const callbackId = this._generateCallbackId('getDeviceInfo');
            this.callbacks[callbackId] = resolve;
            this.errorCallbacks[callbackId] = reject;
            this._postMessage('getDeviceInfo', { callbackId });
        });
    }

    async downloadBlob(blobUrl, filename, mimeType) {
        try {
            const response = await fetch(blobUrl);
            const blob = await response.blob();
            const reader = new FileReader();
            reader.readAsDataURL(blob);
            reader.onloadend = () => {
                // The result includes the Base64 prefix `data:mime/type;base64,`
                // We send the whole string to the native side for parsing.
                const base64data = reader.result;
                this._postMessage('downloadBlob', { 
                    base64data: base64data,
                    filename: filename || 'download',
                    mimeType: mimeType || blob.type
                });
            };
        } catch (e) {
            console.error('WebSightBridge Error: Failed to process blob.', e);
        }
    }

    openExternal(url) {
        this._postMessage('openExternal', { url });
    }

    // --- Internal Callback Handling ---

    resolveCallback(callbackId, result) {
        if (this.callbacks[callbackId]) {
            this.callbacks[callbackId](result);
            this._cleanupCallbacks(callbackId);
        }
    }

    rejectCallback(callbackId, error) {
        if (this.errorCallbacks[callbackId]) {
            this.errorCallbacks[callbackId](error);
            this._cleanupCallbacks(callbackId);
        }
    }

    _generateCallbackId(prefix) {
        return `${prefix}_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
    }

    _cleanupCallbacks(callbackId) {
        delete this.callbacks[callbackId];
        delete this.errorCallbacks[callbackId];
    }
}
