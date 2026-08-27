# Changelog

All notable changes to Wordflow are documented here.

## 0.9.0 — 2026-08-27

- Added persistent Full Learning and Exam Reading modes to both Quick Add interfaces.
- Exam Reading keeps only the expression's exact Chinese meaning in its sentence, with a smaller generation budget and no redundant notes, collocations, or examples.
- Tags cards by learning mode so the two workflows can be filtered and evaluated later.
- Fixed automatic Anki launch by targeting the installed app name instead of an obsolete bundle identifier.
- Waits up to 30 seconds for AnkiConnect and checks the note identity before retrying an interrupted addition, avoiding accidental duplicates.
- Made `Option + Shift + W` a true system-wide shortcut backed by the always-on native helper, so it also works from PDF and Word apps when Arc is not focused.
- Added a compact Help & Feedback button that checks the public repository for updates and turns into a highlighted download icon when a newer version is available.
- Moved Settings and Help/Updates into the macOS title bar, grouped learning mode, language, and the shortcut reference behind one gear menu, and removed repeated shortcut copy from the form.
- Replaced the GitHub Issues and email-app handoff with a bilingual two-field form that submits feedback directly through Formspree without collecting contact details.
- Made the installer safely install and restart the native helper at login, including on Macs with Command Line Tools but without full Xcode.

## 0.8.0 — 2026-07-26

- Replaced the always-on `<all_urls>` content script with temporary `activeTab` access and packaged on-demand scripts.
- Removed the broad `tabs` permission while preserving context capture, keyboard shortcuts, and result toasts.
- Added a bilingual Chrome Web Store privacy and Limited Use disclosure.
- Added a credential-free local review mode, complete submission copy, permission justifications, and reviewer test instructions.
- Added exact-size Chrome Web Store listing assets and a validated `0.8.0` extension package.
- Made a copyable, terminal-agent installation prompt the primary bilingual onboarding path while keeping the complete manual steps available in a collapsed section.

## 0.7.1 — 2026-07-26

- Increased the top breathing room on the browser fallback page.
- Replaced native language and deck selectors with accessible keyboard-friendly comboboxes whose menus open below their triggers without moving the form.
- Uses a restrained green focus state consistent with the primary action in light and dark modes.
- Unified the native Quick Add button, caret, focus border, selected text, shortcut label, Pin, and native menu accent around the Wordflow green palette while keeping success feedback brighter.
- Softened the text-selection wash and native focus border so the green state remains visible without competing with the content.
- Shortened the bilingual README around one clear idea: Anki schedules the review, and Wordflow creates the right material to review.

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
