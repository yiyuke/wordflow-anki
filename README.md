<p align="center">
  <img src="assets/wordflow-logo.png" alt="Wordflow logo" width="132">
</p>

<h1 align="center">Wordflow</h1>

<p align="center"><strong>Turn every new word into a review.</strong></p>
<p align="center">遇见生词，立刻变成记忆。</p>

<p align="center">
  <a href="#english">English</a> · <a href="#简体中文">简体中文</a>
</p>

<p align="center">
  <img alt="macOS" src="https://img.shields.io/badge/macOS-12%2B-111827?logo=apple">
  <img alt="Arc and Chrome" src="https://img.shields.io/badge/Arc%20%2F%20Chrome-Chromium-067647?logo=googlechrome">
  <img alt="Anki" src="https://img.shields.io/badge/Anki-AnkiConnect-2563eb">
  <img alt="License" src="https://img.shields.io/badge/license-MIT-475467">
</p>

---

## English

Wordflow removes the friction between encountering an English word and actually remembering it.

Select a word in Arc or Chrome—or type one from Word, a PDF, a podcast, or anywhere else. Wordflow uses the surrounding context to create a rich Anki note with pronunciation, a learner-friendly meaning, definition, collocations, careful etymology, a memory hook, and natural examples. It then adds both recognition and production cards to your chosen deck.

```text
See a word → Capture once → Review in Anki
```

### Why Wordflow

- **Capture in seconds.** Right-click a selection or use a keyboard shortcut.
- **Keep the original context.** Wordflow carries the sentence, page title, and source into the card.
- **Learn actively.** Every note creates recognition and production cards instead of a passive word list.
- **Stay in your flow.** The compact native window can stay on top and works without a mouse.
- **Use your own system.** Choose any Anki deck; light and dark card themes are included.
- **English and Chinese.** Use `Auto / 中文 / English` in Quick Add. Auto follows the browser/macOS language; a manual choice changes both the interface and card explanations.

### What it is

Wordflow is currently a local macOS workflow rather than a standalone cloud app:

```text
Arc / Chrome extension ─┐
Native Quick Add window ├─→ Local Wordflow service → OpenAI API
Desktop / PDF input ────┘                         ↓
                                                AnkiConnect → Anki
```

The browser extension captures words and context. A local service generates the card content. AnkiConnect writes the note and two cards into Anki. Wordflow itself only listens on `127.0.0.1`.

### Requirements

