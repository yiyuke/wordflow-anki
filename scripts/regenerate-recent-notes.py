#!/usr/bin/env python3
"""Regenerate recent Wordflow notes with the current Full Learning prompt.

The command previews by default. Pass --apply to update the existing notes in
place. Original context, source, audio, and note identity are preserved. If an
Anki write fails, already-updated notes are restored best-effort in this run.
"""

from __future__ import annotations

import argparse
import html
import re
import sys
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from typing import Any, Dict, Iterable, List


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "local_service"))

from wordflow import (  # noqa: E402
    AnkiClient,
    Config,
    OpenAICardGenerator,
    anki_fields,
    normalize_capture,
    safe_tag,
)


def plain_field(note: Dict[str, Any], name: str) -> str:
    raw = str(note.get("fields", {}).get(name, {}).get("value", ""))
    raw = re.sub(r"(?i)<br\s*/?>", "\n", raw)
    raw = re.sub(r"<[^>]+>", "", raw)
    return html.unescape(raw).strip()


def raw_fields(note: Dict[str, Any]) -> Dict[str, str]:
    return {
        name: str(field.get("value", ""))
        for name, field in note.get("fields", {}).items()
    }


def anki_query(deck: str, excluded_tags: Iterable[str]) -> str:
    terms = ["tag:wordflow"]
    if deck:
        escaped_deck = deck.replace("\\", "\\\\").replace('"', '\\"')
        terms.insert(0, f'deck:"{escaped_deck}"')
    for tag in excluded_tags:
        normalized = safe_tag(tag)
        if normalized:
            terms.append(f"-tag:{normalized}")
    return " ".join(terms)


def recent_notes(
    client: AnkiClient,
    limit: int,
    note_ids: Iterable[int],
    *,
    deck: str = "",
    excluded_tags: Iterable[str] = (),
) -> List[Dict[str, Any]]:
    requested = [int(note_id) for note_id in note_ids]
    if not requested:
        requested = sorted(
            (
                int(note_id)
                for note_id in client.invoke(
                    "findNotes",
                    query=anki_query(deck, excluded_tags),
                )
            ),
            reverse=True,
        )[:limit]
    if not requested:
        raise RuntimeError("没有找到带 wordflow 标签的 Anki 笔记")
    by_id = {
        int(note["noteId"]): note
        for note in client.invoke("notesInfo", notes=requested)
    }
    missing = [str(note_id) for note_id in requested if note_id not in by_id]
    if missing:
        raise RuntimeError(f"找不到 Anki 笔记：{', '.join(missing)}")
    return [by_id[note_id] for note_id in requested]


def deck_map(client: AnkiClient, notes: List[Dict[str, Any]]) -> Dict[int, str]:
    card_ids = [int(card_id) for note in notes for card_id in note.get("cards", [])]
    cards = client.invoke("cardsInfo", cards=card_ids) if card_ids else []
    card_to_deck = {int(card["cardId"]): str(card.get("deckName", "")) for card in cards}
    result: Dict[int, str] = {}
    for note in notes:
        note_cards = note.get("cards", [])
        first_card = int(note_cards[0]) if note_cards else 0
        result[int(note["noteId"])] = card_to_deck.get(first_card, "")
    return result


def capture_for(note: Dict[str, Any]) -> Dict[str, str]:
    return normalize_capture({
        "text": plain_field(note, "Word"),
        "context": plain_field(note, "Context"),
        "sense_hint": plain_field(note, "MeaningZH"),
        "source_title": plain_field(note, "SourceTitle"),
        "source_url": plain_field(note, "SourceURL"),
        "source_type": "regenerated",
        "language": "zh",
        "learning_mode": "full",
    })


