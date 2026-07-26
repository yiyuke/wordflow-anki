import json
import os
import re
import struct
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
    CARD_TEMPLATES,
    CARD_CSS,
    Config,
    LEGACY_RECOGNITION_BACK,
    OpenAICardGenerator,
    WordflowApp,
    _request_json,
    extract_response_text,
    html_examples,
    html_inline_items,
    html_items,
    identity_tag,
    keychain_secret,
    normalize_card,
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

    def test_store_manifest_uses_on_demand_page_access(self):
        extension_dir = SERVICE_DIR.parent / "extension"
        manifest = json.loads((extension_dir / "manifest.json").read_text(encoding="utf-8"))
        worker = (extension_dir / "service-worker.js").read_text(encoding="utf-8")
        self.assertEqual(manifest["version"], "0.8.0")
        self.assertEqual(
            set(manifest["permissions"]),
            {"contextMenus", "storage", "activeTab", "scripting"},
        )
        self.assertNotIn("tabs", manifest["permissions"])
        self.assertNotIn("content_scripts", manifest)
        self.assertNotIn("<all_urls>", json.dumps(manifest))
        self.assertEqual(
            manifest["host_permissions"],
            ["http://127.0.0.1:8766/*", "http://localhost:8766/*"],
        )
        self.assertFalse((extension_dir / "content.js").exists())
        self.assertIn("chrome.scripting.executeScript", worker)
        self.assertIn("func: readSelectionContext", worker)
        self.assertIn("func: renderResultToast", worker)

    def test_store_submission_kit_has_privacy_copy_review_mode_and_exact_assets(self):
        root = SERVICE_DIR.parent
        privacy = (root / "PRIVACY.md").read_text(encoding="utf-8")
        submission = (root / "docs" / "CHROME_WEB_STORE.md").read_text(encoding="utf-8")
        review_mode = root / "scripts" / "start-review-mode.command"
        self.assertIn("Limited Use requirements", privacy)
        self.assertIn("activeTab", privacy)
        self.assertIn("scripting", privacy)
        self.assertIn("Single purpose", submission)
        self.assertIn("Permission justifications", submission)
        self.assertIn("Reviewer test instructions", submission)
        self.assertIn("MOCK_OPENAI=1", review_mode.read_text(encoding="utf-8"))
        self.assertTrue(review_mode.stat().st_mode & 0o111)

        expected_sizes = {
            "icon-128.png": (128, 128),
            "small-promo-440x280.png": (440, 280),
            "marquee-promo-1400x560.png": (1400, 560),
            "screenshot-capture-en-1280x800.png": (1280, 800),
            "screenshot-capture-zh-1280x800.png": (1280, 800),
            "screenshot-quick-add-en-1280x800.png": (1280, 800),
            "screenshot-quick-add-zh-1280x800.png": (1280, 800),
        }
        for filename, expected in expected_sizes.items():
            data = (root / "assets" / "chrome-web-store" / filename).read_bytes()
            self.assertEqual(data[:8], b"\x89PNG\r\n\x1a\n")
            self.assertEqual(struct.unpack(">II", data[16:24]), expected)

    def test_browser_fallback_uses_accessible_below_trigger_dropdowns(self):
        extension_dir = SERVICE_DIR.parent / "extension"
        markup = (extension_dir / "popup.html").read_text(encoding="utf-8")
        styling = (extension_dir / "popup.css").read_text(encoding="utf-8")
        script = (extension_dir / "popup.js").read_text(encoding="utf-8")
        self.assertEqual(markup.count('role="combobox"'), 2)
        self.assertEqual(markup.count('role="listbox"'), 2)
        self.assertIn("top: calc(100% + 7px)", styling)
        self.assertIn("position: absolute", styling)
        self.assertIn("input:focus-visible", styling)
        self.assertIn("border-color: #067647", styling)
        self.assertIn("0 0 0 2px rgba(6, 118, 71, .14)", styling)
        self.assertIn("::selection { color: #101828; background: #e8f5ed; }", styling)
        self.assertIn('select-option[aria-selected="true"] { color: #067647; background: #ecfdf3;', styling)
        self.assertNotIn("#175cd3", styling)
        self.assertNotIn("#eff4ff", styling)
        self.assertIn('setupSelect("language")', script)
        self.assertIn('setupSelect("deck")', script)

    def test_native_quick_add_uses_brand_green_without_changing_success_green(self):
        source = (SERVICE_DIR.parent / "native" / "WordflowQuickAdd.swift").read_text(encoding="utf-8")
        self.assertIn("addButton.bezelColor = Brand.primary", source)
        self.assertIn("textView.insertionPointColor = Brand.primary", source)
        self.assertIn(".backgroundColor: Brand.selectionBackground", source)
        self.assertIn("pinButton.contentTintColor = pinned ? Brand.primary", source)
        self.assertIn("pinButton.setButtonType(.momentaryChange)", source)
        self.assertIn("Brand.primary.withAlphaComponent(isDark ? 0.9 : 0.62)", source)
        self.assertIn("layer?.borderWidth = 1", source)
        self.assertIn("color: success ? .systemGreen : .systemRed", source)
        self.assertNotIn(".controlAccentColor", source)
        info = (SERVICE_DIR.parent / "native" / "Info.plist").read_text(encoding="utf-8")
        build_script = (SERVICE_DIR.parent / "native" / "build-app.sh").read_text(encoding="utf-8")
        self.assertIn("<key>NSAccentColorName</key>", info)
        self.assertIn("<string>AccentColor</string>", info)
        self.assertIn("xcrun actool", build_script)

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
        self.assertEqual(capture["language"], "zh")

    def test_capture_accepts_english_explanations(self):
        capture = normalize_capture({"text": "lucid", "language": "en"})
        self.assertEqual(capture["language"], "en")
        fallback = normalize_capture({"text": "lucid", "language": "unsupported"})
        self.assertEqual(fallback["language"], "zh")

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

    def test_compact_card_items_are_escaped_without_section_labels(self):
        collocations = html_inline_items(["light < fog", "lucid explanation"])
        examples = html_examples(["Her answer was <lucid>."])
        self.assertIn("class='collocation'", collocations)
        self.assertIn("light &lt; fog", collocations)
        self.assertIn("class='example'", examples)
        self.assertIn("&lt;lucid&gt;", examples)
        self.assertNotIn("<ul>", collocations)

    def test_compact_template_has_one_learning_flow(self):
        recognition_back = CARD_TEMPLATES[0]["Back"]
        self.assertIn("wordflow-managed:3", recognition_back)
        self.assertIn("class='learning-note'", recognition_back)
        self.assertNotIn("Word insight", recognition_back)
        self.assertNotIn("{{Etymology}}", recognition_back)
        self.assertNotIn("class='label'", recognition_back)

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

    def test_language_preference_is_persisted(self):
        with tempfile.TemporaryDirectory() as directory:
            preferences = Path(directory) / "preferences.json"
            app = WordflowApp(mock_config(), preferences_path=preferences)
            self.assertEqual(app.settings()["language"], "auto")
            self.assertEqual(app.select_language({"language": "en"})["language"], "en")
            restored = WordflowApp(mock_config(), preferences_path=preferences)
            self.assertEqual(restored.settings()["language"], "en")
            with self.assertRaises(ValueError):
                app.select_language({"language": "unsupported"})

    def test_multiword_capture_keeps_the_complete_phrase(self):
        capture = normalize_capture(
            {
                "text": "chimed in",
                "context": "Somebody suddenly chimed in.",
                "language": "en",
            }
        )
        model_card = {
            "word": "chimed",
            "lemma": "chime",
            "context_cloze": "Somebody suddenly […] in.",
        }
        card = normalize_card(model_card, capture)
        self.assertEqual(card["word"], "chimed in")
        self.assertEqual(card["lemma"], "chimed in")
        self.assertEqual(card["context_cloze"], "Somebody suddenly […].")

    def test_anki_model_check_is_cached(self):
        client = AnkiClient(replace(mock_config(), mock_anki=False))
        calls = []

        def invoke(action, **_params):
            calls.append(action)
            return {
                "deckNames": ["Test Deck"],
                "modelNames": ["Test Model"],
                "modelTemplates": {
                    template["Name"]: {
                        "Front": template["Front"],
                        "Back": template["Back"],
                    }
                    for template in CARD_TEMPLATES
                },
                "modelStyling": {"css": CARD_CSS},
            }[action]

        client.invoke = invoke
        client.ensure_model()
        client.ensure_model()
        self.assertEqual(calls, ["deckNames", "modelNames", "modelTemplates", "modelStyling"])

    def test_legacy_wordflow_template_is_upgraded(self):
        client = AnkiClient(replace(mock_config(), mock_anki=False))
        calls = []
        legacy_templates = {
            template["Name"]: {
                "Front": template["Front"],
                "Back": template["Back"],
            }
            for template in CARD_TEMPLATES
        }
        legacy_templates["Recognition"]["Back"] = LEGACY_RECOGNITION_BACK

        def invoke(action, **params):
            calls.append((action, params))
            return {
                "modelTemplates": legacy_templates,
                "modelStyling": {"css": "legacy css"},
                "updateModelTemplates": None,
                "updateModelStyling": None,
            }[action]

        client.invoke = invoke
        client._sync_managed_model()
        self.assertEqual(
            [action for action, _params in calls],
            ["modelTemplates", "updateModelTemplates", "modelStyling", "updateModelStyling"],
        )

    def test_custom_anki_template_is_not_overwritten(self):
        client = AnkiClient(replace(mock_config(), mock_anki=False))
        calls = []

        def invoke(action, **_params):
            calls.append(action)
            return {
                "Recognition": {"Front": "My custom front", "Back": "My custom back"},
                "Production": {"Front": "My custom production", "Back": "My custom answer"},
            }

        client.invoke = invoke
        client._sync_managed_model()
        self.assertEqual(calls, ["modelTemplates"])

    def test_new_cards_store_one_compact_learning_note(self):
        client = AnkiClient(replace(mock_config(), mock_anki=False))
        client.ensure_model = lambda _deck=None: None
        added = {}

        def invoke(action, **params):
            if action == "findNotes":
                return []
            if action == "addNote":
                added.update(params["note"])
                return 123
            raise AssertionError(action)

        client.invoke = invoke
        result = client.add_card(
            {
                "word": "incubate",
                "lemma": "incubate",
                "pronunciation": "/ˈɪŋkjəbeɪt/",
                "part_of_speech": "verb",
                "meaning_zh": "培育",
                "definition_en": "to help something develop",
                "context": "They incubate ideas.",
                "context_cloze": "They […] ideas.",
                "collocations": ["incubate an idea", "incubate a startup"],
                "learning_note": "让想法像蛋一样，在支持和时间中逐渐成熟。",
                "examples": ["The lab incubates new ideas."],
                "tags": ["verb"],
            },
            {
                "source_type": "test",
                "source_title": "Test",
                "source_url": "",
                "language": "zh",
            },
            deck_name="Test Deck",
        )
        self.assertEqual(result["note_id"], 123)
        self.assertEqual(added["fields"]["Etymology"], "")
        self.assertEqual(added["fields"]["MemoryHook"], "让想法像蛋一样，在支持和时间中逐渐成熟。")
        self.assertIn("class='collocation'", added["fields"]["Collocations"])
        self.assertIn("class='example'", added["fields"]["Examples"])
        self.assertNotIn("insight-item", added["fields"]["MemoryHook"])

    def test_generation_uses_latency_reasoning_setting(self):
        capture = normalize_capture({"text": "lucid", "context": "A lucid explanation.", "language": "en"})
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
            "learning_note": "From Latin lux, light: a lucid idea feels mentally illuminated rather than merely simple.",
            "examples": ["Her answer was lucid."],
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
        self.assertEqual(payload["max_output_tokens"], 1100)
        self.assertIn("explanation language is English", payload["input"][0]["content"])
        self.assertIn("learning_note", payload["text"]["format"]["schema"]["required"])
        self.assertNotIn("original_image", payload["text"]["format"]["schema"]["required"])
        self.assertEqual(payload["text"]["format"]["schema"]["properties"]["collocations"]["minItems"], 2)
        self.assertEqual(payload["text"]["format"]["schema"]["properties"]["collocations"]["maxItems"], 3)
        self.assertEqual(payload["text"]["format"]["schema"]["properties"]["examples"]["minItems"], 1)
        self.assertEqual(payload["text"]["format"]["schema"]["properties"]["examples"]["maxItems"], 2)
        self.assertIn("Adapt learning_note", payload["input"][0]["content"])
        user_input = json.loads(payload["input"][1]["content"])
        self.assertEqual(user_input["explanation_language"], "en")

    def test_normalization_caps_repetition_and_content_counts(self):
        capture = normalize_capture(
            {"text": "lucid", "context": "Her explanation was lucid.", "language": "en"}
        )
        card = normalize_card(
            {
                "lemma": "lucid",
                "collocations": ["lucid prose", "Lucid prose", "lucid dream", "lucid account"],
                "examples": [
                    "Her explanation was lucid.",
                    "His answer was lucid.",
                    "She gave a lucid account.",
                ],
                "tags": ["clear", "clear", "adjective"],
            },
            capture,
        )
        self.assertEqual(card["collocations"], ["lucid prose", "lucid dream", "lucid account"])
        self.assertEqual(card["examples"], ["His answer was lucid.", "She gave a lucid account."])
        self.assertEqual(card["tags"], ["clear", "adjective"])

    def test_remote_disconnect_is_retried_and_names_the_service(self):
        with (
            patch(
                "wordflow.urllib.request.urlopen",
                side_effect=RemoteDisconnected("Remote end closed connection without response"),
            ) as urlopen,
            patch("wordflow.time.sleep") as sleep,
        ):
            with self.assertRaisesRegex(RuntimeError, "网络连接失败，请稍后重试"):
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
            with self.assertRaisesRegex(RuntimeError, "Anki 未连接"):
                _request_json(
                    "http://127.0.0.1:8765",
                    {"action": "version", "version": 6},
                    {},
                    service_name="AnkiConnect",
                    bypass_proxy=True,
                )

    def test_safe_anki_request_launches_app_and_retries(self):
        client = AnkiClient(replace(mock_config(), mock_anki=False))
        responses = [
            RuntimeError("Anki 未连接"),
            {"result": 6, "error": None},
            {"result": ["Default"], "error": None},
        ]
        with (
            patch("wordflow.sys.platform", "darwin"),
            patch("wordflow._request_json", side_effect=responses) as request_json,
            patch("wordflow.subprocess.Popen") as launch,
            patch("wordflow.time.sleep") as sleep,
        ):
            self.assertEqual(client.invoke("deckNames"), ["Default"])
        launch.assert_called_once()
        sleep.assert_called_once_with(0.5)
        self.assertEqual(request_json.call_count, 3)

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
