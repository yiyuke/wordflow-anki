# Changelog

All notable changes to Wordflow are documented here.

## 0.7.0 — 2026-07-26

- Replaced the fixed multi-section Word Insight report with one adaptive, compact learning note.
- Lets the model choose the most useful explanation strategy for each word or phrase, including imagery, semantic transfer, reliable etymology, usage contrast, register, grammar, or phrase logic.
- Constrains each card to 2–3 useful collocations and 1–2 easy, reusable examples.
- Presents meaning, explanation, examples, and collocations as one continuous reading flow without labeled boxes.
- Keeps the existing Anki note fields for a safe, automatic template upgrade.

## 0.6.2 — 2026-07-26

- Added a structured Word Insight section: original image, core image, semantic explanation, and a memorable one-line summary.
- Tightened definition quality by requiring sense boundaries and separating factual etymology from mental pictures.
- Replaced the Pin checkbox and label with a compact toggleable pin icon.
- Clarified that `Default` is Anki's real built-in deck while Wordflow remembers the last selected deck.
- Safely upgrades Wordflow-managed Anki templates while leaving custom note-type templates untouched.

## 0.6.1 — 2026-07-26

- Made `Command + A` reliably select all text in either native input field.
- Added an `Auto / 中文 / English` language selector shared by the native window and browser fallback.
- Kept complete multiword expressions on the card front and in context cloze sentences, even when model output narrows them to one word.

## 0.6.0 — 2026-07-22

- Added automatic English and Simplified Chinese UI localization.
- Added English or Chinese card explanations based on the browser/macOS language.
- Added the Wordflow logo and browser extension icons.
- Added a bilingual public README, privacy disclosure, contribution guide, and launch kit.
- Added compact status expiration and predictable window-size reset.
- Kept deck selection, pinned keyboard-first input, and return-to-previous-app behavior.

## 0.5.3 — 2026-07-22

- Success messages now clear after six seconds; errors remain for ten seconds.
- Quick Add opens at a compact 468 × 411 frame and returns to that size after closing.

## 0.5.2

- `Command + Enter` saves and returns focus without closing the pinned window.

## 0.5.0

- Added native Quick Add, deck selection, keyboard navigation, automatic Anki launch, and safer local-service access.
