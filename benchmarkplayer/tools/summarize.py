#!/usr/bin/env python3
"""Merge the per-variant folders produced by run_bench.sh into a single
ticket-ready comparison.md (printed to stdout).

Usage: tools/summarize.py <results-dir>
"""
import os
import re
import sys


def read(path):
    try:
        with open(path) as f:
            return f.read()
    except OSError:
        return ""


def field(text, key):
    m = re.search(rf"^{re.escape(key)}\s*:\s*(.+)$", text, re.M)
    return m.group(1).strip() if m else "?"


def main():
    if len(sys.argv) != 2:
        print(__doc__)
        sys.exit(2)
    root = sys.argv[1]
    variants = sorted(
        d for d in os.listdir(root)
        if os.path.isdir(os.path.join(root, d)) and not d.startswith(".")
        and d != "apks"
    )
    if not variants:
        print(f"no variant folders in {root}")
        sys.exit(1)

    meta0 = read(os.path.join(root, variants[0], "meta.txt"))
    print("# Frame pacing comparison — media_kit (libmpv) vs fvp (MDK)")
    print()
    print(f"Device: {field(meta0, 'device')} (Android {field(meta0, 'android')}) — "
          f"presented-frame timestamps from `dumpsys SurfaceFlinger --latency`, "
          f"{field(meta0, 'duration')} per variant, local-LAN reference clip "
          f"(testsrc2 1080p H.264).")
    print()
    print("| variant | avg fps | gap p50/p95/p99 (ms) | max gap (ms) | "
          "bursts (<=20ms) | droughts (>=80ms) |")
    print("|---|---|---|---|---|---|")
    for v in variants:
        h = read(os.path.join(root, v, "histogram.txt"))
        if not h:
            print(f"| {v} | (no data) | | | | |")
            continue
        fps = field(h, "avg presented fps")
        pcts = field(h, "gap p50/p95/p99")
        mx = field(h, "max gap (drought)").replace(" ms", "")
        bursts = re.search(r"burst frames \(gap<=20ms\)\s*:\s*(\d+)", h)
        droughts = re.search(r"drought gaps \(>=80ms\)\s*:\s*(\d+)", h)
        print(f"| {v} | {fps} | {pcts.replace(' ms', '')} | {mx} | "
              f"{bursts.group(1) if bursts else '?'} | "
              f"{droughts.group(1) if droughts else '?'} |")

    print()
    print("## Per-variant detail")
    for v in variants:
        print()
        print(f"### {v}")
        print()
        meta = read(os.path.join(root, v, "meta.txt")).strip()
        if meta:
            print("```")
            print(meta)
            print("```")
        h = read(os.path.join(root, v, "histogram.txt")).strip()
        if h:
            print("```")
            print(h)
            print("```")
        stats = [l for l in read(os.path.join(root, v, "stats.txt")).splitlines()
                 if "BENCH_STATS" in l or "BENCH_META" in l]
        if stats:
            print("<details><summary>player-reported stats (5s cadence)</summary>")
            print()
            print("```")
            for line in stats[:8] + (["..."] if len(stats) > 12 else []) + stats[-4:]:
                print(line)
            print("```")
            print("</details>")


if __name__ == "__main__":
    main()
