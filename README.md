# Wordflow to Anki

选中网页里的英文单词或短语，自动生成包含中文释义、IPA、英文定义、搭配、词源、记忆提示和例句的双向 Anki 卡片。

Wordflow 当前不是一个独立桌面 App，而是一套本地工具：

```text
Arc / Chrome 扩展 → macOS 原生快速输入窗
        ↓
macOS 本地服务（OpenAI Responses API）
        ↓
AnkiConnect → Anki 桌面版
```

浏览器扩展负责取词和快捷键；本地服务负责生成内容；AnkiConnect 负责把 Note 和两张卡片写入 Anki。所有服务只监听本机 `127.0.0.1`。

## 功能

- Arc、Chrome、Edge 等 Chromium 浏览器：选词右键加入 Anki
- 自动携带网页标题、URL 和附近上下文
- 手动输入窗口，适合不能选中的链接、Word、PDF、Codex 等场景
- 原生快速输入窗支持置顶、系统红黄绿按钮和全键盘操作
- 快速窗口可读取现有 Anki 牌组、记住默认牌组，并用 `Command + D` 切换
- 牌组使用向下展开的菜单；单词和上下文输入区采用统一的圆角样式
- 录词时如发现 Anki 尚未运行，会自动在后台启动并等待 AnkiConnect
- 快捷键会可靠地重新聚焦已置顶窗口；保存或取消后可回到原来的 App
- 窗口保持紧凑，并记住用户调整后的尺寸
- 自动生成中文释义、IPA、英文定义、搭配、可靠词源、记忆提示和例句
- 自动创建 `Vocabulary Inbox` 牌组和 `AI Vocabulary` Note Type
- 每个单词生成 Recognition 和 Production 两张卡
- 按 lemma + 词性查重
- 卡片支持 Anki light mode 和 dark mode
- 可选 OpenAI TTS 发音；默认只生成 IPA

## 系统要求

