#!/usr/bin/env python3
"""Minimal HTTP bridge: POST /play, /pause, /next, /previous, /play-pause → playerctl."""

import subprocess
import sys
from http.server import BaseHTTPRequestHandler, HTTPServer

ACTIONS = {"play", "pause", "next", "previous", "play-pause"}


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/health":
            self._respond(200, "ok")
        else:
            self._respond(404, "not found")

    def do_POST(self):
        action = self.path.lstrip("/")
        if action not in ACTIONS:
            self._respond(404, f"unknown action: {action}")
            return
        try:
            result = subprocess.run(
                ["playerctl", action], capture_output=True, text=True, timeout=5
            )
            if result.returncode == 0:
                self._respond(200, result.stdout or "ok")
            else:
                self._respond(502, result.stderr or "playerctl failed")
        except subprocess.TimeoutExpired:
            self._respond(504, "playerctl timeout")

    def _respond(self, code, body):
        self.send_response(code)
        self.send_header("Content-Type", "text/plain")
        self.end_headers()
        self.wfile.write(body.encode())

    def log_message(self, fmt, *args):
        print(fmt % args, file=sys.stderr)


if __name__ == "__main__":
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8553
    server = HTTPServer(("127.0.0.1", port), Handler)
    print(f"hass-playerctl listening on 127.0.0.1:{port}", file=sys.stderr)
    server.serve_forever()
