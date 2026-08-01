"""Clock rate for one bench run: media position advanced / wall time elapsed.

BENCH_STATS ticks on a 5s wall-clock timer and carries the media position, so
the ratio of the two gives MDK's clock rate without reading its own counters.
~1.0 is correct; mdk-sdk#362's failure sits near 0.04.

Uses the MEDIAN of per-tick deltas, not first-to-last: a live stream can jump
position once when the player resyncs to the live edge, and that single
discontinuity swamps an endpoint-based average (seen as rate=6189).
"""
import re
import sys

text = open(sys.argv[1], errors='ignore').read()
pos = [int(m) for m in re.findall(r'BENCH_STATS.*?pos=(\d+)ms', text)]
if len(pos) >= 3:
    steps = sorted((b - a) / 5000.0 for a, b in zip(pos, pos[1:]))
    median = steps[len(steps) // 2]
    print('RATE=%.3f' % median)
    print('SAMPLES=%s' % ','.join(str(p) for p in pos[:5]))
else:
    print('RATE=na')
    print('SAMPLES=%s' % (','.join(str(p) for p in pos) if pos else 'none'))
