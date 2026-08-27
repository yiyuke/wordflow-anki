# Chrome Web Store submission kit

This file is the source of truth for the Wordflow 0.9.0 store submission. Copy the relevant fields into the Chrome Web Store Developer Dashboard after the release branch has been merged.

## Package

```bash
./scripts/package-extension.sh
```

Upload `dist/wordflow-extension-0.9.0.zip`. The package contains only the Manifest V3 browser extension. It never contains an OpenAI API key, local `.env` file, Anki data, or developer credentials.

## Product details

**Name**

```text
Wordflow to Anki
```

**Primary category**

```text
Education
```

**Homepage**

```text
https://github.com/yiyuke/wordflow-anki
```

**Support**

```text
https://github.com/yiyuke/wordflow-anki/issues
```

**Privacy policy**

```text
https://github.com/yiyuke/wordflow-anki/blob/main/PRIVACY.md
```

**English detailed description**

```text
Wordflow turns the English words and phrases you meet while reading into context-aware Anki vocabulary cards.

Select a word on a webpage and use the context menu or keyboard shortcut. Wordflow keeps a limited amount of the original sentence, creates either a complete learning card or a concise Exam Reading meaning, and sends the finished note to your chosen Anki deck. For words found in PDFs, Word documents, videos, or podcasts, open the keyboard-first Quick Add window from anywhere on macOS.

Each note can include:
• pronunciation and a clear meaning
• the original context and source
• 2–3 useful collocations
• 1–2 short, reusable examples
• one compact learning note adapted to the expression
• recognition and production cards

Requirements:
• macOS 12 or later
• Anki with the free AnkiConnect add-on
• the open-source Wordflow local companion
• the user's own OpenAI API key

Wordflow has no account, advertising, analytics, telemetry, or developer-operated server. Page content is accessed only after the user invokes Wordflow. The extension communicates only with the Wordflow companion running on the user's own Mac.
```

**简体中文详细说明**

```text
Wordflow 把你在阅读中真正遇到的英文单词和短语，变成保留语境、可以直接复习的 Anki 词卡。

在网页上选中一个词，通过右键菜单或快捷键调用 Wordflow。它会保留有限的原句语境，根据学习目标生成完整学习词卡或简洁的考研阅读释义，并把完成的 Note 送到你选择的 Anki 牌组。遇到 PDF、Word 文档、视频或播客中的词，也可以从 macOS 的任何位置打开键盘优先的 Quick Add 窗口。

每条 Note 可以包含：
• 发音和清楚的释义
• 原始语境与来源
• 2–3 个常用搭配
• 1–2 个简短、可复用的例句
• 一段根据词语动态设计的学习说明
• “看词识义”和“看义回忆”两张卡

使用要求：
• macOS 12 或以上
• Anki 与免费的 AnkiConnect 插件
• 开源的 Wordflow 本地服务
• 用户自己的 OpenAI API Key

Wordflow 没有账号、广告、数据分析、遥测或开发者运营的服务器。只有在用户主动调用 Wordflow 后，它才临时访问当前页面；扩展只连接用户自己 Mac 上运行的 Wordflow 本地服务。
```

## Privacy

**Single purpose**

```text
Wordflow captures an English word or phrase that the user explicitly selects or enters, preserves a limited amount of its original context, and sends that material to the user's local Wordflow companion to create an Anki vocabulary card.
```

**Permission justifications**

- `contextMenus`: Adds “Add to Anki” only to the browser menu shown for selected text.
- `storage`: Stores the localhost service URL, interface language preference, and the ID of the browser window to return to after saving.
- `activeTab`: Grants temporary access to the current tab only after the user clicks Wordflow, chooses its context-menu command, or presses its capture shortcut.
- `scripting`: Runs two small, packaged functions on demand: one reads the current selection and at most 600 characters of nearby context; the other displays a short success or error toast. Wordflow has no always-on content script and loads no remote code.
- `http://127.0.0.1:8766/*` and `http://localhost:8766/*`: Communicate only with the open-source Wordflow companion on the user's own Mac. Supporting both loopback names keeps upgrades compatible with earlier local settings. No non-local HTTP origin is permitted.

**Data-use disclosure**

- Disclose website content: selected word or phrase and bounded nearby context.
- Disclose web history if the dashboard definition includes the title and URL of the one page from which the user explicitly captures a word. Wordflow does not monitor other pages or build a browsing-history profile.
- The extension sends this material only to the local companion after an explicit user action.
- The local companion sends the selected expression, bounded context, page title, and requested language to the OpenAI API. It does not send the source URL to OpenAI.
- Requests to OpenAI set `store: false`.
- The source URL and generated card are stored in the user's local Anki collection.
- Wordflow does not collect browsing history, authentication information, financial information, health information, personal communications, location, or analytics.
- Wordflow does not sell user data or use it for advertising, creditworthiness, or unrelated purposes.

Use the public [`PRIVACY.md`](../PRIVACY.md) for the Limited Use disclosure and complete the dashboard certifications truthfully.

## Distribution

Recommended first submission:

- Visibility: `Unlisted`
- Regions: `All regions`
- In-app purchases: `No`
- Mature content: `No`
- Deferred publishing: `On`

Unlisted and public items follow the same policy review. Use the unlisted URL for a small beta, then move to public distribution after the complete production installation has been verified by several external users.

## Reviewer test instructions

Wordflow normally requires Anki, AnkiConnect, and the user's own OpenAI API key. Reviewers can exercise the complete browser-extension interaction without credentials, paid services, network calls, or an Anki installation:

1. On macOS with Python 3, download the source linked from the Homepage URL.
2. Double-click `scripts/start-review-mode.command`, or run it from Terminal.
3. Keep its Terminal window open. It starts an isolated mock companion on `127.0.0.1:8766`.
4. Open a normal webpage containing English text.
5. Select a word or phrase and choose **Add to Anki** from the context menu, or press `Option + Shift + A`.
6. Confirm that a success toast appears. Review mode creates a deterministic mock card in memory and makes no external request.
7. Press `Option + Shift + W`. Because the native companion app is not installed, Wordflow opens its browser Quick Add fallback.
8. Enter a word and optional sentence, then choose **Generate and add to Anki**. Confirm that the success message appears.
9. Press Control-C in the review-mode Terminal window to stop the local service.

The production path is documented in the bilingual README. Review mode exists only to make policy review deterministic; it does not bypass or alter the production requirements presented to users.

## Required graphic assets

- `assets/chrome-web-store/icon-128.png`
- `assets/chrome-web-store/screenshot-capture-en-1280x800.png`
- `assets/chrome-web-store/screenshot-quick-add-en-1280x800.png`
- `assets/chrome-web-store/screenshot-capture-zh-1280x800.png`
- `assets/chrome-web-store/screenshot-quick-add-zh-1280x800.png`
- `assets/chrome-web-store/small-promo-440x280.png`
- `assets/chrome-web-store/marquee-promo-1400x560.png`
- YouTube demo URL: add after the user uploads the final recording.

The English and Simplified Chinese screenshots use the same features and differ only in localized interface copy.
