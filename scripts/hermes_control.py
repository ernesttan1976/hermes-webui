#!/usr/bin/env python3
"""Local control API to start/stop Hermes (UI-controlled) and view logs.

This script intentionally runs the bootstrap directly (no restart loop) so the
control UI can manage start/stop. It writes to its own log file under
~/Library/Logs/Hermes/hermes-webui-ui-controlled.log.

Run: python3 scripts/hermes_control.py
Listen: http://127.0.0.1:8788 (HERMES_CONTROL_PORT env to override)
"""

from __future__ import annotations

import json
import os
import subprocess
import threading
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path
import sys

REPO_ROOT = Path(__file__).resolve().parents[1]
HERMES_HOST = os.getenv("HERMES_WEBUI_HOST", "127.0.0.1")
HERMES_PORT = int(os.getenv("HERMES_WEBUI_PORT", "8787"))
LOG_DIR = Path.home() / "Library" / "Logs" / "Hermes"
LOG_FILE = LOG_DIR / "hermes-webui-ui-controlled.log"

LOG_DIR.mkdir(parents=True, exist_ok=True)

proc_lock = threading.Lock()
proc: subprocess.Popen | None = None  # type: ignore[var-annotated]


def start_service() -> bool:
    global proc
    with proc_lock:
        if proc is not None and proc.poll() is None:
            return False

        env = os.environ.copy()
        env.setdefault("HERMES_HOME", str(REPO_ROOT / "docker-volumes" / "hermes-home"))
        env.setdefault("HERMES_WEBUI_HOST", HERMES_HOST)
        env.setdefault("HERMES_WEBUI_PORT", str(HERMES_PORT))

        log_fh = open(LOG_FILE, "ab")

        cmd = [
            sys.executable or "python3",
            str(REPO_ROOT / "bootstrap.py"),
            "--no-browser",
            str(HERMES_PORT),
        ]
        proc = subprocess.Popen(
            cmd,
            cwd=str(REPO_ROOT),
            env=env,
            stdout=log_fh,
            stderr=subprocess.STDOUT,
        )
        return True


def stop_service() -> bool:
    global proc
    with proc_lock:
        if proc is None or proc.poll() is not None:
            return False
        proc.terminate()
        try:
            proc.wait(timeout=10)
        except subprocess.TimeoutExpired:
            proc.kill()
        proc = None
        return True


def service_status() -> dict:
    with proc_lock:
        if proc is None:
            return {"running": False}
        return {"running": proc.poll() is None, "pid": proc.pid}


def tail_logs(n_lines: int = 200) -> str:
    if not LOG_FILE.exists():
        return ""
    try:
        # For simplicity read whole file and tail in memory; fine for modest logs
        text = LOG_FILE.read_text(encoding="utf-8", errors="ignore")
        lines = text.splitlines()
        return "\n".join(lines[-n_lines:])
    except Exception as exc:
        return f"[error reading logs: {exc}]"


class Handler(BaseHTTPRequestHandler):
    def _set_json(self, code: int = 200) -> None:
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.end_headers()

    def _set_text(self, code: int = 200) -> None:
        self.send_response(code)
        self.send_header("Content-Type", "text/plain; charset=utf-8")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.end_headers()

    def do_OPTIONS(self) -> None:
        self.send_response(204)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.end_headers()

    def do_GET(self) -> None:
        if self.path == "/status":
            self._set_json()
            self.wfile.write(json.dumps(service_status()).encode("utf-8"))
        elif self.path == "/logs":
            self._set_text()
            self.wfile.write(tail_logs().encode("utf-8"))
        elif self.path == "/health":
            self._set_json()
            self.wfile.write(json.dumps({"status": "ok"}).encode("utf-8"))
        else:
            self.send_error(404, "Not found")

    def do_POST(self) -> None:
        if self.path == "/start":
            started = start_service()
            self._set_json(200)
            self.wfile.write(
                json.dumps({"ok": True, "started": started, "status": service_status()}).encode(
                    "utf-8"
                )
            )
        elif self.path == "/stop":
            stopped = stop_service()
            self._set_json(200)
            self.wfile.write(
                json.dumps({"ok": True, "stopped": stopped, "status": service_status()}).encode(
                    "utf-8"
                )
            )
        else:
            self.send_error(404, "Not found")


def main() -> None:
    port = int(os.getenv("HERMES_CONTROL_PORT", "8788"))
    server = HTTPServer(("127.0.0.1", port), Handler)
    print(f"[hermes-control] Serving on http://127.0.0.1:{port}")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        stop_service()
        server.server_close()


if __name__ == "__main__":
    main()
