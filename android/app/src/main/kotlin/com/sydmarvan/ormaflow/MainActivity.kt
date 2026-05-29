package com.sydmarvan.ormaflow

import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        // Must be called BEFORE super.onCreate so the window flags are set
        // before Flutter attaches its surface.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            // Android 10+ enforces a semi-transparent scrim over the gesture
            // bar area regardless of theme XML settings. Disable it here so
            // the app's own #1B1B1B background shows through cleanly.
            window.isNavigationBarContrastEnforced = false
        }
        super.onCreate(savedInstanceState)
    }
}
