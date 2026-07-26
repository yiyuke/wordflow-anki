# Wordflow Launch Kit / 发布工具包

Everything here is ready to copy, adjust, and publish. Keep the launch personal and concrete: show the interruption you wanted to remove, then show one word going from a webpage into Anki.

## 1. Recommended release order / 建议发布顺序

1. Merge the public-release pull request into `main`.
2. Run the tests on `main` and install that exact revision locally.
3. Create GitHub Release `v0.6.0` with the release notes below. GitHub automatically adds source `.zip` and `.tar.gz` downloads.
4. Record one silent 8–15 second demo: select a word → use the shortcut → show the resulting Anki card.
5. Publish on X/Twitter first, then publish a more personal Chinese version on Xiaohongshu.
6. Ask for a very specific response: installation problems, one missing card field, or one workflow that still feels slow.
7. After the first testers succeed, prepare the Chrome Web Store listing. GitHub remains the source/documentation home; the store becomes the convenient installation channel.

## 2. GitHub Release

**Tag:** `v0.6.0`
**Title:** `Wordflow 0.6 — Turn every new word into a review`

```markdown
Wordflow turns words you meet in Arc, Chrome, PDFs, Word, and podcast notes into review-ready Anki cards.

Highlights:
- English and Simplified Chinese UI
- English or Chinese card explanations
- Context-aware meaning, IPA, collocations, etymology, memory hook, and examples
- Recognition + production cards
- Native pinned, keyboard-first Quick Add window for macOS
- Deck selection and automatic Anki launch
- Light/dark Anki card styling

Requirements: macOS, Anki + AnkiConnect, a Chromium browser, Python 3, and your own OpenAI API key.

Start with the bilingual README. Please open an Issue if installation is unclear—first-release feedback is especially useful.
```

## 3. X / Twitter launch post

Use `assets/social-card-en.png` and, ideally, attach the short demo as the first media item.

```text
I built Wordflow to remove one tiny interruption from learning English:

See a word → select it → get a review-ready Anki card.

It keeps the original context and adds IPA, a clear meaning, collocations, careful etymology, memory hooks, and examples—then creates recognition + production cards.

Open source. macOS. Arc/Chrome. English + 中文.

https://github.com/yiyuke/wordflow-anki
```

Optional follow-up posts:

```text
The part I cared about most: it also works when the word is in Word, a PDF, podcast notes, or a link you cannot select. ⌥⇧W opens a tiny keyboard-first window from anywhere.
```

```text
This is an early open-source release. It still requires AnkiConnect and your own OpenAI API key. If you try it, tell me where installation feels confusing or slow—that is the most useful feedback right now.
```

## 4. 小红书首发笔记

建议使用 `assets/social-card-zh.png` 作为首图，第二张放“网页选词”，第三张放“自动生成的 Anki 卡片”，最后一张写清楚安装要求。不要把它包装成“零配置神器”；公开说明需要 AnkiConnect 和自己的 OpenAI API Key，更容易获得可信的反馈。

**标题候选：**

```text
我把「查生词→做 Anki 卡」做成了一个快捷键
```

**正文：**

```text
我学英语时一直有一个很小、但很烦的中断：

看到生词 → 复制 → 打开 GPT → 查释义、词源、搭配和例句 → 再粘贴进 Anki。

步骤并不难，但一天重复很多次以后，我经常干脆不记了。

所以我做了 Wordflow：

在 Arc / Chrome 里选中单词，右键或按快捷键，它会保留原句和来源，自动整理 IPA、释义、英文定义、搭配、可靠词源、记忆提示和例句，然后直接放进指定的 Anki 牌组，同时生成“看词识义”和“看义回忆”两张卡。

遇到 Word、PDF、播客笔记，或者没法选中的链接，也可以按 ⌥⇧W 打开一个很小的置顶输入框，全程可以用键盘完成。

目前是第一版开源工具：
• macOS
• Arc / Chrome
• 需要 Anki + AnkiConnect
• 需要自己的 OpenAI API Key
• 支持中文和英文界面

代码和完整安装说明在 GitHub：搜索 yiyuke/wordflow-anki。

如果你愿意试用，我最想知道两件事：哪一步安装最容易卡住？一张单词卡里还有什么信息是你真的会复习、但现在缺少的？

#英语学习 #Anki #背单词 #效率工具 #开源工具
```

## 5. Assets / 素材

- `assets/wordflow-logo.png` — transparent 1024 × 1024 logo
- `assets/social-card-en.png` — 1600 × 900 landscape launch image
- `assets/social-card-zh.png` — 1080 × 1440 portrait launch image
- `extension/icons/` — 16, 32, 48, and 128 px browser icons

## 6. Chrome Web Store follow-up

GitHub source alone cannot provide one-click installation for ordinary macOS/Windows Chrome users. A Chrome Web Store listing is the practical next distribution step and also works in Arc. Before submission, prepare:

- extension ZIP containing only `extension/` (run `scripts/package-extension.sh`);
- 128 px icon and store screenshots;
- the single-purpose description;
- `PRIVACY.md` hosted at a public URL;
- permission justifications;
- support URL and contact method;
- a test installation using a clean Chrome profile.

The browser extension still depends on the local macOS service, Anki, and AnkiConnect, so the store listing must say this near the top rather than hiding it.