def restore_notes(client: AnkiClient, updated: List[Dict[str, Any]]) -> None:
    for item in reversed(updated):
        note_id = item["note_id"]
        try:
            client.invoke(
                "updateNoteFields",
                note={"id": note_id, "fields": item["old_fields"]},
            )
            current = client.invoke("notesInfo", notes=[note_id])[0]
            current_tags = [str(tag) for tag in current.get("tags", [])]
            if current_tags:
                client.invoke("removeTags", notes=[note_id], tags=" ".join(current_tags))
            if item["old_tags"]:
                client.invoke("addTags", notes=[note_id], tags=" ".join(item["old_tags"]))
        except Exception as error:  # best-effort recovery must continue
            print(f"[rollback] {note_id} 恢复失败：{error}", file=sys.stderr, flush=True)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--limit", type=int, default=10, help="最近笔记数量（默认 10）")
    parser.add_argument("--note-id", type=int, action="append", default=[], help="只处理指定 note id")
    parser.add_argument("--deck", default="", help="只处理指定牌组中的 Wordflow 笔记")
    parser.add_argument(
        "--exclude-tag",
        action="append",
        default=[],
        help="跳过带指定标签的笔记；可重复使用",
    )
    parser.add_argument("--quiet", action="store_true", help="批量处理时不打印每张卡片的正文")
    parser.add_argument("--workers", type=int, default=1, help="并行生成数量（默认 1，最多 4）")
    parser.add_argument("--browse", action="store_true", help="完成后主动打开 Anki 浏览器（默认不抢焦点）")
    parser.add_argument("--apply", action="store_true", help="原地更新 Anki；默认只预览")
    args = parser.parse_args()
    if args.limit < 1 or args.limit > 100:
        parser.error("--limit 必须在 1 到 100 之间")
    if args.workers < 1 or args.workers > 4:
        parser.error("--workers 必须在 1 到 4 之间")

    config = Config.from_env()
    if config.mock_openai or config.mock_anki:
        raise RuntimeError("请关闭 MOCK_OPENAI / MOCK_ANKI 后再重写真实卡片")
    if not config.openai_api_key:
        raise RuntimeError("没有找到本机 OpenAI API Key")

    client = AnkiClient(config)
    generator = OpenAICardGenerator(config)
    notes = recent_notes(
        client,
        args.limit,
        args.note_id,
        deck=args.deck,
        excluded_tags=args.exclude_tag,
    )
    decks = deck_map(client, notes)
    generated: List[Dict[str, Any]] = []

    def generate_item(index_and_note: tuple[int, Dict[str, Any]]) -> Dict[str, Any]:
        index, note = index_and_note
        note_id = int(note["noteId"])
        capture = capture_for(note)
        card = generator.generate(capture)
        return {
            "index": index,
            "note_id": note_id,
            "note": note,
            "capture": capture,
            "card": card,
            "deck": decks.get(note_id, ""),
        }

    indexed_notes = list(enumerate(notes, start=1))
    if args.workers == 1:
        generated_items = map(generate_item, indexed_notes)
    else:
        executor = ThreadPoolExecutor(max_workers=args.workers)
        generated_items = executor.map(generate_item, indexed_notes)
    try:
        for item in generated_items:
            index = item["index"]
            capture = item["capture"]
            card = item["card"]
            print(f"[{index}/{len(notes)}] 已生成 {capture['text']}", flush=True)
            if not args.quiet:
                print(f"    {card['learning_note']}", flush=True)
            generated.append(item)
    finally:
        if args.workers != 1:
            executor.shutdown(wait=True)

    if not args.apply:
        print("\n以上仅为预览；确认后加 --apply 原地更新。", flush=True)
        return 0

    for deck in sorted({item["deck"] for item in generated if item["deck"]}):
        client.ensure_model(deck)

    updated: List[Dict[str, Any]] = []
    try:
        for index, item in enumerate(generated, start=1):
            note = item["note"]
            note_id = item["note_id"]
            old_fields = raw_fields(note)
            old_tags = [str(tag) for tag in note.get("tags", [])]
            new_fields = anki_fields(
                item["card"],
                item["capture"],
                audio_field=old_fields.get("Audio", ""),
            )
            updated.append({"note_id": note_id, "old_fields": old_fields, "old_tags": old_tags})
            client.invoke("updateNoteFields", note={"id": note_id, "fields": new_fields})
            client.invoke("removeTags", notes=[note_id], tags="mode-exam exam-reading")
            generated_tags = [safe_tag(tag) for tag in item["card"].get("tags", [])]
            added_tags = ["mode-full", "memory-bridge-v1", *filter(None, generated_tags)]
            client.invoke("addTags", notes=[note_id], tags=" ".join(sorted(set(added_tags))))
            print(f"[{index}/{len(generated)}] 已更新 {item['capture']['text']}", flush=True)
    except Exception:
        print("写入中断，正在恢复本次已修改的笔记…", file=sys.stderr, flush=True)
        restore_notes(client, updated)
        raise

    if args.browse:
        note_query = " OR ".join(f"nid:{item['note_id']}" for item in generated)
        try:
            client.invoke("guiBrowse", query=note_query)
        except RuntimeError:
            pass
    print(f"\n已在后台原地更新 {len(generated)} 张笔记。", flush=True)
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (RuntimeError, ValueError) as error:
        print(f"错误：{error}", file=sys.stderr)
        raise SystemExit(1)
