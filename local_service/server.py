#!/usr/bin/env python3
from __future__ import annotations

import json
import os
import signal
import subprocess
import sys
from datetime import datetime
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Any, Dict
from urllib.parse import urlparse

from wordflow import Config, WordflowApp


ROOT = Path(__file__).resolve().parent.parent
CLIENT_HEADER = "X-Wordflow-Client"
CLIENT_HEADER_VALUE = "wordflow-local"
ALLOWED_ORIGIN_PREFIXES = (
    "chrome-extension://",
    "moz-extension://",
    "safari-web-extension://",
)


def is_allowed_origin(origin: str) -> bool:
    return not origin or origin.startswith(ALLOWED_ORIGIN_PREFIXES)


def is_valid_client_header(value: str) -> bool:
    return value == CLIENT_HEADER_VALUE


def quick_add_app_path() -> Path:
    configured = os.getenv("WORDFLOW_QUICK_ADD_APP", "").strip()
    candidates = [
        Path(configured).expanduser() if configured else None,
        ROOT / "Wordflow Quick Add.app",
        ROOT / "native" / "build" / "Wordflow Quick Add.app",
    ]
    return next((path for path in candidates if path and path.exists()), ROOT / "Wordflow Quick Add.app")


def quick_add_pid_path() -> Path:
    configured = os.getenv("WORDFLOW_QUICK_ADD_PID", "").strip()
    if configured:
        return Path(configured).expanduser()
    return Path.home() / "Library" / "Application Support" / "Wordflow" / "quick-add.pid"


def signal_quick_add_window(app_path: Path, pid_path: Path | None = None) -> bool:
    pid_file = pid_path or quick_add_pid_path()
    try:
        pid = int(pid_file.read_text(encoding="utf-8").strip())
        process = subprocess.run(
            ["/bin/ps", "-p", str(pid), "-o", "comm="],
            check=True,
            capture_output=True,
            text=True,
            timeout=2,
        )
        expected_name = (app_path / "Contents" / "MacOS" / "WordflowQuickAdd").name
        if Path(process.stdout.strip()).name != expected_name:
            raise ProcessLookupError("PID does not belong to Wordflow Quick Add")
        os.kill(pid, 0)
        os.kill(pid, signal.SIGUSR1)
        return True
    except (OSError, ValueError, subprocess.SubprocessError):
        try:
            pid_file.unlink(missing_ok=True)
        except OSError:
            pass
        return False


def open_quick_add_window() -> Dict[str, Any]:
    if sys.platform != "darwin":
        raise RuntimeError("原生快速窗口目前只支持 macOS")
    app_path = quick_add_app_path()
    if not app_path.exists():
        raise RuntimeError("原生快速窗口尚未安装")
    if signal_quick_add_window(app_path):
        return {"ok": True, "window": "native", "activated": True}
    subprocess.Popen(
        ["/usr/bin/open", str(app_path)],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        start_new_session=True,
    )
    return {"ok": True, "window": "native", "activated": False}


class Handler(BaseHTTPRequestHandler):
    app: WordflowApp
    server_version = "Wordflow/0.6"

    def _headers(self, status: int = 200) -> None:
        origin = self.headers.get("Origin", "").strip()
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        if origin and is_allowed_origin(origin):
            self.send_header("Access-Control-Allow-Origin", origin)
            self.send_header("Vary", "Origin")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", f"Content-Type, {CLIENT_HEADER}")
        if (
            is_allowed_origin(origin)
            and self.headers.get("Access-Control-Request-Private-Network", "").lower() == "true"
        ):
            self.send_header("Access-Control-Allow-Private-Network", "true")
        self.send_header("Cache-Control", "no-store")
        self.end_headers()

    def _json(self, data: Dict[str, Any], status: int = 200) -> None:
        self._headers(status)
        self.wfile.write(json.dumps(data, ensure_ascii=False).encode("utf-8"))

    def do_OPTIONS(self) -> None:
        origin = self.headers.get("Origin", "").strip()
        self._headers(204 if is_allowed_origin(origin) else 403)

    def do_GET(self) -> None:
        path = urlparse(self.path).path
        if path in {"/", "/health"}:
            self._json(self.app.health())
        elif path == "/api/decks":
            origin = self.headers.get("Origin", "").strip()
            if not is_allowed_origin(origin) or not is_valid_client_header(self.headers.get(CLIENT_HEADER, "")):
                self._json({"ok": False, "error": "不允许的请求来源"}, 403)
                return
            try:
                self._json({"ok": True, **self.app.decks()})
            except Exception as error:
                self._json({"ok": False, "error": str(error)}, 502)
        else:
            self._json({"ok": False, "error": "Not found"}, 404)

    def do_POST(self) -> None:
        path = urlparse(self.path).path
        try:
            origin = self.headers.get("Origin", "").strip()
            if not is_allowed_origin(origin):
                self._json({"ok": False, "error": "不允许的请求来源"}, 403)
                return
            if not is_valid_client_header(self.headers.get(CLIENT_HEADER, "")):
                self._json({"ok": False, "error": "缺少 Wordflow 本地客户端标识"}, 403)
                return
            content_type = self.headers.get("Content-Type", "").split(";", 1)[0].strip().lower()
            if content_type != "application/json":
                self._json({"ok": False, "error": "只接受 JSON 请求"}, 415)
                return
            length = int(self.headers.get("Content-Length", "0"))
            if length > 50_000:
                raise ValueError("请求过大")
            payload = json.loads(self.rfile.read(length).decode("utf-8") or "{}")
            if path == "/api/capture":
                self._json(self.app.capture(payload))
            elif path == "/api/generate":
                self._json({"ok": True, **self.app.generate(payload)})
            elif path == "/api/decks/select":
                self._json(self.app.select_deck(payload))
            elif path == "/api/window/open":
                self._json(open_quick_add_window())
            else:
                self._json({"ok": False, "error": "Not found"}, 404)
        except ValueError as error:
            self._json({"ok": False, "error": str(error)}, 400)
        except Exception as error:
            timestamp = datetime.now().astimezone().isoformat(timespec="seconds")
            sys.stderr.write(
                f"[wordflow] {timestamp} {path} failed: {type(error).__name__}: {error}\n"
            )
            sys.stderr.flush()
            self._json({"ok": False, "error": str(error)}, 502)

    def log_message(self, format: str, *args: Any) -> None:
        timestamp = datetime.now().astimezone().isoformat(timespec="seconds")
        sys.stderr.write(f"[wordflow] {timestamp} {self.address_string()} {format % args}\n")


def main() -> None:
    config = Config.from_env()
    Handler.app = WordflowApp(config)
    server = ThreadingHTTPServer((config.host, config.port), Handler)
    print(f"Wordflow local service: http://{config.host}:{config.port}")
    print(f"Anki deck: {config.deck_name} | model: {config.openai_model}")
    if not config.openai_api_key and not config.mock_openai:
        print("Warning: OPENAI_API_KEY is not configured", file=sys.stderr)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


if __name__ == "__main__":
    main()
