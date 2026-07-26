<p align="center">
  <img src="assets/wordflow-logo.png" alt="Wordflow 标志" width="132">
</p>

<h1 align="center">Wordflow</h1>

<p align="center"><strong>在生词滑走之前，接住它。</strong></p>
<p align="center">把真实遇见的词，变成真正记得住的 Anki 卡片。</p>

<p align="center">
  <a href="README.md">English</a> · <strong>简体中文</strong>
</p>

<p align="center">
  <img alt="macOS" src="https://img.shields.io/badge/macOS-12%2B-111827?logo=apple">
  <img alt="Arc and Chrome" src="https://img.shields.io/badge/Arc%20%2F%20Chrome-Chromium-067647?logo=googlechrome">
  <img alt="Anki" src="https://img.shields.io/badge/Anki-AnkiConnect-2563eb">
  <img alt="License" src="https://img.shields.io/badge/license-MIT-475467">
</p>

---

## 我为什么做 Wordflow

积累词汇最容易中断的地方，往往就在**遇见一个词**和**真正记住它**之间。

- 背单词书可以一次看到很多词，但这些词缺少与自己有关的语境，常常背过就忘。
- 小说、视频、文章或播客里遇见的词更鲜活，却很容易在继续阅读时“滑走”；下一次再遇见，它又变回一个陌生词。
- Anki 很擅长安排复习，但制作一张好卡片仍然需要手动录入。不同词语真正需要的释义、语境、搭配和记忆方法也并不相同，很难每次都稳定整理好。

Wordflow 想补上的就是这一段：趁语境还新鲜时接住这个词，根据它本身的类型和理解难度生成紧凑的解释，然后直接送进 Anki。

```text
收集 → 理解与记录 → 复习 → 使用
```

目标不是囤积一张越来越长的词表，而是建立一条可以持续运行的词汇积累路径。

## Wordflow 的优势

- **几秒钟完成录入。** 网页选词右键，或者直接按快捷键。
- **保留真实语境。** 原句、页面标题和来源会一起进入卡片。
- **解释会动态取舍。** 单词、习语、短语动词和抽象概念不会被强行塞入同一套模板。
- **双向复习。** 每条 Note 自动生成 Recognition 和 Production 两张卡。
- **不打断正在做的事。** 紧凑的原生窗口支持置顶和全键盘操作。
- **继续使用自己的 Anki。** 可以选择任意牌组，卡片支持浅色与深色模式。
- **中英双语。** `自动 / 中文 / English` 会同时切换界面和解释语言。

## 它是什么

Wordflow 目前不是云端账号型 App，而是一套只在 Mac 本地运行的工作流：

```text
Arc / Chrome 扩展 ─┐
原生快速输入窗口 ──┼─→ Wordflow 本地服务 → OpenAI API
桌面 / PDF 输入 ───┘                         ↓
                                            AnkiConnect → Anki
```

浏览器扩展负责取得词语和上下文，本地服务负责生成卡片内容，AnkiConnect 负责把 Note 和两张卡写进 Anki。Wordflow 本身只监听 `127.0.0.1`。

## 当前状态

Wordflow 目前是一个早期的 macOS 开源版本，已经可以用于个人学习和测试，但安装还没有普通 App Store 软件那么简单：

- 浏览器扩展暂时需要手动加载；
- macOS 可能会要求确认未签名的本地脚本；
- 必须安装 Anki 和 AnkiConnect；
- 每位用户需要提供自己的 OpenAI API Key，并承担自己的 API 费用。

Chrome Web Store 版本和更简单的签名安装包，是后续的发布方向。

## 系统要求

