#!/usr/bin/env python3
"""Swap the fvp.registerWith() options in video_controller.dart for testing
different Android decode/render paths.
  Usage: set_fvp.py <copy|image0|surface0|tunnel|sw>"""
import re, sys, pathlib

mode = sys.argv[1]
opts = {
    'copy':     "'video.decoders': ['AMediaCodec:copy=1', 'FFmpeg'],",
    'image0':   "'video.decoders': ['AMediaCodec:image=0', 'FFmpeg'],",
    'surface0': "'video.decoders': ['AMediaCodec:surface=0', 'FFmpeg'],",
    'tunnel':   "'tunnel': true,\n        'video.decoders': ['AMediaCodec', 'FFmpeg'],",
    'sw':       "'video.decoders': ['FFmpeg'],",
    # 'exo' disables fvp on Android entirely -> native ExoPlayer (SurfaceView),
    # which renders via the system compositor instead of MDK's GL texture.
    'diag':     "'global': {'logLevel': 'all'},",
    'exo':      "'platforms': ['windows', 'macos', 'linux'],",
}[mode]

f = pathlib.Path('lib/features/player/video_controller.dart')
t = f.read_text()
t, n = re.subn(
    r"fvp\.registerWith\(options: \{.*?\}\);",
    "fvp.registerWith(options: {\n        " + opts + "\n      });",
    t, count=1, flags=re.S)
if n != 1:
    sys.exit('could not find fvp.registerWith(options: {...}) to replace')
f.write_text(t)
print(f"fvp mode set: {mode}")
