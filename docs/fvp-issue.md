# [Android] Video is color-corrupted on TCL Google TV (Realtek RTD2875P / PowerVR) with every decoder — but media_kit (also libmpv) renders fine on the same device

## Summary

On a **TCL Google TV** (Realtek **RTD2875P** SoC, **PowerVR** GPU, Android 12),
`fvp` **plays** streams (audio fine, decoding runs at full frame rate) but the
**video picture is heavily color-corrupted** — chromatic noise + block artifacts
across the whole frame — and stutters.

The decisive finding: **`media_kit` (also libmpv-based) renders the exact same
streams perfectly on the exact same device.** Since both fvp/MDK and media_kit
use libmpv to demux/decode, the difference is the **renderer** — which points at
**MDK's GL renderer / texture path on this PowerVR driver**, not the GPU, libmpv,
or decoding.

Screenshot of the corruption: _[attach the photo of the garbled frame here]_

## Decisive comparison

| Engine (Flutter) | Demux/decode | Renders correctly on this device? |
|---|---|---|
| **fvp** 0.36.x (MDK GL renderer) | libmpv | ❌ **corrupted** |
| **media_kit** 1.2.6 (mpv `vo_gpu`) | libmpv | ✅ **perfect** (correct colors, smooth) |

Same decoding stack, same streams, same GPU — only the renderer differs. fvp/MDK
corrupts; mpv's `vo_gpu` does not.

## Environment

| | |
|---|---|
| fvp | 0.36.1 (MDK `0.36.0 (git d3ec2cc)`) |
| Flutter | 3.44.2 (stable), engine 77e2e94772, Dart 3.12.2 |
| video_player | 2.11.1 |
| ABI in use | **armeabi-v7a (32-bit)** — MDK banner: `Build for: Android21/31(12.0) ... 4KB ARMv7` |

### Device

| prop | value |
|---|---|
| model | TCL Smart TV `G10_4K_US_NF` (device `G10`) |
| board / platform | `rtd6748` |
| SoC | Realtek **RTD2875P** |
| GPU | **PowerVR** (`ro.hardware.vulkan = powervr`) |
| OS | Android **12** (API 31) |
| display | 3840×2160 @ 60 |
| EGL | `1.5 Android META-EGL` |

## Observations

- **Audio is correct.**
- **Decoding is healthy:** `MediaCodec` logs show steady queue/release at the
  content's native rate (~24–25 fps): `[QIB]V, QIB:24/s` / `[ROB]V, ROB:25/s`.
- **Video is color-garbled** (looks like a YUV plane / stride / color-format
  misinterpretation) and stutters despite the decoder running at rate.
- **Non-video Flutter UI renders perfectly** on the same GPU (Skia) — only the
  fvp video texture is wrong.

## What I tried (every config shows the *same* corruption)

| `registerWith` config | Result |
|---|---|
| default (`AMediaCodec`, `image=1`) | corrupted |
| `video.decoders: ['AMediaCodec:image=0']` (SurfaceTexture/OES) | corrupted |
| `video.decoders: ['AMediaCodec:copy=1']` | corrupted |
| `video.decoders: ['FFmpeg']` (**software**) | **corrupted** ← rules out the decoder |
| `tunnel: true` | renders **nothing** (black) + **crash on player dispose** |

Reproduces under both Flutter **Skia** (`EnableImpeller=false`) and **Impeller
(Vulkan)**.

## Questions

1. Given media_kit's mpv `vo_gpu` renders correctly on this PowerVR driver, is
   there an MDK **renderer / global option** (color format, texture format, GL
   workaround) that would fix MDK's output here?
2. Is there a supported way to render fvp to a native **Android SurfaceView**
   (system compositor) for `video_player`-based integrations?
3. The `tunnel: true` crash-on-dispose looks like a separate bug — I can file it
   separately with a stack trace if helpful.

## Logs

MDK init banner:

```
MDK: 0.36.0 (git d3ec2cc) - Multimedia Development Kit.
MDK: Build for: Android21/31(12.0) 5.4.284+ 4KB ARMv7; libc++180000; Clang18.0.4 ... NDK27.3.13750724. Smart TV TCL TCL
```

**Complete MDK log:** `fvp-capture-full.log` (full process logcat) and
`fvp-capture-mdk.log` (MDK-only extract) in `docs/issue-374/`.

> Note on capturing the full log: fvp already calls
> `setGlobalOption("log", "all")`, but it routes MDK's output through
> `package:logging`'s `Logger`. With no listener attached to `Logger.root`
> (the default), every MDK line is dropped before it reaches logcat — which is
> why an earlier capture only contained Android system noise (`MediaCodec`,
> `TclPqManager`) and none of MDK's internals. The complete log above was
> obtained by attaching a root `Logger` listener in `main()` that prints every
> record, so `log=all` actually surfaces.
