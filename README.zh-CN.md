<p align="center">
  <img src="assets/wordflow-logo.png" alt="Wordflow 标志" width="120">
</p>

<h1 align="center">Wordflow</h1>

<p align="center"><strong>记住你真正遇见的生词。</strong></p>
<p align="center">收集 → 理解 → 复习 → 使用</p>

<p align="center">
  <a href="README.md">English</a> · <strong>简体中文</strong>
</p>

<p align="center">
  <a href="https://chromewebstore.google.com/detail/wordflow-to-anki/digeekdaafggpmdaojgmpjkdbbkgkiga"><strong>从 Chrome 应用商店安装</strong></a>
  ·
  <a href="https://www.youtube.com/watch?v=ySq3NDcvDcQ"><strong>观看 38 秒演示</strong></a>
</p>

<p align="center">
  <img alt="macOS" src="https://img.shields.io/badge/macOS-12%2B-111827?logo=apple">
  <img alt="Arc and Chrome" src="https://img.shields.io/badge/Arc%20%2F%20Chrome-Chromium-067647?logo=googlechrome">
  <img alt="Anki" src="https://img.shields.io/badge/Anki-AnkiConnect-2563eb">
  <img alt="License" src="https://img.shields.io/badge/license-MIT-475467">
</p>

---

## 用Anki复习，用Wordflow录入

