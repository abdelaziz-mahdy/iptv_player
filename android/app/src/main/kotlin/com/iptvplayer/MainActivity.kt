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
        // fvp platform view: MediaCodec renders decoded frames straight into
        // the SurfaceView (no GL renderer, no EGL) — the only path that plays
        // 4K on this TV (24.01fps at 4K24, 56fps at 4K60 vs ~22fps through
        // GL; benchmarked 2026-07-19, fvp#379). The pinned fvp fork makes the
        // final per-video call: HDR/10-bit content goes back to the GL path,
        // because non-tunneled HDR output wedges the Realtek decoder.
        // Inert for media_kit and for the texture path.
        Os.setenv("FVP_DIRECT_SURFACE", "1", true)
        super.onCreate(savedInstanceState)
    }
}
