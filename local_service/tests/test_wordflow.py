import os
import re
import sys
import unittest
from pathlib import Path


SERVICE_DIR = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(SERVICE_DIR))

from wordflow import (  # noqa: E402
    AnkiClient,
    CARD_CSS,
    Config,
    WordflowApp,
    extract_response_text,
    html_items,
    identity_tag,
    normalize_capture,
)


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
    def test_capture_is_cleaned_and_bounded(self):
        capture = normalize_capture({"text": "  meticulous \n", "context": "A   careful sentence."})
        self.assertEqual(capture["text"], "meticulous")
        self.assertEqual(capture["context"], "A careful sentence.")

    def test_empty_and_long_selection_are_rejected(self):
        with self.assertRaises(ValueError):
            normalize_capture({"text": ""})
        with self.assertRaises(ValueError):
            normalize_capture({"text": "x" * 121})

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
