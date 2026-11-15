package com.iptvplayer

import android.os.Bundle
import android.system.Os
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        // wang-bin/fvp#374 workaround: force MDK's GL renderer onto an 8-bit
        // EGLConfig. MDK defaults to a 10-bit (RGBA_1010102) window surface,
        // which this TV's PowerVR driver cannot share consistently across GL
        // contexts (IMGSRV "IsTextureConsistent" failures -> corrupted video).
        // Must run before the Flutter engine loads libfvp/libmdk, hence before
        // super.onCreate(). Remove once fvp/mdk handle this upstream.
        Os.setenv("EGL_SDR_DEPTH", "8", true)
        super.onCreate(savedInstanceState)
    }
}
