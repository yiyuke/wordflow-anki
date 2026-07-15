#!/usr/bin/env python3
from __future__ import annotations

import json
import sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from typing import Any, Dict
from urllib.parse import urlparse

from wordflow import Config, WordflowApp


class Handler(BaseHTTPRequestHandler):
    app: WordflowApp
    server_version = "Wordflow/0.1"

    def _headers(self, status: int = 200) -> None:
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.send_header("Cache-Control", "no-store")
        self.end_headers()

    def _json(self, data: Dict[str, Any], status: int = 200) -> None:
        self._headers(status)
        self.wfile.write(json.dumps(data, ensure_ascii=False).encode("utf-8"))

    def do_OPTIONS(self) -> None:
        self._headers(204)

    def do_GET(self) -> None:
        path = urlparse(self.path).path
        if path in {"/", "/health"}:
            self._json(self.app.health())
        else:
            self._json({"ok": False, "error": "Not found"}, 404)

    def do_POST(self) -> None:
        path = urlparse(self.path).path
        try:
            length = int(self.headers.get("Content-Length", "0"))
            if length > 50_000:
                raise ValueError("请求过大")
            payload = json.loads(self.rfile.read(length).decode("utf-8") or "{}")
            if path == "/api/capture":
                self._json(self.app.capture(payload))
            elif path == "/api/generate":
                self._json({"ok": True, **self.app.generate(payload)})
            else:
                self._json({"ok": False, "error": "Not found"}, 404)
        except ValueError as error:
            self._json({"ok": False, "error": str(error)}, 400)
        except Exception as error:
            self._json({"ok": False, "error": str(error)}, 502)

    def log_message(self, format: str, *args: Any) -> None:
        sys.stderr.write(f"[wordflow] {self.address_string()} {format % args}\n")


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