- macOS（当前一键安装脚本只支持 Mac）
- [Python 3](https://www.python.org/downloads/macos/)
- 可选：Xcode Command Line Tools，用于构建原生快速窗口；缺少时自动使用浏览器备用窗口
- [Anki 桌面版](https://apps.ankiweb.net/)
- Chromium 浏览器：Arc、Chrome 或 Edge
- [OpenAI API Key](https://platform.openai.com/api-keys)；API 费用与 ChatGPT 订阅相互独立

## 安装

### 1. 下载 Wordflow

任选一种方式：

- 在本仓库点击 **Code → Download ZIP**，解压后打开文件夹。
- 或在终端运行：

```bash
git clone https://github.com/yiyuke/wordflow-anki.git
cd wordflow-anki
```

### 2. 安装 Anki 和 AnkiConnect

1. 从 [Anki 官网](https://apps.ankiweb.net/)下载并安装桌面版 Anki。
2. 打开 Anki，进入 **Tools → Add-ons → Get Add-ons**。
3. 输入 AnkiConnect 代码 `2055492159`。
4. 重启 Anki，并在使用 Wordflow 时保持 Anki 运行。
5. 可选检查：浏览器打开 `http://127.0.0.1:8765`，看到 `Anki-Connect` 即正常。

AnkiConnect 的项目说明与源码见 [AnkiConnect](https://git.sr.ht/~foosoft/anki-connect)。请保持默认监听地址 `127.0.0.1`，不要改成 `0.0.0.0`。

### 3. 安装本地服务

双击项目根目录的 `install.command`。它会：

- 把公开程序文件复制到 `~/Library/Application Support/Wordflow`
- 注册一个只在本机运行的后台服务
- 在本机具备 Swift 编译器时构建原生快速输入窗
- 打开已安装的 Wordflow 文件夹

如果 macOS 阻止运行，请按住 Control 点击文件，选择 **打开**，再确认一次。

然后双击已安装目录中的 `configure-api-key.command`，粘贴 OpenAI API Key。输入不会显示；Key 会存进 macOS 钥匙串，不会写进项目或上传 GitHub。

### 4. 安装浏览器扩展

目前 GitHub 版本需要手动加载，尚未发布到 Chrome Web Store。

Arc：

1. 打开 `arc://extensions`。
2. 开启 **Developer mode**。
3. 点击 **Load unpacked**。
4. 选择 `~/Library/Application Support/Wordflow/extension`。

Chrome：

1. 打开 `chrome://extensions`。
2. 开启 **Developer mode**。
3. 点击 **Load unpacked / 加载已解压的扩展程序**。
4. 选择 `~/Library/Application Support/Wordflow/extension`。

Edge 的步骤相同，入口是 `edge://extensions`。

## 使用

- 在网页选中单词，右键选择 **加入 Anki**。
- `Option + Shift + A`：把浏览器当前选中的单词直接加入 Anki。
- `Option + Shift + W`：打开原生快速输入窗。只要 Arc/Chrome 正在运行，即使焦点在 Word、PDF 或其他 App，也可以使用。
- 点击扩展图标：同样打开快速输入窗。

如快捷键冲突，可在 `arc://extensions/shortcuts` 或 `chrome://extensions/shortcuts` 修改，并把手动输入命令的作用域设为 **Global**。

新卡会出现在 Anki 的 `Vocabulary Inbox` 牌组。也可在 Anki 的 **Browse** 中搜索单词。

### 快速输入窗的键盘操作

- 打开窗口时，光标自动落在“单词或短语”。
- 即使置顶窗口已经显示，再按 `Option + Shift + W` 也会重新聚焦单词框。
- 在单词框按 `↓` 或 `Tab`：进入上下文。
- 在上下文按 `Tab`：进入“加入 Anki”按钮；按 `Shift + Tab` 返回单词框。
- `Command + D`：打开牌组选择器；选择会成为浏览器右键添加和下次输入的默认牌组。
- 在单词框按 `Enter`，或点击按钮：生成并保存，窗口保持打开，适合连续输入。
- 在任意位置按 `Command + Enter`：生成并保存，然后激活原来的 App；置顶快速窗口会继续显示但不占用焦点。
- `Command + P`：切换“置顶”。窗口会记住这个选择。
- `Esc`：无论光标停在哪个输入框，都会关闭快速窗口；焦点回到原来的 App。

原生窗口保留 macOS 的关闭、最小化和缩放按钮。默认尺寸只包裹录词所需内容，也允许在合理范围内调整并记住尺寸。

## Word 和桌面 PDF

最简单的方式是按 `Option + Shift + W`，手动输入单词。

也可以选中单词后按 `Command + C`，再双击：

```text
~/Library/Application Support/Wordflow/macos/add-copied-text.command
```

如果 PDF 是扫描图片，系统必须先通过 OCR 识别文字；Wordflow 本身暂不包含 OCR。

## 设置与更新

本地设置保存在：

```text
~/Library/Application Support/Wordflow/.env
```

窗口中选择的默认牌组与最近读取的牌组列表保存在：

```text
~/Library/Application Support/Wordflow/preferences.json
```

不需要手动编辑这个文件；`ANKI_DECK` 仍作为第一次运行和无法读取 Anki 时的后备牌组。

默认使用 OpenAI `gpt-5.6-luna`，适合高频、成本敏感的结构化制卡。可以修改 `OPENAI_MODEL`。项目使用 Responses API 且设置 `store: false`。

为缩短简单制卡任务的等待时间，默认设置 `OPENAI_REASONING_EFFORT=none`；如更重视复杂语义分析，可改为 `low`。本地服务还会缓存已经确认过的 Anki 牌组与 Note Type，避免每次重复检查。

可选开启发音音频：

```text
ENABLE_TTS=1
TTS_MODEL=tts-1
TTS_VOICE=alloy
```

修改后重启服务：

```bash
launchctl kickstart -k "gui/$(id -u)/com.wordflow.to-anki"
```

更新 GitHub 版本：

```bash
git pull
```

随后重新运行 `install.command`，并在浏览器扩展页面点击扩展的 **Reload**。

## 卸载

双击 `uninstall.command`。它会移除本地服务和安装文件，但不会删除：

- 已经生成的 Anki 卡片
- 浏览器中的扩展（请在扩展页面手动移除）
- 钥匙串中的 API Key

如需同时删除 Key：

```bash
security delete-generic-password -s com.wordflow.openai
```

## Chrome Web Store 与 Arc

这个扩展可以发布到 Chrome Web Store。发布后，Chrome 用户可以一键安装；Arc 是 Chromium 浏览器，也可以直接安装 Chrome Web Store 中的扩展，因此不需要再单独发布一个“Arc 商店版”。

GitHub 仓库和商店不是二选一：

- GitHub 用来公开源码、文档、Issue 和版本更新。
- Chrome Web Store 用来提供更方便、可自动更新的扩展安装。
- 即使扩展上架商店，用户仍需在 Mac 上安装本地服务、Anki 和 AnkiConnect。

上架前还需要准备商店图标、截图、隐私披露与支持页面，注册 Chrome Web Store 开发者账号并支付一次性注册费，然后提交审核。参考 Google 官方的[开发者注册](https://developer.chrome.com/docs/webstore/register)和[发布流程](https://developer.chrome.com/docs/webstore/publish)。Arc 的官方说明见[在 Arc 中使用扩展](https://resources.arc.net/hc/en-us/articles/19434259167767-Extensions-in-Arc-How-to-Import-Add-Open)。

## 隐私与安全

- `.env` 已被 Git 忽略，API Key 默认保存在 macOS 钥匙串。
- 本地服务仅监听 `127.0.0.1:8766`；AnkiConnect 默认监听 `127.0.0.1:8765`。
- 写入接口拒绝普通网页来源，并要求 Wordflow 客户端标识；网页不能直接借用本地服务生成或写入卡片。
- 浏览器捕获会向 OpenAI API 发送：选中文字、最多一小段附近上下文和页面标题；不会上传整个网页或整个文档。
- 页面内容在提示词中被视为数据，不会被当成模型指令执行。
- 页面 URL 会写入本地 Anki 卡片作为来源，但不会放进 OpenAI 请求。
- 使用 OpenAI API 时，请同时遵守 OpenAI 的数据与使用政策。

## 开发与测试

无需第三方 Python 包：

```bash
python3 -m unittest discover -s local_service/tests -v
node --check extension/service-worker.js
node --check extension/content.js
node --check extension/popup.js
native/build-app.sh
```

离线 mock 测试：

```bash
cp .env.example .env
MOCK_OPENAI=1 MOCK_ANKI=1 ./start-service.command
curl -X POST http://127.0.0.1:8766/api/capture \
  -H 'Content-Type: application/json' \
  -H 'X-Wordflow-Client: wordflow-local' \
  -d '{"text":"meticulous","context":"She is meticulous about every detail."}'
```

## License

[MIT](LICENSE)
