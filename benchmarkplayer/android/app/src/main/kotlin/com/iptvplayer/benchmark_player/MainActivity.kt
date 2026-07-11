package com.iptvplayer.benchmark_player

import android.os.Bundle
import android.system.Os
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        // fvp#374: MDK defaults to a 10-bit (RGBA_1010102) EGLConfig; the
        // PowerVR driver on this TV corrupts 10-bit buffers shared across EGL
        // contexts. Must be set before libmdk loads. Inert for media_kit.
        Os.setenv("EGL_SDR_DEPTH", "8", true)
        super.onCreate(savedInstanceState)
    }
}
