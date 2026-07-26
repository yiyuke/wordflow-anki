<p align="center">
  <img src="assets/wordflow-logo.png" alt="Wordflow logo" width="120">
</p>

<h1 align="center">Wordflow</h1>

<p align="center"><strong>Do not memorize someone else's word list. Remember the words you actually meet.</strong></p>
<p align="center">Collect → Understand → Review → Use</p>

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

## Anki remembers when you should review. Wordflow creates what you should review.

[Anki](https://apps.ankiweb.net/) is a flashcard app built around spaced repetition. It brings a card back just before you are likely to forget it, helping knowledge move into long-term memory.

Anki is excellent at reviewing—but making a useful vocabulary card is still slow. Wordflow lets you select or type a word, understands it in its original context, creates a compact learning card, and sends it straight to Anki.

```text
Meet a word → Capture it once → Review before it fades → Use it
```

We believe this is the best way to build vocabulary: not by memorizing a list detached from your life, but by keeping the words you genuinely encounter, understanding them in context, and revisiting them at the right time.

## Why it feels different

- **Real context, not an isolated definition.** The sentence and source stay with the word.
- **An explanation that fits the expression.** A word, idiom, phrasal verb, and abstract concept are handled differently.
- **Almost no interruption.** Select and right-click, or open Quick Add from any app with `Option + Shift + W`.
- **Active recall in both directions.** Every note creates recognition and production cards.

Wordflow adds pronunciation, a clear meaning, 2–3 useful collocations, 1–2 reusable examples, and one short learning note designed for that particular expression.

## Install

> Wordflow is currently an early macOS release. It requires Anki, AnkiConnect, a Chromium browser, Python 3, and your own OpenAI API key. The browser extension is loaded manually until a Chrome Web Store version is available.

### 1. Download

There is not yet a tagged release. For the current preview:

```bash
git clone https://github.com/yiyuke/wordflow-anki.git
cd wordflow-anki
```

Ordinary users do not need to fork the repository. Fork only if you want to change the code or contribute.

### 2. Install AnkiConnect

1. Install and open [Anki](https://apps.ankiweb.net/).
2. Open **Tools → Add-ons → Get Add-ons**.
3. Enter `2055492159`, then restart Anki.

### 3. Install Wordflow

1. Double-click `install.command`.
2. Double-click the installed `configure-api-key.command` and paste your [OpenAI API key](https://platform.openai.com/api-keys).
3. If macOS blocks a script, Control-click it, choose **Open**, and confirm once.

### 4. Load the browser extension

1. Open `arc://extensions` or `chrome://extensions`.
2. Enable **Developer mode** and choose **Load unpacked**.
3. Select `~/Library/Application Support/Wordflow/extension`.

## Use

| What you want to do | Action |
| --- | --- |
| Capture selected text in Arc or Chrome | Right-click **Add to Anki**, or press `Option + Shift + A` |
| Type a word from a PDF, Word, video, or podcast | Press `Option + Shift + W` |
| Choose an Anki deck | Press `Command + D` in Quick Add |
| Save and keep typing | Press `Enter` |
| Save and return to the previous app | Press `Command + Enter` |
| Pin or close Quick Add | Press `Command + P` or `Esc` |

Choose `Auto / 中文 / English` in Quick Add to change both the interface and the explanation language. New cards start in `Vocabulary Inbox`; Wordflow remembers later deck choices.

## Privacy and cost

Wordflow has no account, analytics, advertising, or developer-operated server. Your word and limited context go directly from your Mac to the OpenAI API; the finished card stays in your Anki collection.

Every installation uses its own OpenAI API key and pays for its own usage. The key is stored in macOS Keychain and is never included in this repository. See [PRIVACY.md](PRIVACY.md) and [SECURITY.md](SECURITY.md).

<details>
<summary><strong>How Wordflow works</strong></summary>

```text
Arc / Chrome extension ─┐
Native Quick Add window ├─→ Local Wordflow service → OpenAI API
Desktop / PDF input ────┘                         ↓
                                                AnkiConnect → Anki
```

Wordflow listens only on `127.0.0.1`. A strict JSON Schema keeps cards compact while the model chooses the most helpful explanation strategy. Li Jigang's [`ljg-word` Skill](https://github.com/lijigang/ljg-skills/blob/master/skills/ljg-word/SKILL.md) inspired one optional image-to-meaning technique; it is not a runtime dependency.

</details>

<details>
<summary><strong>Update, uninstall, and development</strong></summary>

To update, run `git pull`, run `install.command` again, and reload the extension. To uninstall, double-click `uninstall.command`; existing Anki cards remain untouched.

```bash
python3 -m unittest discover -s local_service/tests -v
node --check extension/service-worker.js
node --check extension/content.js
node --check extension/popup.js
native/build-app.sh
```

See [CONTRIBUTING.md](CONTRIBUTING.md), [CHANGELOG.md](CHANGELOG.md), and the [launch kit](docs/LAUNCH.md).

</details>

## License

[MIT](LICENSE)
