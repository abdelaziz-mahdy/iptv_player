#!/usr/bin/env python3
"""Rewrite the Android render-backend meta-data in AndroidManifest.xml.
Usage: set_impeller.py <vulkan|opengles|skia>"""
import re, sys, pathlib

mode = sys.argv[1]
mf = pathlib.Path("android/app/src/main/AndroidManifest.xml")
t = mf.read_text()

# Strip any existing EnableImpeller / ImpellerBackend meta-data elements.
t = re.sub(
    r'\n\s*<meta-data\s+android:name="io\.flutter\.embedding\.android\.'
    r'(?:EnableImpeller|ImpellerBackend)"\s+android:value="[^"]*"\s*/>',
    '', t)

if mode == "skia":
    block = (
        '\n        <meta-data\n'
        '            android:name="io.flutter.embedding.android.EnableImpeller"\n'
        '            android:value="false" />')
elif mode == "vulkan":
    block = (
        '\n        <meta-data\n'
        '            android:name="io.flutter.embedding.android.EnableImpeller"\n'
        '            android:value="true" />')
elif mode == "opengles":
    block = (
        '\n        <meta-data\n'
        '            android:name="io.flutter.embedding.android.EnableImpeller"\n'
        '            android:value="true" />\n'
        '        <meta-data\n'
        '            android:name="io.flutter.embedding.android.ImpellerBackend"\n'
        '            android:value="opengles" />')
else:
    sys.exit(f"unknown mode: {mode}")

# Insert the meta-data just before the first <activity> — a stable anchor that
# doesn't depend on which attributes the <application> tag ends with.
needle = "        <activity"
if needle not in t:
    sys.exit("could not find <activity> anchor in AndroidManifest.xml")
t = t.replace(needle, block.lstrip("\n") + "\n" + needle, 1)
mf.write_text(t)
print(f"manifest set: {mode}")