- macOS 12 or later
- [Anki Desktop](https://apps.ankiweb.net/)
- Arc, Chrome, Edge, or another Chromium browser
- Python 3
- An [OpenAI API key](https://platform.openai.com/api-keys) — API billing is separate from a ChatGPT subscription
- Optional: Xcode Command Line Tools for the native Quick Add window; Wordflow falls back to a browser window when Swift is unavailable

### Install

#### 1. Download Wordflow

Download the latest source archive from [Releases](https://github.com/yiyuke/wordflow-anki/releases), or clone the repository:

```bash
git clone https://github.com/yiyuke/wordflow-anki.git
cd wordflow-anki
```

#### 2. Install AnkiConnect

1. Install and open [Anki](https://apps.ankiweb.net/).
2. Go to **Tools → Add-ons → Get Add-ons**.
3. Enter the AnkiConnect code `2055492159`.
4. Restart Anki.

Keep AnkiConnect on its default local address, `127.0.0.1:8765`. Its source and documentation are available at [AnkiConnect](https://git.sr.ht/~foosoft/anki-connect).

#### 3. Install the local service

Double-click `install.command`, then double-click the installed `configure-api-key.command` and paste your OpenAI API key. The key is stored in macOS Keychain and is never committed to the repository.

If macOS blocks a script, Control-click it, choose **Open**, and confirm once.

#### 4. Load the extension

GitHub cannot provide one-click Chrome/Arc extension installation. Until Wordflow is published in the Chrome Web Store, load the trusted source folder manually:

1. Open `arc://extensions` or `chrome://extensions`.
2. Enable **Developer mode**.
3. Choose **Load unpacked**.
4. Select `~/Library/Application Support/Wordflow/extension`.

Arc can install Chrome Web Store extensions directly, so a future store release will work in both Arc and Chrome.

### Use

- Select a word on a webpage and choose **Add to Anki** from the context menu.
- Press `Option + Shift + A` to capture the current browser selection.
- Press `Option + Shift + W` to open Quick Add from Word, PDFs, podcast notes, or any other app.
- Press `Command + D` in Quick Add to choose a deck.
- Choose `Auto / 中文 / English` at the top right. `Auto` follows Arc/Chrome or macOS; a manual choice is remembered across the native and browser windows.
- Press `Command + A` in either input to select all of its text.
- Press `Enter` to save and keep typing.
- Press `Command + Enter` to save, leave the pinned card visible, and return focus to the previous app.
- Press `Command + P` to pin or unpin the window; press `Esc` to close it.

New cards default to `Vocabulary Inbox`. Wordflow remembers later deck choices. If a shortcut conflicts with another extension, change it at `arc://extensions/shortcuts` or `chrome://extensions/shortcuts` and set the manual input shortcut to **Global**.

### What goes into a card

- Complete selected word or phrase, plus its dictionary lemma
- IPA pronunciation
- Concise meaning in English or Simplified Chinese
- Learner-friendly English definition
- Original context and a cloze version
- Useful collocations
- Conservative etymology and a separate memory hook
- Two natural examples
- Source title and URL
- Optional OpenAI TTS audio

Duplicate detection uses the lemma and part of speech. Each note creates a **Recognition** card and a **Production** card.

### Privacy

Wordflow has no account, analytics, advertising, or developer-operated server. The selected text, a bounded amount of nearby context, and the page title are sent directly from your Mac to the OpenAI API to generate the card. The page URL is stored in your local Anki note but is not included in the OpenAI request. Requests use `store: false`.

See [PRIVACY.md](PRIVACY.md) for the complete bilingual disclosure and extension permission rationale.

### Update and uninstall

To update, run `git pull`, run `install.command` again, then click **Reload** on the browser extensions page.

To uninstall, double-click `uninstall.command`. Existing Anki cards remain untouched. The script does not automatically remove the browser extension or Keychain API key.

### Development

```bash
python3 -m unittest discover -s local_service/tests -v
node --check extension/service-worker.js
node --check extension/content.js
node --check extension/popup.js
native/build-app.sh
```

Contributions and bug reports are welcome. See [CONTRIBUTING.md](CONTRIBUTING.md), the [launch kit](docs/LAUNCH.md), and the [changelog](CHANGELOG.md).

---

## 简体中文

Wordflow 解决的是一个很小、但每天都会打断学习的问题：**看到生词以后，怎样马上把它变成真正会复习的内容？**

你可以在 Arc 或 Chrome 里选中单词，也可以从 Word、PDF、播客笔记或其他软件手动输入。Wordflow 会结合原句生成发音、释义、英文定义、搭配、可靠词源、记忆提示和自然例句，然后把它直接加入你选择的 Anki 牌组，并生成识别与回忆两张卡。

```text
遇见生词 → 捕捉一次 → 回到 Anki 复习
```

### 为什么用 Wordflow

- **几秒钟完成录词。** 选词右键，或者直接按快捷键。
- **保留真实语境。** 原句、页面标题和来源会一起进入卡片。
- **不是被动收藏。** 每条 Note 自动生成 Recognition 和 Production 两张卡。
- **不打断正在做的事。** 紧凑的原生窗口支持置顶和全键盘操作。
- **继续使用自己的 Anki。** 可以选择任意牌组，卡片支持浅色与深色模式。
- **中英双语。** 在快速窗口右上角选择 `自动 / 中文 / English`；自动模式跟随浏览器或 macOS，手动选择会同时切换界面与词卡解释。

### 它是什么

Wordflow 目前不是云端账号型 App，而是一套只在 Mac 本地运行的工作流：

```text
Arc / Chrome 扩展 ─┐
原生快速输入窗口 ──┼─→ Wordflow 本地服务 → OpenAI API
桌面 / PDF 输入 ───┘                         ↓
                                            AnkiConnect → Anki
```

浏览器扩展负责取词和上下文，本地服务负责生成卡片内容，AnkiConnect 负责把 Note 和两张卡写进 Anki。Wordflow 本身只监听 `127.0.0.1`。

### 系统要求

- macOS 12 或更高版本
- [Anki 桌面版](https://apps.ankiweb.net/)
- Arc、Chrome、Edge 或其他 Chromium 浏览器
- Python 3
- [OpenAI API Key](https://platform.openai.com/api-keys)；API 费用与 ChatGPT 订阅相互独立
- 可选：Xcode Command Line Tools，用于构建原生快速窗口；没有 Swift 时会自动使用浏览器备用窗口

### 安装

#### 1. 下载 Wordflow

从 [Releases](https://github.com/yiyuke/wordflow-anki/releases) 下载最新源码压缩包，或在终端运行：

```bash
git clone https://github.com/yiyuke/wordflow-anki.git
cd wordflow-anki
```

#### 2. 安装 AnkiConnect

1. 安装并打开 [Anki](https://apps.ankiweb.net/)。
2. 进入 **Tools → Add-ons → Get Add-ons**。
3. 输入 AnkiConnect 代码 `2055492159`。
4. 重启 Anki。

请保留 AnkiConnect 的默认本地地址 `127.0.0.1:8765`。项目说明和源码见 [AnkiConnect](https://git.sr.ht/~foosoft/anki-connect)。

#### 3. 安装本地服务

双击 `install.command`。安装完成后，再双击已安装目录中的 `configure-api-key.command`，粘贴 OpenAI API Key。Key 会保存在 macOS 钥匙串，不会写入 GitHub 仓库。

如果 macOS 阻止脚本运行，请按住 Control 点击文件，选择 **打开**，再确认一次。

#### 4. 加载浏览器扩展

GitHub 不能像扩展商店一样一键安装 Chrome/Arc 扩展。在 Wordflow 正式上架 Chrome Web Store 前，需要手动加载可信的源码目录：

1. 打开 `arc://extensions` 或 `chrome://extensions`。
2. 开启 **Developer mode**。
3. 点击 **Load unpacked / 加载已解压的扩展程序**。
4. 选择 `~/Library/Application Support/Wordflow/extension`。

Arc 可以直接使用 Chrome Web Store 扩展，因此未来只需发布一个商店版本。

### 使用

- 在网页选中单词，右键选择 **加入 Anki**。
- `Option + Shift + A`：捕捉浏览器当前选中的单词。
- `Option + Shift + W`：从 Word、PDF、播客笔记或其他 App 打开快速输入窗。
- `Command + D`：选择 Anki 牌组。
- 在右上角选择 `自动 / 中文 / English`：自动模式跟随 Arc/Chrome 或 macOS，手动选择会被原生窗口和浏览器窗口共同记住。
- 在任一输入框按 `Command + A`：全选当前输入框的内容。
- `Enter`：保存并继续输入。
- `Command + Enter`：保存后把焦点交回之前的 App；置顶窗口继续显示。
- `Command + P`：切换置顶；`Esc`：关闭窗口。

新卡默认加入 `Vocabulary Inbox`。之后选择的牌组会被记住。如果快捷键冲突，可在 `arc://extensions/shortcuts` 或 `chrome://extensions/shortcuts` 修改，并把手动输入快捷键设成 **Global**。

### 每张卡包含什么

- 完整保留选中的单词或短语，并附上字典原形
- IPA 发音
- 中文或英文简明释义
- 适合学习者的英文定义
- 原始上下文与挖空版本
- 常用搭配
- 谨慎处理的词源和独立的记忆提示
- 两个自然例句
- 来源标题与 URL
- 可选 OpenAI TTS 发音音频

查重使用 lemma + 词性。每条 Note 会生成 **Recognition** 和 **Production** 两张卡。

### 隐私

Wordflow 没有账号、广告、数据分析或开发者运营的服务器。选中的文字、有限长度的附近上下文和页面标题会从你的 Mac 直接发送到 OpenAI API，用于生成卡片。页面 URL 只写入本地 Anki，不会包含在 OpenAI 请求中。请求设置为 `store: false`。

完整的中英双语说明及浏览器权限用途见 [PRIVACY.md](PRIVACY.md)。

### 更新与卸载

更新时运行 `git pull`，重新运行 `install.command`，然后在浏览器扩展页面点击 **Reload**。

卸载时双击 `uninstall.command`。已经生成的 Anki 卡片不会被删除；浏览器扩展和钥匙串中的 API Key 需要按需手动移除。

### 开发与贡献

```bash
python3 -m unittest discover -s local_service/tests -v
node --check extension/service-worker.js
node --check extension/content.js
node --check extension/popup.js
native/build-app.sh
```

欢迎提交 Issue 和 Pull Request。更多信息见 [贡献指南](CONTRIBUTING.md)、[发布素材与步骤](docs/LAUNCH.md)和[更新日志](CHANGELOG.md)。

## License

[MIT](LICENSE)