- macOS 12 或更高版本
- [Anki 桌面版](https://apps.ankiweb.net/)
- Arc、Chrome、Edge 或其他 Chromium 浏览器
- Python 3
- [OpenAI API Key](https://platform.openai.com/api-keys)；API 费用与 ChatGPT 订阅相互独立
- 可选：Xcode Command Line Tools，用于构建原生快速窗口；没有 Swift 时会自动使用浏览器备用窗口

## 下载、Clone 还是 Fork？

普通使用者**不需要 Fork 仓库**。Fork 主要用于独立修改源码或提交代码贡献。

目前还没有正式带版本号的 GitHub Release。现阶段测试者可以 Clone 仓库并按照下方步骤安装；第一份 GitHub Release 发布后，普通用户直接下载 Release 即可。

也可以让 AI 编程工具读取这份 README 并协助安装，但这不是必需条件。macOS 权限确认、AnkiConnect 安装、输入自己的 API Key，以及在商店版发布前加载未打包扩展，仍然需要用户本人完成。

## 安装

### 1. 下载 Wordflow

```bash
git clone https://github.com/yiyuke/wordflow-anki.git
cd wordflow-anki
```

### 2. 安装 AnkiConnect

1. 安装并打开 [Anki](https://apps.ankiweb.net/)。
2. 进入 **Tools → Add-ons → Get Add-ons**。
3. 输入 AnkiConnect 代码 `2055492159`。
4. 重启 Anki。

请保留 AnkiConnect 的默认本地地址 `127.0.0.1:8765`。项目说明和源码见 [AnkiConnect](https://git.sr.ht/~foosoft/anki-connect)。

### 3. 安装本地服务

双击 `install.command`。安装完成后，再双击已安装目录中的 `configure-api-key.command`，粘贴 OpenAI API Key。Key 会保存在 macOS 钥匙串，不会写入 GitHub 仓库。

如果 macOS 阻止脚本运行，请按住 Control 点击文件，选择 **打开**，再确认一次。

### 4. 加载浏览器扩展

在 Wordflow 正式上架 Chrome Web Store 前：

1. 打开 `arc://extensions` 或 `chrome://extensions`。
2. 开启 **Developer mode**。
3. 点击 **Load unpacked / 加载已解压的扩展程序**。
4. 选择 `~/Library/Application Support/Wordflow/extension`。

Arc 可以直接使用 Chrome Web Store 扩展，因此未来只需发布一个商店版本。

## 使用

- 在网页选中单词，右键选择 **加入 Anki**。
- `Option + Shift + A`：捕捉浏览器当前选中的词语。
- `Option + Shift + W`：从 Word、PDF、播客笔记或其他 App 打开快速输入窗。
- `Command + D`：选择 Anki 牌组。
- 在右上角选择 `自动 / 中文 / English`：自动模式跟随 Arc、Chrome 或 macOS，手动选择会被记住。
- 在任一输入框按 `Command + A`：全选当前输入框的内容。
- `Enter`：保存并继续输入。
- `Command + Enter`：保存后把焦点交回之前的 App；置顶窗口继续显示。
- `Command + P`：切换置顶；`Esc`：关闭窗口。

新卡默认加入 `Vocabulary Inbox`，之后选择的牌组会被记住。列表里的 `Default` 是 Anki 自带的真实牌组。如果快捷键冲突，可在 `arc://extensions/shortcuts` 或 `chrome://extensions/shortcuts` 修改，并把手动输入快捷键设成 **Global**。

## 每张卡包含什么

- 完整保留选中的单词或短语，并附上字典原形
- IPA 发音
- 中文或英文简明释义
- 适合学习者的英文定义
- 原始上下文与挖空版本
- 2–3 个常用搭配
- 一段紧凑的动态说明，可在合适时使用画面、语义迁移、可靠词源、近义辨析、语气、语法或短语逻辑
- 1–2 个自然、容易复用的例句
- 来源标题与 URL
- 可选 OpenAI TTS 发音音频

查重使用 lemma + 词性。每条 Note 会生成 **Recognition** 和 **Production** 两张卡。

Wordflow 运行时并不会执行一个 Codex Skill。本地服务会把 Wordflow 自己维护的提示词、选中的词语和上下文发送给 OpenAI Responses API。严格的 JSON Schema 固定卡片结构和内容预算，模型则在这个范围内自行选择最有帮助的解释方法。李继刚的 [`ljg-word` Skill](https://github.com/lijigang/ljg-skills/blob/master/skills/ljg-word/SKILL.md) 提供了“画面 → 含义迁移”的启发，但它不是运行依赖，也不是每个词都必须套用的模板。

## 隐私与 API 费用

Wordflow 没有账号、广告、数据分析或开发者运营的服务器。选中的文字、有限长度的附近上下文和页面标题会从你的 Mac 直接发送到 OpenAI API。页面 URL 只写入本地 Anki，不会包含在生成请求中。请求设置为 `store: false`。

每一份安装都会使用那台 Mac 上单独配置的 API Key。Key 只保存在自己的 macOS 钥匙串中，会被 Git 忽略，也不会随着仓库分发。其他用户使用并支付的是他们自己的 OpenAI API 用量。

完整说明和浏览器权限用途见 [PRIVACY.md](PRIVACY.md)。涉及敏感信息的安全问题，请按照 [SECURITY.md](SECURITY.md) 私下提交。

## 更新与卸载

更新时运行 `git pull`，重新运行 `install.command`，然后在浏览器扩展页面点击 **Reload**。

卸载时双击 `uninstall.command`。已经生成的 Anki 卡片不会被删除；浏览器扩展和钥匙串中的 API Key 需要按需手动移除。

## 开发与贡献

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