[Anki](https://apps.ankiweb.net/) 是一款基于“间隔重复”的记忆工具，它设置好复习单词卡片的次数和循环，帮助长期记忆。

Anki 适合用来复习，但仍需手动录入每一个单词卡片。

Wordflow 支持选中或输入一个词，结合原句理解它，生成紧凑的学习卡片，直接送进 Anki。

```text
遇见一个词 → 捕捉一次 → 通过循环复习机制 → 最后真正会用
```

我认为最好的记忆单词的方法：不是背一张陌生的单词表，而是在真实语境中遇见、理解，在正确的时间复习，直到能够使用。

## Wordflow的优点

- **保留真实语境，不孤立释义。** 录入单词时可以同时录入原文语境，并由此生成词卡。
- **量身定制每个词卡。** AI会为不同类型的单词、短语或固定搭配设计最适合记忆的内容。
- **几乎不打断阅读。** 网页选词右键，或按 `Option + Shift + W`打开添加生词窗口。
- **双向主动回忆。** 每次录入自动生成“看词识义”和“看义回忆”两张卡，正反巩固生词。

根据学习目标选择不同的词卡。**完整学习**会提供发音、清楚的释义、2–3 个常用搭配、1–2 个易复用例句和一段紧凑的学习说明；**考研阅读**只保留这个词在原句中的准确中文意思，帮助用户快速读懂文章，不让解释淹没重点。

## 看完整的学习闭环

<table>
  <tr>
    <td width="50%" align="center">
      <a href="https://www.youtube.com/watch?v=ySq3NDcvDcQ">
        <img src="assets/demo-capture.jpg" alt="用 Wordflow 收集单词并生成 Anki 卡片" width="100%">
      </a>
      <br>
      <strong>1. 收集与理解</strong><br>
      选中单词、保留语境，自动生成两张可以直接复习的卡片。
    </td>
    <td width="50%" align="center">
      <a href="https://www.youtube.com/watch?v=SslXMoeeIzc">
        <img src="assets/demo-review.jpg" alt="在 Anki 中复习 Wordflow 卡片" width="100%">
      </a>
      <br>
      <strong>2. 复习与回忆</strong><br>
      让 Anki 安排复习，直到“见词认识”变成“主动想起”。
    </td>
  </tr>
</table>

## 安装

> Wordflow 目前是一个早期 macOS 版本。需要 Anki、AnkiConnect、Chrome 或 Arc、Python 3 和用户自己的 OpenAI API Key。浏览器扩展已经上架 Chrome 应用商店；一个很小的本地服务负责在你的 Mac 上连接扩展和 Anki。

### 1. 安装浏览器扩展

[**从 Chrome 应用商店安装 Wordflow →**](https://chromewebstore.google.com/detail/wordflow-to-anki/digeekdaafggpmdaojgmpjkdbbkgkiga)

同一个商店页面同时适用于 Chrome 和 Arc。

### 2. 安装 Anki 和 AnkiConnect

1. 安装并打开 [Anki](https://apps.ankiweb.net/)。
2. 进入 **Tools → Add-ons → Get Add-ons**。
3. 输入 `2055492159`，然后重启 Anki。

### 3. 安装 Wordflow 本地服务

#### 推荐：交给本地 AI 编程助手安装

如果你使用能够访问这台 Mac 终端的 Codex、Claude Code 或其他 AI 编程助手，复制下面整段 Prompt 给它即可。普通聊天机器人无法直接操作本地电脑。

```text
请帮我在这台 Mac 上安装 Wordflow 本地服务：
https://github.com/yiyuke/wordflow-anki

开始前，请先阅读 README.zh-CN.md 和 install.command，确认安装内容。
请从 main 分支下载或更新项目，运行项目自带的安装程序，并验证：
1. Wordflow 本地服务在 127.0.0.1:8766 正常运行；
2. 原生 Quick Add 窗口可以打开；
3. 从 Chrome 应用商店安装的扩展可以连接本地服务。

请使用 Chrome 应用商店版本；除非我明确要求开发版，否则不要从源代码加载浏览器扩展。
不要让我 Fork 仓库，也不要让我把 OpenAI API Key 发到聊天里。
只有遇到以下必须由我完成的步骤时才暂停，并给出清楚、逐步的指引：
- 安装或打开 Anki，并在 Anki 中安装 AnkiConnect（代码：2055492159）；
- 从 https://chromewebstore.google.com/detail/wordflow-to-anki/digeekdaafggpmdaojgmpjkdbbkgkiga 安装 Wordflow 扩展；
- 在本地终端的隐藏输入提示中粘贴我自己的 OpenAI API Key，让它保存到 macOS 钥匙串；
- 处理可能出现的 macOS 安全确认。

完成后，请测试 Option + Shift + W 和 Option + Shift + A，并告诉我是否还有需要手动完成的事情。
```

> 不要把 API Key 直接粘贴给 AI。Wordflow 自带的配置脚本会在本地隐藏输入，并把 Key 保存到 macOS 钥匙串。

<details>
<summary><strong>不使用 AI，手动安装本地服务</strong></summary>

### 下载源代码

目前还没有单独发布带版本号的本地服务安装包，可以使用当前版本：

```bash
git clone https://github.com/yiyuke/wordflow-anki.git
cd wordflow-anki
```

### 运行安装程序

1. 双击 `install.command`。
2. 双击安装后的 `configure-api-key.command`，粘贴自己的 [OpenAI API Key](https://platform.openai.com/api-keys)。
3. 如果 macOS 阻止脚本运行，请按住 Control 点击文件，选择 **打开**，再确认一次。

</details>

## 使用

| 想做什么 | 操作 |
| --- | --- |
| 捕捉 Arc 或 Chrome 里选中的词 | 右键 **加入 Anki**，或按 `Option + Shift + A` |
| 输入 PDF、Word、视频或播客里的词 | 在任意 App 按全局快捷键 `Option + Shift + W` |
| 在详细学习和考研阅读之间切换 | 打开标题栏齿轮 → **学习模式** |
| 选择 Anki 牌组 | 在快速窗口按 `Command + D` |
| 保存并继续输入 | 按 `Enter` |
| 保存后回到之前的 App | 按 `Command + Enter` |
| 置顶或关闭快速窗口 | 按 `Command + P` 或 `Esc` |

标题栏齿轮把学习模式、语言和完整快捷键表收在同一个地方，Wordflow 会记住你的选择。新卡默认进入 `Vocabulary Inbox`，之后选择的牌组也会被记住。

保存时如果 Anki 没有运行，Wordflow 会在后台打开 Anki、等待 AnkiConnect 就绪，并安全地完成添加。

macOS 顶部标题栏右侧的问号按钮包含应用内反馈、项目主页和手动检查更新。用户只需选择反馈类型、描述问题并直接提交，不需要打开邮件 App，也不需要提供联系方式。发现新版本后，按钮会变成高亮的下载按钮。

## 隐私与费用

Wordflow 没有账号、广告或数据分析。可选反馈表单只会通过 Formspree 传递用户主动提交的反馈类型和问题描述。

词语和有限的上下文会从你的 Mac 直接发送到 OpenAI API，生成的卡片保存在你自己的 Anki 中。

每一份安装都使用用户自己的 OpenAI API Key，并支付自己的 API 用量。详细说明见 [PRIVACY.md](PRIVACY.md) 和 [SECURITY.md](SECURITY.md)。

<details>
<summary><strong>Wordflow 如何工作</strong></summary>

```text
Arc / Chrome 扩展 ─┐
原生快速输入窗口 ──┼─→ Wordflow 本地服务 → OpenAI API
桌面 / PDF 输入 ───┘                         ↓
                                            AnkiConnect → Anki
```

Wordflow 只监听 `127.0.0.1`。严格的 JSON Schema 控制卡片长度和结构，模型则选择最适合当前词语的解释方法。李继刚的 [`ljg-word` Skill](https://github.com/lijigang/ljg-skills/blob/master/skills/ljg-word/SKILL.md) 提供了一种可选的“画面 → 含义”启发，但它不是运行依赖。

</details>

<details>
<summary><strong>更新、卸载与开发</strong></summary>

Chrome 应用商店会自动更新浏览器扩展。更新本地服务时运行 `git pull`，再重新运行 `install.command`。卸载时双击 `uninstall.command`；已有 Anki 卡片不会被删除。

如果要开发扩展，请打开 `arc://extensions` 或 `chrome://extensions`，开启 **Developer mode**，选择 **Load unpacked / 加载已解压的扩展程序**，然后选择仓库中的 `extension` 文件夹。

```bash
python3 -m unittest discover -s local_service/tests -v
node --check extension/service-worker.js
node --check extension/popup.js
native/build-app.sh
```

更多信息见 [CONTRIBUTING.md](CONTRIBUTING.md)、[CHANGELOG.md](CHANGELOG.md)、[发布工具包](docs/LAUNCH.md)和 [Chrome Web Store 提交工具包](docs/CHROME_WEB_STORE.md)。

</details>

## License

[MIT](LICENSE)
