#!/usr/bin/env python3
"""Turn repeated `dumpsys SurfaceFlinger --latency <layer>` dumps into a
frame-pacing report.

Input format (pacing_raw.txt written by run_bench.sh): blocks separated by
lines starting with '===', each block is one dump: first line = refresh
period (ns), then one line per frame: desiredPresent actualPresent frameReady
(ns). Dumps overlap (each returns the last 127 frames); actual-present
timestamps are deduplicated across dumps.

Writes <name>.csv (per-frame present times + gaps) next to the input and
prints the human-readable histogram report to stdout.
"""
import sys
import os

INT64_MAX = (1 << 63) - 1

# Gap buckets in ms. A 60Hz-vsync-paced 24fps clip should sit in 33-58ms;
# "burst" (<=20ms) and "drought" (>=80ms) counts are the stutter signature.
BUCKETS = [(0, 20), (20, 40), (40, 60), (60, 80), (80, 120), (120, 10**9)]


def parse(path):
    present = set()
    with open(path) as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("==="):
                continue
            parts = line.split()
            if len(parts) != 3:
                continue
            try:
                actual = int(parts[1])
            except ValueError:
                continue
            if actual <= 0 or actual == INT64_MAX:
                continue
            present.add(actual)
    return sorted(present)


def main():
    if len(sys.argv) != 2:
        print(__doc__)
        sys.exit(2)
    path = sys.argv[1]
    times = parse(path)
    if len(times) < 10:
        print(f"only {len(times)} present timestamps parsed — not enough data")
        sys.exit(1)

    gaps_ms = [(b - a) / 1e6 for a, b in zip(times, times[1:])]
    total_s = (times[-1] - times[0]) / 1e9
    fps = (len(times) - 1) / total_s if total_s > 0 else 0.0

    csv_path = os.path.splitext(path)[0] + ".csv"
    with open(csv_path, "w") as f:
        f.write("present_ns,gap_ms\n")
        f.write(f"{times[0]},\n")
        for t, g in zip(times[1:], gaps_ms):
            f.write(f"{t},{g:.3f}\n")

    s = sorted(gaps_ms)

    def pct(p):
        return s[min(len(s) - 1, int(len(s) * p))]

    print(f"frames presented : {len(times)}")
    print(f"window           : {total_s:.1f}s")
    print(f"avg presented fps: {fps:.2f}")
    print(f"gap p50/p95/p99  : {pct(.50):.1f} / {pct(.95):.1f} / {pct(.99):.1f} ms")
    print(f"max gap (drought): {max(gaps_ms):.1f} ms")
    print()
    print("gap histogram:")
    for lo, hi in BUCKETS:
        n = sum(1 for g in gaps_ms if lo <= g < hi)
        label = f"{lo}-{hi}ms" if hi < 10**9 else f">{lo}ms"
        bar = "#" * min(60, round(60 * n / max(1, len(gaps_ms))))
        print(f"  {label:>10}: {n:5d} {bar}")
    bursts = sum(1 for g in gaps_ms if g <= 20)
    droughts = sum(1 for g in gaps_ms if g >= 80)
    print()
    print(f"burst frames (gap<=20ms) : {bursts}  <- frames shown 'too soon' after the previous one")
    print(f"drought gaps (>=80ms)    : {droughts}  <- visible stutters")
    print(f"csv: {csv_path}")


if __name__ == "__main__":
    main()
