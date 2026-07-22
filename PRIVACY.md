# Wordflow Privacy / 隐私说明

Last updated / 最后更新：2026-07-22

## English

Wordflow is a local, open-source bridge between your browser, the OpenAI API, and Anki. It has no Wordflow account, advertising, analytics, telemetry, or developer-operated backend.

### Data processed

When you create a card, Wordflow sends the following directly from your Mac to the OpenAI API:

- the selected word or phrase;
- a bounded amount of nearby context;
- the source page or document title;
- your requested explanation language.

The source URL is saved to your local Anki note but is not sent in the OpenAI generation request. Requests set `store: false`. OpenAI remains an independent service governed by its own API terms and data policies.

### Local data

- Your OpenAI API key is stored in macOS Keychain.
- The selected default deck and cached deck names are stored in `~/Library/Application Support/Wordflow/preferences.json`.
- Generated notes and cards are stored by Anki.
- The local Wordflow service listens only on `127.0.0.1:8766`; AnkiConnect normally listens on `127.0.0.1:8765`.

### Browser permissions

- `contextMenus`: adds the “Add to Anki” selection action.
- `storage`: remembers the local service URL and the previous browser window.
- `activeTab` and `tabs`: read the current selection and return focus after saving.
- Access to `127.0.0.1:8766`: talks to the Wordflow service on your own Mac.
- Content scripts: read only the current selection and bounded nearby text when you invoke Wordflow, then display the result toast.

Wordflow does not sell personal data. The project author does not receive the captured words, API key, browsing history, or Anki collection.

Questions or security reports can be opened through [GitHub Issues](https://github.com/yiyuke/wordflow-anki/issues).

## 中文

Wordflow 是浏览器、OpenAI API 与 Anki 之间的本地开源桥梁。它没有 Wordflow 账号、广告、数据分析、遥测或由开发者运营的后端服务器。

### 会处理哪些数据

创建卡片时，Wordflow 会从你的 Mac 直接向 OpenAI API 发送：

- 选中的单词或短语；
- 有长度限制的附近上下文；
- 来源网页或文档标题；
- 你需要的解释语言。

来源 URL 会保存在本地 Anki Note 中，但不会发送到 OpenAI 的生成请求。请求设置为 `store: false`。OpenAI 是独立服务，其 API 条款与数据政策仍然适用。

### 本地数据

- OpenAI API Key 保存在 macOS 钥匙串。
- 默认牌组和缓存的牌组名称保存在 `~/Library/Application Support/Wordflow/preferences.json`。
- 生成的 Note 和卡片由 Anki 保存。
- Wordflow 本地服务只监听 `127.0.0.1:8766`；AnkiConnect 通常监听 `127.0.0.1:8765`。

### 浏览器权限用途

- `contextMenus`：添加“加入 Anki”的选词菜单。
- `storage`：记住本地服务地址及之前的浏览器窗口。
- `activeTab` 与 `tabs`：读取当前选择，并在保存后切回原窗口。
- 访问 `127.0.0.1:8766`：连接你自己 Mac 上的 Wordflow 服务。
- Content script：只有在你调用 Wordflow 时读取当前选择和有限的附近文字，并显示操作结果。

Wordflow 不出售个人数据。项目作者不会收到你捕捉的单词、API Key、浏览历史或 Anki 数据库。

隐私或安全问题可以通过 [GitHub Issues](https://github.com/yiyuke/wordflow-anki/issues) 提交。
