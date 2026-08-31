#!/usr/bin/env python3
"""Host-side screenshot server for the App Store capture run.

The integration test runs inside the iOS simulator, which shares the host
network stack, so it can call this server on 127.0.0.1 and block until the
frame is on disk. That gives a deterministic handshake: the test only advances
once the screenshot exists and has been dimension-checked.

Screenshots are taken with `xcrun simctl io <udid> screenshot`, which produces
the device's native 1320x2868 for the 6.9" iPhone — the size App Store Connect
expects. Flutter's own takeScreenshot is deliberately not used (see README).

    GET /shot?name=en_01_home   -> capture, verify size, 200 "OK" / 500 "<err>"
    GET /ping                   -> 200 "pong"
"""

import os
import struct
import subprocess
import sys
from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib.parse import urlparse, parse_qs

UDID = os.environ.get("SALAMAT_UDID", "C5D3C6E3-DDC3-488D-80A3-8FD2BEE8B944")
OUT_DIR = os.environ.get("SALAMAT_SHOT_DIR", "store2")
PORT = int(os.environ.get("SALAMAT_SHOT_PORT", "8787"))
EXPECTED = (1320, 2868)

failures = []


def png_size(path):
    """Read width/height straight out of the PNG IHDR chunk."""
    with open(path, "rb") as fh:
        head = fh.read(24)
    if len(head) < 24 or head[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError("not a PNG")
    return struct.unpack(">II", head[16:24])


def capture(name):
    safe = "".join(c for c in name if c.isalnum() or c in "_-")
    if not safe:
        raise ValueError("empty name")
    os.makedirs(OUT_DIR, exist_ok=True)
    path = os.path.join(OUT_DIR, safe + ".png")
    subprocess.run(
        ["xcrun", "simctl", "io", UDID, "screenshot", path],
        check=True,
        capture_output=True,
    )
    w, h = png_size(path)
    if (w, h) != EXPECTED:
        raise ValueError(
            f"{safe}.png is {w}x{h}, expected {EXPECTED[0]}x{EXPECTED[1]}"
        )
    return path, w, h


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *_):
        pass  # keep the runner output readable

    def _reply(self, code, body):
        payload = body.encode()
        self.send_response(code)
        self.send_header("Content-Type", "text/plain; charset=utf-8")
        self.send_header("Content-Length", str(len(payload)))
        self.end_headers()
        self.wfile.write(payload)

    def do_GET(self):
        url = urlparse(self.path)
        if url.path == "/ping":
            self._reply(200, "pong")
            return
        if url.path != "/shot":
            self._reply(404, "no")
            return
        name = (parse_qs(url.query).get("name") or [""])[0]
        try:
            path, w, h = capture(name)
            print(f"  shot  {path}  {w}x{h}", flush=True)
            self._reply(200, "OK")
        except Exception as exc:  # noqa: BLE001 - surfaced to the test + runner
            msg = f"{name}: {exc}"
            failures.append(msg)
            print(f"  FAIL  {msg}", file=sys.stderr, flush=True)
            self._reply(500, msg)


if __name__ == "__main__":
    srv = HTTPServer(("127.0.0.1", PORT), Handler)
    print(f"shot server on 127.0.0.1:{PORT} -> {OUT_DIR} ({UDID})", flush=True)
    try:
        srv.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        if failures:
            print(f"{len(failures)} screenshot failure(s)", file=sys.stderr)
            sys.exit(1)
