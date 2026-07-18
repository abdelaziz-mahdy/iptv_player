#!/usr/bin/env python3
"""http.server with single-range HTTP Range support (python's stock server
has none, which makes MP4s with trailing metadata unplayable and defeats
any player that probes with ranges).

Usage: range_server.py [port] [directory]
"""
import os
import re
import sys
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer


class RangeHandler(SimpleHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def send_head(self):
        path = self.translate_path(self.path)
        if os.path.isdir(path) or not os.path.exists(path):
            return super().send_head()

        rng = self.headers.get("Range")
        m = re.match(r"bytes=(\d*)-(\d*)$", rng.strip()) if rng else None
        if not m or (not m.group(1) and not m.group(2)):
            return super().send_head()

        size = os.path.getsize(path)
        if m.group(1):
            start = int(m.group(1))
            end = int(m.group(2)) if m.group(2) else size - 1
        else:  # suffix range: last N bytes
            start = max(0, size - int(m.group(2)))
            end = size - 1
        end = min(end, size - 1)
        if start > end or start >= size:
            self.send_response(416)
            self.send_header("Content-Range", f"bytes */{size}")
            self.send_header("Content-Length", "0")
            self.end_headers()
            return None

        f = open(path, "rb")
        f.seek(start)
        self.send_response(206)
        self.send_header("Content-Type", self.guess_type(path))
        self.send_header("Accept-Ranges", "bytes")
        self.send_header("Content-Range", f"bytes {start}-{end}/{size}")
        self.send_header("Content-Length", str(end - start + 1))
        self.end_headers()
        self._range_remaining = end - start + 1
        return f

    def copyfile(self, source, outputfile):
        remaining = getattr(self, "_range_remaining", None)
        if remaining is None:
            return super().copyfile(source, outputfile)
        self._range_remaining = None
        while remaining > 0:
            chunk = source.read(min(1024 * 256, remaining))
            if not chunk:
                break
            outputfile.write(chunk)
            remaining -= len(chunk)

    def end_headers(self):
        # Advertise range support on plain 200s too.
        if not any(h.lower() == "accept-ranges" for h, _ in self._headers_buffer_pairs()):
            self.send_header("Accept-Ranges", "bytes")
        super().end_headers()

    def _headers_buffer_pairs(self):
        pairs = []
        for raw in getattr(self, "_headers_buffer", []):
            try:
                line = raw.decode("latin-1")
            except AttributeError:
                line = raw
            if ":" in line:
                k, v = line.split(":", 1)
                pairs.append((k.strip(), v.strip()))
        return pairs

    def log_message(self, fmt, *args):
        sys.stderr.write("%s - %s\n" % (self.address_string(), fmt % args))


def main():
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8000
    if len(sys.argv) > 2:
        os.chdir(sys.argv[2])
    server = ThreadingHTTPServer(("", port), RangeHandler)
    print(f"range server on :{port} in {os.getcwd()}")
    server.serve_forever()


if __name__ == "__main__":
    main()
