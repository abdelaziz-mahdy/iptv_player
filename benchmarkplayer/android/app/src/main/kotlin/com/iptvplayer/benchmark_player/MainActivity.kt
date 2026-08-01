package com.iptvplayer.benchmark_player

import android.opengl.EGL14
import android.os.Bundle
import android.system.Os
import android.util.Log
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        // fvp#374: MDK defaults to a 10-bit (RGBA_1010102) EGLConfig; the
        // PowerVR driver on this TV corrupts 10-bit buffers shared across EGL
        // contexts. Must be set before libmdk loads. Inert for media_kit.
        Os.setenv("EGL_SDR_DEPTH", "8", true)
        // fvp PR #379 experiments: `am start --ez direct_surface true` makes
        // the fvp fork attach the platform-view surface to MediaCodec itself
        // (decoder -> SurfaceFlinger, no GL); `--es direct_mode tunnel` tries
        // true tunneled playback (tunnel=1 + ANativeWindow). Env var read in
        // fvp_plugin.cpp.
        // One build, many clips: `am start --es bench_url <url>` overrides the
        // BENCH_URL dart-define, so a clip sweep needs no rebuild per file.
        intent?.getStringExtra("bench_url")?.let {
            Os.setenv("BENCH_URL_OVERRIDE", it, true)
            Log.i("BENCH", "BENCH_URL_OVERRIDE=$it")
        }
        val directMode = intent?.getStringExtra("direct_mode")
            ?: if (intent?.getBooleanExtra("direct_surface", false) == true) "1" else null
        if (directMode != null) {
            Os.setenv("FVP_DIRECT_SURFACE", directMode, true)
            Log.i("BENCH", "FVP_DIRECT_SURFACE=$directMode (MediaCodec renders to surface)")
        }
        eglConfigProbe()
        super.onCreate(savedInstanceState)
        // Unattended runs: without this the Google TV ambient screensaver
        // takes over mid-measurement (the activity loses its surface, the
        // platform view dies, and pacing data silently measures the
        // screensaver). The IPTV app holds a wakelock; the bench must too.
        window.addFlags(android.view.WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
    }

    /**
     * fvp#374 follow-up experiment requested by the mdk maintainer: does this
     * driver mark its RGBA_1010102 configs as slow/non-conformant? If so,
     * libmdk can pin EGL_CONFIG_CAVEAT=EGL_NONE and auto-avoid the broken
     * 10-bit path with no probe. Dumps every config plus the result of the
     * caveat-filtered eglChooseConfig. One-shot, log-only.
     */
    private fun eglConfigProbe() {
        val tag = "EGL_PROBE"
        try {
            val disp = EGL14.eglGetDisplay(EGL14.EGL_DEFAULT_DISPLAY)
            if (disp == EGL14.EGL_NO_DISPLAY) {
                Log.i(tag, "no default display")
                return
            }
            val ver = IntArray(2)
            if (!EGL14.eglInitialize(disp, ver, 0, ver, 1)) {
                Log.i(tag, "eglInitialize failed err=0x${Integer.toHexString(EGL14.eglGetError())}")
                return
            }
            Log.i(tag, "EGL ${ver[0]}.${ver[1]} vendor=${EGL14.eglQueryString(disp, EGL14.EGL_VENDOR)} version=${EGL14.eglQueryString(disp, EGL14.EGL_VERSION)}")

            // -- 1. full config table --
            val num = IntArray(1)
            EGL14.eglGetConfigs(disp, null, 0, 0, num, 0)
            val cfgs = arrayOfNulls<android.opengl.EGLConfig>(num[0])
            EGL14.eglGetConfigs(disp, cfgs, 0, cfgs.size, num, 0)
            Log.i(tag, "driver exposes ${num[0]} configs; 10-bit and 8888 window configs:")
            val v = IntArray(1)
            fun attr(c: android.opengl.EGLConfig, a: Int): Int {
                return if (EGL14.eglGetConfigAttrib(disp, c, a, v, 0)) v[0] else -1
            }
            for (i in 0 until num[0]) {
                val c = cfgs[i] ?: continue
                val r = attr(c, EGL14.EGL_RED_SIZE)
                val g = attr(c, EGL14.EGL_GREEN_SIZE)
                val b = attr(c, EGL14.EGL_BLUE_SIZE)
                val a = attr(c, EGL14.EGL_ALPHA_SIZE)
                val surf = attr(c, EGL14.EGL_SURFACE_TYPE)
                val isWindow = surf and EGL14.EGL_WINDOW_BIT != 0
                val is1010102 = r == 10 && g == 10 && b == 10 && a == 2
                val is8888 = r == 8 && g == 8 && b == 8 && a == 8
                if (!isWindow || (!is1010102 && !is8888)) continue
                val caveat = when (attr(c, EGL14.EGL_CONFIG_CAVEAT)) {
                    EGL14.EGL_NONE -> "NONE"
                    EGL14.EGL_SLOW_CONFIG -> "SLOW_CONFIG"
                    EGL14.EGL_NON_CONFORMANT_CONFIG -> "NON_CONFORMANT"
                    else -> "0x${Integer.toHexString(v[0])}"
                }
                Log.i(tag, "config id=${attr(c, EGL14.EGL_CONFIG_ID)} " +
                        "rgba=$r$g$b$a caveat=$caveat " +
                        "conformant=0x${Integer.toHexString(attr(c, EGL14.EGL_CONFORMANT))} " +
                        "renderable=0x${Integer.toHexString(attr(c, EGL14.EGL_RENDERABLE_TYPE))} " +
                        "surfaceType=0x${Integer.toHexString(surf)} " +
                        "native=0x${Integer.toHexString(attr(c, EGL14.EGL_NATIVE_VISUAL_ID))}")
            }

            // -- 2. wang-bin's exact query: 10-bit window config, caveat pinned to NONE --
            val es3Bit = 0x40 // EGL_OPENGL_ES3_BIT (EGLExt.EGL_OPENGL_ES3_BIT_KHR)
            val attribs = intArrayOf(
                EGL14.EGL_CONFIG_CAVEAT, EGL14.EGL_NONE,
                EGL14.EGL_BUFFER_SIZE, 32,
                EGL14.EGL_RED_SIZE, 10,
                EGL14.EGL_GREEN_SIZE, 10,
                EGL14.EGL_BLUE_SIZE, 10,
                EGL14.EGL_ALPHA_SIZE, 2,
                EGL14.EGL_RENDERABLE_TYPE, EGL14.EGL_OPENGL_ES2_BIT or es3Bit,
                EGL14.EGL_SURFACE_TYPE, EGL14.EGL_WINDOW_BIT,
                EGL14.EGL_NONE
            )
            while (EGL14.eglGetError() != EGL14.EGL_SUCCESS) { /* drain */ }
            val n = IntArray(1)
            val out = arrayOfNulls<android.opengl.EGLConfig>(16)
            val ok = EGL14.eglChooseConfig(disp, attribs, 0, out, 0, out.size, n, 0)
            val err = EGL14.eglGetError()
            Log.i(tag, "eglChooseConfig(1010102, CAVEAT=NONE): ret=$ok matches=${n[0]} err=0x${Integer.toHexString(err)}")
            for (i in 0 until n[0]) {
                val c = out[i] ?: continue
                Log.i(tag, "  match[$i] id=${attr(c, EGL14.EGL_CONFIG_ID)} rgba=${attr(c, EGL14.EGL_RED_SIZE)}${attr(c, EGL14.EGL_GREEN_SIZE)}${attr(c, EGL14.EGL_BLUE_SIZE)}${attr(c, EGL14.EGL_ALPHA_SIZE)}")
            }

            // -- 3. same but also requiring ES2|ES3 conformance --
            val attribs2 = intArrayOf(
                EGL14.EGL_CONFIG_CAVEAT, EGL14.EGL_NONE,
                EGL14.EGL_CONFORMANT, EGL14.EGL_OPENGL_ES2_BIT or es3Bit,
                EGL14.EGL_BUFFER_SIZE, 32,
                EGL14.EGL_RED_SIZE, 10,
                EGL14.EGL_GREEN_SIZE, 10,
                EGL14.EGL_BLUE_SIZE, 10,
                EGL14.EGL_ALPHA_SIZE, 2,
                EGL14.EGL_RENDERABLE_TYPE, EGL14.EGL_OPENGL_ES2_BIT or es3Bit,
                EGL14.EGL_SURFACE_TYPE, EGL14.EGL_WINDOW_BIT,
                EGL14.EGL_NONE
            )
            val ok2 = EGL14.eglChooseConfig(disp, attribs2, 0, out, 0, out.size, n, 0)
            Log.i(tag, "eglChooseConfig(+CONFORMANT=ES2|ES3): ret=$ok2 matches=${n[0]} err=0x${Integer.toHexString(EGL14.eglGetError())}")
        } catch (t: Throwable) {
            Log.i(tag, "probe crashed: $t")
        }
    }
}
