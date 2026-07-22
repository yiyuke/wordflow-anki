import json
import os
import re
import sys
import tempfile
import unittest
from dataclasses import replace
from http.client import RemoteDisconnected
from pathlib import Path
from unittest.mock import MagicMock, patch


SERVICE_DIR = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(SERVICE_DIR))

from wordflow import (  # noqa: E402
    AnkiClient,
    CARD_CSS,
    Config,
    OpenAICardGenerator,
    WordflowApp,
    _request_json,
    extract_response_text,
    html_items,
    identity_tag,
    keychain_secret,
    normalize_deck_name,
    normalize_capture,
)
from server import is_allowed_origin, is_valid_client_header, signal_quick_add_window  # noqa: E402


def contrast_ratio(foreground: str, background: str) -> float:
    def luminance(color: str) -> float:
        channels = [int(color[index:index + 2], 16) / 255 for index in (1, 3, 5)]
        linear = [value / 12.92 if value <= 0.04045 else ((value + 0.055) / 1.055) ** 2.4 for value in channels]
        return 0.2126 * linear[0] + 0.7152 * linear[1] + 0.0722 * linear[2]

    lighter, darker = sorted((luminance(foreground), luminance(background)), reverse=True)
    return (lighter + 0.05) / (darker + 0.05)


def mock_config() -> Config:
    return Config(
        host="127.0.0.1",
        port=0,
        openai_api_key="",
        openai_model="mock-model",
        openai_reasoning_effort="none",
        openai_base_url="https://example.invalid/v1",
        anki_url="http://127.0.0.1:8765",
        anki_api_key="",
        deck_name="Test Deck",
        model_name="Test Model",
        enable_tts=False,
        tts_model="tts-1",
        tts_voice="alloy",
        mock_openai=True,
        mock_anki=True,
    )


