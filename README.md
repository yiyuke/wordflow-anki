<p align="center">
  <img src="assets/wordflow-logo.png" alt="Wordflow logo" width="132">
</p>

<h1 align="center">Wordflow</h1>

<p align="center"><strong>Catch a word before it slips away.</strong></p>
<p align="center">Turn words you meet into Anki cards you can actually remember.</p>

<p align="center">
  <strong>English</strong> · <a href="README.zh-CN.md">简体中文</a>
</p>

<p align="center">
  <img alt="macOS" src="https://img.shields.io/badge/macOS-12%2B-111827?logo=apple">
  <img alt="Arc and Chrome" src="https://img.shields.io/badge/Arc%20%2F%20Chrome-Chromium-067647?logo=googlechrome">
  <img alt="Anki" src="https://img.shields.io/badge/Anki-AnkiConnect-2563eb">
  <img alt="License" src="https://img.shields.io/badge/license-MIT-475467">
</p>

---

## Why I built Wordflow

Vocabulary often falls through the gap between **meeting a word** and **remembering it**.

- A vocabulary book can supply hundreds of words, yet words learned without a personal context are easy to forget.
- A word found in a novel, video, article, or podcast is more meaningful—but it can disappear before you turn it into something reviewable. By the next encounter, it already feels unfamiliar again.
- Anki is excellent at scheduling reviews, but creating a good note is still manual. The useful meaning, explanation, context, collocations, and examples also change from one expression to another.

Wordflow was built to close that gap. It captures a word while the context is still fresh, creates a compact explanation suited to that particular word or phrase, and sends it directly to Anki.

```text
Collect → Understand → Review → Use
```

The goal is not to collect a larger word list. It is to build a repeatable path from encountering a word to being able to use it.

## Why Wordflow

- **Capture in seconds.** Right-click a selection or use a keyboard shortcut.
- **Keep the real context.** The sentence, page title, and source stay with the card.
- **Get an explanation that fits.** A word, idiom, phrasal verb, and abstract concept do not receive the same forced template.
- **Review in both directions.** Each note creates recognition and production cards.
- **Stay in your flow.** The compact native window can stay on top and works without a mouse.
- **Keep your own Anki system.** Choose any deck and use the included light or dark card theme.
- **Use English or Chinese.** `Auto / 中文 / English` changes both the interface and explanation language.

## What it is

Wordflow is a local macOS workflow, not a cloud account:

```text
Arc / Chrome extension ─┐
Native Quick Add window ├─→ Local Wordflow service → OpenAI API
Desktop / PDF input ────┘                         ↓
                                                AnkiConnect → Anki
```

The browser extension captures the word and context. The local service creates the card content. AnkiConnect writes the note and its two cards into Anki. Wordflow listens only on `127.0.0.1`.

## Project status

Wordflow is an early open-source macOS release. It is ready for personal use and testing, but installation is still more technical than a normal App Store product:

- the browser extension must currently be loaded manually;
- macOS may ask you to approve unsigned local scripts;
- Anki and AnkiConnect are required;
- each user supplies and pays for their own OpenAI API key.

A Chrome Web Store listing and a simpler signed installer are future distribution steps.

## Requirements

