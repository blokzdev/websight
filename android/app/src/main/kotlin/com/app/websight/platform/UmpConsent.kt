package com.app.websight.platform

import android.app.Activity
import com.google.android.ump.ConsentInformation
import com.google.android.ump.ConsentRequestParameters
import com.google.android.ump.UserMessagingPlatform

class UmpConsent(private val activity: Activity) {

    private val consentInformation: ConsentInformation =
        UserMessagingPlatform.getConsentInformation(activity)

    fun gatherConsent(onConsentGathered: (Boolean, String?) -> Unit) {
        // Fast path: if the SDK already has a usable consent state (cached
        // from a previous launch), skip the network round-trip and the form
        // entirely. This is the recommended pattern from Google's UMP guide
        // and saves a second of cold-start time + a network call on every
        // launch.
        if (consentInformation.canRequestAds()) {
            onConsentGathered(true, null)
            return
        }

        // For testing purposes, you can force a geography and reset consent.
        // val debugSettings = ConsentDebugSettings.Builder(activity)
        //     .setDebugGeography(ConsentDebugSettings.DebugGeography.DEBUG_GEOGRAPHY_EEA)
        //     .addTestDeviceHashedId("YOUR_TEST_DEVICE_HASHED_ID")
        //     .build()

        val params = ConsentRequestParameters.Builder()
            // .setConsentDebugSettings(debugSettings) // Uncomment for testing
            .build()

        consentInformation.requestConsentInfoUpdate(
            activity,
            params,
            {
                UserMessagingPlatform.loadAndShowConsentFormIfRequired(activity) { loadAndShowError ->
                    if (loadAndShowError != null) {
                        onConsentGathered(false, loadAndShowError.message)
                    } else {
                        onConsentGathered(true, null)
                    }
                }
            },
            { requestConsentError ->
                onConsentGathered(false, requestConsentError.message)
            }
        )
    }
}
