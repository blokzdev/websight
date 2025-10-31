package com.example.websight.platform

import android.app.Activity
import com.google.android.ump.ConsentInformation
import com.google.android.ump.ConsentRequestParameters
import com.google.android.ump.UserMessagingPlatform

class UmpConsent(private val activity: Activity) {

    private val consentInformation: ConsentInformation =
        UserMessagingPlatform.getConsentInformation(activity)

    fun gatherConsent(onConsentGathered: (Boolean, String?) -> Unit) {
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
                        // Consent gathering failed.
                        onConsentGathered(false, loadAndShowError.message)
                    } else {
                        // Consent has been gathered.
                        onConsentGathered(true, null)
                    }
                }
            },
            { requestConsentError ->
                // Consent info update failed.
                onConsentGathered(false, requestConsentError.message)
            }
        )
    }
}
