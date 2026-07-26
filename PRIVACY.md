# Wordflow Privacy / 隐私说明

Last updated / 最后更新：2026-07-26

## English

Wordflow is a local, open-source bridge between your browser, the OpenAI API, and Anki. It has no Wordflow account, advertising, analytics, telemetry, or developer-operated backend.

### Single purpose and Limited Use

Wordflow has one purpose: when the user explicitly selects or enters an English word or phrase, it keeps a limited amount of context and sends that material to the user's local Wordflow companion so an Anki vocabulary card can be created.

Wordflow's use of information received from Chrome APIs complies with the [Chrome Web Store User Data Policy](https://developer.chrome.com/docs/webstore/program-policies/user-data-faq), including the Limited Use requirements. Data is used only to provide this user-requested card-creation workflow. It is never sold, used for advertising, used to determine creditworthiness, or transferred for an unrelated purpose.

### Data processed

Only after you invoke Wordflow, the browser extension sends the following to the local Wordflow service on your Mac:

- the selected word or phrase;
- a bounded amount of nearby context;
- the source page or document title;
- the source URL;
- your requested explanation language.

The local service sends the word or phrase, bounded context, source title, and requested language to the OpenAI API to generate the card. The source URL is saved to your local Anki note but is not sent in the OpenAI generation request. Requests set `store: false`. OpenAI remains an independent service governed by its own API terms and data policies.

Wordflow does not monitor browsing, read pages in the background, or build a browsing-history profile. It records only the title and URL of a page from which the user explicitly captures a word. Page access is granted temporarily only after you click the extension, use its context-menu action, or press its capture shortcut.

### Storage and retention

- Your OpenAI API key is stored in macOS Keychain.
- The selected default deck and cached deck names are stored in `~/Library/Application Support/Wordflow/preferences.json`.
- Generated notes and cards are stored by Anki.
- Wordflow does not retain a separate server-side copy of captured words or context.
- The local Wordflow service listens only on `127.0.0.1:8766`; AnkiConnect normally listens on `127.0.0.1:8765`.

### Browser permissions

- `contextMenus`: adds the “Add to Anki” selection action.
- `storage`: remembers the local service URL, language preference, and previous browser window.
- `activeTab`: grants temporary access to the current tab only after the user invokes Wordflow.
- `scripting`: reads the current selection and bounded nearby text on demand, then displays the result toast. Wordflow does not register an always-on content script.
- Access to `127.0.0.1:8766` and `localhost:8766`: talks only to the Wordflow service on your own Mac; both loopback names are supported for compatibility.

Wordflow does not sell personal data. The project author does not receive the captured words, API key, browsing history, or Anki collection.

General questions can be opened through [GitHub Issues](https://github.com/yiyuke/wordflow-anki/issues). Report sensitive security problems privately according to [SECURITY.md](SECURITY.md).

## 中文

Wordflow 是浏览器、OpenAI API 与 Anki 之间的本地开源桥梁。它没有 Wordflow 账号、广告、数据分析、遥测或由开发者运营的后端服务器。

### 单一用途与 Limited Use

Wordflow 只有一个用途：当用户主动选中或输入英文单词、短语时，保留有限的上下文，并把这些材料发送到用户 Mac 上的 Wordflow 本地服务，用来创建 Anki 单词卡。

Wordflow 对 Chrome API 信息的使用遵守 [Chrome Web Store User Data Policy](https://developer.chrome.com/docs/webstore/program-policies/user-data-faq)，包括 Limited Use 要求。数据只用于用户主动发起的词卡创建流程，不会被出售、用于广告、用于判断信用，也不会被转移到无关用途。

### 会处理哪些数据

只有在你主动调用 Wordflow 后，浏览器扩展才会把以下内容发送到你 Mac 上的 Wordflow 本地服务：

- 选中的单词或短语；
- 有长度限制的附近上下文；
- 来源网页或文档标题；
- 来源 URL；
- 你需要的解释语言。

本地服务会把单词或短语、有限上下文、来源标题和解释语言发送到 OpenAI API 生成词卡。来源 URL 会保存在本地 Anki Note 中，但不会发送到 OpenAI 的生成请求。请求设置为 `store: false`。OpenAI 是独立服务，其 API 条款与数据政策仍然适用。

Wordflow 不会监控浏览行为，不会在后台读取网页，也不会建立浏览历史画像。它只记录用户主动捕捉生词时所在页面的标题和 URL。只有当你点击扩展、使用右键菜单或按下捕捉快捷键时，当前页面才会获得临时访问。

### 保存与保留

- OpenAI API Key 保存在 macOS 钥匙串。
- 默认牌组和缓存的牌组名称保存在 `~/Library/Application Support/Wordflow/preferences.json`。
- 生成的 Note 和卡片由 Anki 保存。
- Wordflow 不会在开发者服务器上另外保存你捕捉的单词或上下文。
- Wordflow 本地服务只监听 `127.0.0.1:8766`；AnkiConnect 通常监听 `127.0.0.1:8765`。

### 浏览器权限用途

- `contextMenus`：添加“加入 Anki”的选词菜单。
- `storage`：记住本地服务地址、语言偏好及之前的浏览器窗口。
- `activeTab`：只有在用户主动调用 Wordflow 后，才临时访问当前页面。
- `scripting`：按需读取当前选择和有限的附近文字，并显示结果提示；Wordflow 不会注册常驻页面的 Content Script。
- 访问 `127.0.0.1:8766` 和 `localhost:8766`：只连接你自己 Mac 上的 Wordflow 服务；同时支持两个回环地址是为了兼容旧版本设置。

Wordflow 不出售个人数据。项目作者不会收到你捕捉的单词、API Key、浏览历史或 Anki 数据库。

一般问题可以通过 [GitHub Issues](https://github.com/yiyuke/wordflow-anki/issues) 提交。涉及敏感信息的安全问题，请按照 [SECURITY.md](SECURITY.md) 私下报告。