- macOS 12 or later
- [Anki Desktop](https://apps.ankiweb.net/)
- Arc, Chrome, Edge, or another Chromium browser
- Python 3
- An [OpenAI API key](https://platform.openai.com/api-keys) — API billing is separate from a ChatGPT subscription
- Optional: Xcode Command Line Tools for the native Quick Add window; Wordflow falls back to a browser window when Swift is unavailable

## Download, clone, or fork?

Most users should **not fork the repository**. Forking is for people who want their own development copy or plan to contribute code.

There is not yet a tagged public release. For the current source preview, clone the repository and follow the installation steps below. Once the first GitHub Release is published, ordinary users should download that release instead.

An AI coding assistant can follow this README and help with installation, but it is optional. The user must still approve macOS prompts, install AnkiConnect, provide their own API key, and load the unpacked extension until a store version is available.

## Install

### 1. Download Wordflow

```bash
git clone https://github.com/yiyuke/wordflow-anki.git
cd wordflow-anki
```

### 2. Install AnkiConnect

1. Install and open [Anki](https://apps.ankiweb.net/).
2. Go to **Tools → Add-ons → Get Add-ons**.
3. Enter the AnkiConnect code `2055492159`.
4. Restart Anki.

Keep AnkiConnect on its default local address, `127.0.0.1:8765`. Its source and documentation are available at [AnkiConnect](https://git.sr.ht/~foosoft/anki-connect).

### 3. Install the local service

Double-click `install.command`. Then double-click the installed `configure-api-key.command` and paste your OpenAI API key. The key is stored in macOS Keychain and is never committed to the repository.

If macOS blocks a script, Control-click it, choose **Open**, and confirm once.

### 4. Load the extension

Until Wordflow is published in the Chrome Web Store:

1. Open `arc://extensions` or `chrome://extensions`.
2. Enable **Developer mode**.
3. Choose **Load unpacked**.
4. Select `~/Library/Application Support/Wordflow/extension`.

Arc can install Chrome Web Store extensions directly, so a future store release will work in both Arc and Chrome.

## Use

- Select a word on a webpage and choose **Add to Anki** from the context menu.
- Press `Option + Shift + A` to capture the current browser selection.
- Press `Option + Shift + W` to open Quick Add from Word, PDFs, podcast notes, or any other app.
- Press `Command + D` in Quick Add to choose a deck.
- Choose `Auto / 中文 / English` at the top right. `Auto` follows Arc/Chrome or macOS; a manual choice is remembered.
- Press `Command + A` in either input to select all text.
- Press `Enter` to save and keep typing.
- Press `Command + Enter` to save, leave the pinned card visible, and return focus to the previous app.
- Press `Command + P` to pin or unpin the window; press `Esc` to close it.

New cards default to `Vocabulary Inbox`. Wordflow remembers later deck choices. A deck named `Default` is Anki's real built-in deck. If a shortcut conflicts with another extension, change it at `arc://extensions/shortcuts` or `chrome://extensions/shortcuts` and set the manual input shortcut to **Global**.

## What goes into a card

- Complete selected word or phrase, plus its dictionary lemma
- IPA pronunciation
- Concise meaning in English or Simplified Chinese
- Learner-friendly English definition
- Original context and a cloze version
- 2–3 useful collocations
- One compact learning note that can use imagery, semantic transfer, reliable etymology, usage contrast, register, grammar, or phrase logic when useful
- 1–2 natural, reusable examples
- Source title and URL
- Optional OpenAI TTS audio

Duplicate detection uses the lemma and part of speech. Each note creates a **Recognition** card and a **Production** card.

At runtime, Wordflow does not execute a Codex Skill. The local service sends a Wordflow-owned prompt, the selected text, and its context to the OpenAI Responses API. A strict JSON Schema fixes the card shape and content budget; the model chooses the most useful explanation strategy within it. Li Jigang's [`ljg-word` Skill](https://github.com/lijigang/ljg-skills/blob/master/skills/ljg-word/SKILL.md) inspired the optional image-to-meaning technique, but it is neither a runtime dependency nor a required template.

## Privacy and API billing

Wordflow has no account, analytics, advertising, or developer-operated server. The selected text, a bounded amount of nearby context, and the page title are sent directly from your Mac to the OpenAI API. The page URL is stored in your local Anki note but is not included in the generation request. Requests use `store: false`.

Each installation uses the API key configured on that person's Mac. Your key is stored in macOS Keychain, ignored by Git, and never distributed through this repository. Other users use and pay for their own OpenAI API usage.

See [PRIVACY.md](PRIVACY.md) for the complete disclosure and permission rationale. Please report sensitive security problems privately as described in [SECURITY.md](SECURITY.md).

## Update and uninstall

To update, run `git pull`, run `install.command` again, then click **Reload** on the browser extensions page.

To uninstall, double-click `uninstall.command`. Existing Anki cards remain untouched. The script does not automatically remove the browser extension or Keychain API key.

## Development

```bash
python3 -m unittest discover -s local_service/tests -v
node --check extension/service-worker.js
node --check extension/content.js
node --check extension/popup.js
native/build-app.sh
```

Contributions and bug reports are welcome. See [CONTRIBUTING.md](CONTRIBUTING.md), the [launch kit](docs/LAUNCH.md), and the [changelog](CHANGELOG.md).

## License

[MIT](LICENSE)
