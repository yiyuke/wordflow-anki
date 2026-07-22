#!/usr/bin/env python3
from __future__ import annotations

import argparse
import http.client
import json
import locale
import socket
import subprocess
import sys
import urllib.error
import urllib.request


DIRECT_OPENER = urllib.request.build_opener(urllib.request.ProxyHandler({}))


def clipboard_text() -> str:
    if sys.platform == "darwin":
        return subprocess.run(["pbpaste"], check=True, capture_output=True, text=True).stdout
    raise RuntimeError("当前平台请通过参数或标准输入传入选中文字")


def main() -> None:
    locale_name = (locale.getlocale()[0] or "").lower()
    default_language = "zh" if locale_name.startswith("zh") else "en"
    parser = argparse.ArgumentParser(description="Add selected or copied text to Anki through Wordflow")
    parser.add_argument("text", nargs="?", help="word or phrase; defaults to stdin/clipboard")
    parser.add_argument("--context", default="", help="optional source sentence")
    parser.add_argument("--source-title", default="Desktop selection")
    parser.add_argument("--service-url", default="http://127.0.0.1:8766")
    parser.add_argument("--language", choices=("zh", "en"), default=default_language)
    args = parser.parse_args()

    text = args.text or (sys.stdin.read() if not sys.stdin.isatty() else clipboard_text())
    payload = {
        "text": text.strip(),
        "context": args.context.strip(),
        "source_title": args.source_title,
        "source_url": "",
        "source_type": "desktop",
        "language": args.language,
    }
    request = urllib.request.Request(
        f"{args.service_url.rstrip('/')}/api/capture",
        data=json.dumps(payload, ensure_ascii=False).encode("utf-8"),
        headers={
            "Content-Type": "application/json",
            "X-Wordflow-Client": "wordflow-local",
        },
        method="POST",
    )
    try:
        with DIRECT_OPENER.open(request, timeout=120) as response:
            data = json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as error:
        data = json.loads(error.read().decode("utf-8"))
    except (
        http.client.RemoteDisconnected,
        ConnectionResetError,
        socket.timeout,
        TimeoutError,
        urllib.error.URLError,
    ) as error:
        reason = error.reason if isinstance(error, urllib.error.URLError) else error
        message = f"无法连接本地服务：{reason}" if args.language == "zh" else f"Could not connect to Wordflow: {reason}"
        raise SystemExit(message) from error

    if not data.get("ok"):
        fallback = "加入失败" if args.language == "zh" else "Could not add the card"
        raise SystemExit(data.get("error", fallback))
    if args.language == "zh":
        status = "已存在" if data.get("duplicate") else "已加入"
        print(f"{status}：{data['card']['word']}")
    else:
        status = "Already exists" if data.get("duplicate") else "Added"
        print(f"{status}: {data['card']['word']}")


if __name__ == "__main__":
    main()