class WordflowTests(unittest.TestCase):
    def test_local_service_only_allows_extension_origins(self):
        self.assertTrue(is_allowed_origin(""))
        self.assertTrue(is_allowed_origin("chrome-extension://abc123"))
        self.assertTrue(is_allowed_origin("moz-extension://abc123"))
        self.assertFalse(is_allowed_origin("https://example.com"))
        self.assertFalse(is_allowed_origin("null"))

    def test_local_service_requires_client_header(self):
        self.assertTrue(is_valid_client_header("wordflow-local"))
        self.assertFalse(is_valid_client_header(""))
        self.assertFalse(is_valid_client_header("browser"))

    def test_running_quick_window_is_signalled_instead_of_reopened(self):
        with patch("server.subprocess.run") as process, patch("server.os.kill") as kill:
            process.return_value.stdout = "/installed/Wordflow Quick Add.app/Contents/MacOS/WordflowQuickAdd\n"
            with patch("pathlib.Path.read_text", return_value="4242\n"):
                self.assertTrue(
                    signal_quick_add_window(
                        Path("/installed/Wordflow Quick Add.app"),
                        Path("/tmp/wordflow-test.pid"),
                    )
                )
        self.assertEqual(kill.call_count, 2)

    def test_keychain_lookup_includes_the_current_account(self):
        result = MagicMock(stdout="secret\n")
        with (
            patch("wordflow.sys.platform", "darwin"),
            patch("wordflow.getpass.getuser", return_value="aurelia"),
            patch("wordflow.subprocess.run", return_value=result) as run,
        ):
            self.assertEqual(keychain_secret("com.wordflow.openai"), "secret")
        self.assertEqual(
            run.call_args.args[0],
            [
                "security",
                "find-generic-password",
                "-a",
                "aurelia",
                "-s",
                "com.wordflow.openai",
                "-w",
            ],
        )

    def test_capture_is_cleaned_and_bounded(self):
        capture = normalize_capture({"text": "  meticulous \n", "context": "A   careful sentence."})
        self.assertEqual(capture["text"], "meticulous")
        self.assertEqual(capture["context"], "A careful sentence.")

    def test_empty_and_long_selection_are_rejected(self):
        with self.assertRaises(ValueError):
            normalize_capture({"text": ""})
        with self.assertRaises(ValueError):
            normalize_capture({"text": "x" * 121})

    def test_deck_name_is_validated(self):
        self.assertEqual(normalize_deck_name("  English   from real life  "), "English from real life")
        with self.assertRaises(ValueError):
            normalize_deck_name("")

    def test_responses_output_text_is_extracted(self):
        response = {
            "output": [
                {
                    "type": "message",
                    "content": [{"type": "output_text", "text": '{"word":"test"}'}],
                }
            ]
        }
        self.assertEqual(extract_response_text(response), '{"word":"test"}')

    def test_html_is_escaped(self):
        self.assertEqual(html_items(["a < b"]), "<ul><li>a &lt; b</li></ul>")

    def test_identity_uses_lemma_and_part_of_speech(self):
        noun = identity_tag({"lemma": "record", "part_of_speech": "noun"})
        verb = identity_tag({"lemma": "record", "part_of_speech": "verb"})
        self.assertNotEqual(noun, verb)

    def test_mock_capture_and_duplicate_detection(self):
        app = WordflowApp(mock_config())
        payload = {"text": "Meticulous", "context": "She is meticulous about details."}
        first = app.capture(payload)
        second = app.capture(payload)
        self.assertTrue(first["ok"])
        self.assertFalse(first["duplicate"])
        self.assertTrue(second["duplicate"])
        self.assertIn("[…]", first["card"]["context_cloze"])

    def test_selected_deck_is_persisted_and_used_for_capture(self):
        with tempfile.TemporaryDirectory() as directory:
            preferences = Path(directory) / "preferences.json"
            app = WordflowApp(mock_config(), preferences_path=preferences)
            app.anki.deck_names = lambda: ["English from real life", "Test Deck"]
            selected = app.select_deck({"deck": "English from real life"})
            result = app.capture({"text": "lucid", "deck": selected["selected"]})

            restored = WordflowApp(mock_config(), preferences_path=preferences)
            restored.anki.deck_names = lambda: ["English from real life", "Test Deck"]
            self.assertEqual(restored.decks()["selected"], "English from real life")
            self.assertEqual(result["deck"], "English from real life")

    def test_anki_model_check_is_cached(self):
        client = AnkiClient(replace(mock_config(), mock_anki=False))
        calls = []

        def invoke(action, **_params):
            calls.append(action)
            return {"deckNames": ["Test Deck"], "modelNames": ["Test Model"]}[action]

        client.invoke = invoke
        client.ensure_model()
        client.ensure_model()
        self.assertEqual(calls, ["deckNames", "modelNames"])

    def test_generation_uses_latency_reasoning_setting(self):
        capture = normalize_capture({"text": "lucid", "context": "A lucid explanation."})
        card = {
            "word": "lucid",
            "lemma": "lucid",
            "pronunciation": "/ˈluːsɪd/",
            "part_of_speech": "adjective",
            "meaning_zh": "清晰的",
            "definition_en": "clear and easy to understand",
            "context": capture["context"],
            "context_cloze": "A […] explanation.",
            "collocations": ["lucid explanation", "lucid account"],
            "etymology": "from Latin lucidus",
            "memory_hook": "Think of light making an idea clear.",
            "examples": ["Her answer was lucid.", "He gave a lucid account."],
            "tags": ["adjective"],
        }
        response = {
            "output": [
                {
                    "type": "message",
                    "content": [{"type": "output_text", "text": json.dumps(card)}],
                }
            ]
        }
        config = replace(mock_config(), mock_openai=False, openai_api_key="test-key")
        with patch("wordflow._request_json", return_value=response) as request_json:
            OpenAICardGenerator(config).generate(capture)
        payload = request_json.call_args.args[1]
        self.assertEqual(payload["reasoning"], {"effort": "none"})
        self.assertEqual(payload["max_output_tokens"], 1400)

    def test_remote_disconnect_is_retried_and_names_the_service(self):
        with (
            patch(
                "wordflow.urllib.request.urlopen",
                side_effect=RemoteDisconnected("Remote end closed connection without response"),
            ) as urlopen,
            patch("wordflow.time.sleep") as sleep,
        ):
            with self.assertRaisesRegex(RuntimeError, "OpenAI.*自动重试"):
                _request_json(
                    "https://example.invalid/v1/responses",
                    {"input": "test"},
                    {},
                    service_name="OpenAI",
                    retries=1,
                )
        self.assertEqual(urlopen.call_count, 2)
        sleep.assert_called_once()

    def test_anki_disconnect_has_actionable_message(self):
        with patch(
            "wordflow.DIRECT_OPENER.open",
            side_effect=RemoteDisconnected("Remote end closed connection without response"),
        ):
            with self.assertRaisesRegex(RuntimeError, "AnkiConnect.*Anki 已完全启动"):
                _request_json(
                    "http://127.0.0.1:8765",
                    {"action": "version", "version": 6},
                    {},
                    service_name="AnkiConnect",
                    bypass_proxy=True,
                )

    def test_anki_requests_explicitly_bypass_system_proxy(self):
        client = AnkiClient(replace(mock_config(), mock_anki=False))
        response = MagicMock()
        response.__enter__.return_value.read.return_value = b'{"result": 6, "error": null}'
        with (
            patch("wordflow.DIRECT_OPENER.open", return_value=response) as direct_open,
            patch("wordflow.urllib.request.urlopen") as proxied_open,
        ):
            self.assertEqual(client.invoke("version"), 6)
        direct_open.assert_called_once()
        proxied_open.assert_not_called()

    def test_card_colors_meet_aa_contrast_in_light_and_dark_modes(self):
        light_block = re.search(r"\.card\s*\{(.*?)\n\}", CARD_CSS, re.DOTALL)
        dark_block = re.search(r"\.card\.nightMode,\s*\n\.nightMode \.card\s*\{(.*?)\n\}", CARD_CSS, re.DOTALL)
        self.assertIsNotNone(light_block)
        self.assertIsNotNone(dark_block)

        def variables(block):
            return dict(re.findall(r"--(wf-[\w-]+):\s*(#[0-9a-fA-F]{6})", block.group(1)))

        for palette in (variables(light_block), variables(dark_block)):
            for foreground in ("wf-text", "wf-muted", "wf-accent"):
                with self.subTest(foreground=foreground, background="wf-bg"):
                    self.assertGreaterEqual(contrast_ratio(palette[foreground], palette["wf-bg"]), 4.5)
            self.assertGreaterEqual(contrast_ratio(palette["wf-text"], palette["wf-surface"]), 4.5)


if __name__ == "__main__":
    unittest.main()
