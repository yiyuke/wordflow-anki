#!/usr/bin/env node

import fs from "node:fs/promises";
import path from "node:path";
import { createRequire } from "node:module";
import { fileURLToPath } from "node:url";

const require = createRequire(import.meta.url);
let sharp;
let chromium;
try {
  sharp = require("sharp");
  ({ chromium } = require("playwright"));
} catch (_error) {
  console.error("This maintainer script requires the sharp and playwright packages.");
  console.error("Run it with the bundled Codex workspace Node dependencies or install those packages locally.");
  process.exit(1);
}

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const output = path.join(root, "assets", "chrome-web-store");
const logoPath = path.join(root, "assets", "wordflow-logo.png");
const iconPath = path.join(root, "extension", "icons", "icon128.png");
const popupCss = await fs.readFile(path.join(root, "extension", "popup.css"), "utf8");
const logoBase64 = (await fs.readFile(logoPath)).toString("base64");

await fs.mkdir(output, { recursive: true });
await fs.copyFile(iconPath, path.join(output, "icon-128.png"));

function articleHtml(locale) {
  const isChinese = locale === "zh";
  const toast = isChinese ? "已加入 Anki：serendipity" : "Added to Anki: serendipity";
  const eyebrow = isChinese ? "阅读中的真实语境" : "A word in its real context";
  const caption = isChinese
    ? "选中生词，Wordflow 会保留有限的原句语境并送入 Anki。"
    : "Select a word. Wordflow keeps its limited context and sends it to Anki.";
  return `<!doctype html>
  <html lang="${isChinese ? "zh-CN" : "en"}">
  <head>
    <meta charset="utf-8">
    <style>
      * { box-sizing: border-box; }
      ::selection { color: #101828; background: #e8f5ed; }
      html, body { width: 1280px; height: 800px; margin: 0; }
      body {
        overflow: hidden; color: #182230; background: #fbfcfa;
        font-family: ui-serif, Georgia, "Times New Roman", serif;
      }
      nav {
        height: 76px; display: flex; align-items: center; justify-content: space-between;
        padding: 0 70px; border-bottom: 1px solid #e4e7ec; background: rgba(255,255,255,.96);
        font: 650 14px/1 -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
      }
      .brand { display: flex; align-items: center; gap: 12px; color: #067647; }
      .brand img { width: 34px; height: 34px; }
      .reading { color: #667085; letter-spacing: .02em; }
      main { width: 860px; margin: 82px auto 0; }
      .eyebrow {
        color: #067647; font: 750 15px/1.2 -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
        letter-spacing: .08em; text-transform: uppercase;
      }
      h1 { margin: 22px 0 24px; font-size: 68px; line-height: 1.02; letter-spacing: -.045em; }
      .lede { margin: 0 0 28px; color: #344054; font-size: 28px; line-height: 1.55; }
      .caption {
        width: 720px; margin-top: 32px; padding-top: 24px; border-top: 1px solid #d0d5dd;
        color: #667085; font: 550 17px/1.55 -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
      }
      #wordflow-anki-toast {
        position: fixed; z-index: 2147483647; right: 38px; bottom: 34px;
        max-width: 360px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap;
        padding: 14px 18px; border-radius: 10px; color: white; background: #067647;
        box-shadow: 0 10px 34px rgba(0,0,0,.24);
        font: 650 15px/1.4 -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
      }
    </style>
  </head>
  <body>
    <nav>
      <div class="brand"><img src="data:image/png;base64,${logoBase64}" alt=""> Wordflow reading demo</div>
      <div class="reading">Collect → Understand → Review → Use</div>
    </nav>
    <main>
      <div class="eyebrow">${eyebrow}</div>
      <h1>Words worth keeping</h1>
      <p class="lede"><span id="selected-word">Serendipity</span> is an unplanned fortunate discovery — the kind of word that becomes easier to remember when it stays connected to the sentence where you found it.</p>
      <p class="caption">${caption}</p>
    </main>
    <div id="wordflow-anki-toast">${toast}</div>
    <script>
      const range = document.createRange();
      range.selectNodeContents(document.getElementById("selected-word"));
      const selection = window.getSelection();
      selection.removeAllRanges();
      selection.addRange(range);
    </script>
  </body>
  </html>`;
}

function popupPreviewHtml(locale) {
  const isChinese = locale === "zh";
  const copy = isChinese
    ? {
        title: "快速添加到 Anki",
        open: "打开窗口：⌥⇧W",
        language: "自动",
        word: "单词或短语",
        deck: "保存到 Anki 牌组",
        context: "例句或上下文（可选）",
        button: "生成并加入 Anki",
        hint: "↓/Tab 移动 · ⌘D 牌组 · ⌘↩ 保存并返回 · Esc 关闭"
      }
    : {
        title: "Quick Add to Anki",
        open: "Open window: ⌥⇧W",
        language: "Auto",
        word: "Word or phrase",
        deck: "Save to Anki deck",
        context: "Example or context (optional)",
        button: "Generate and add to Anki",
        hint: "↓/Tab move · ⌘D deck · ⌘↩ save & return · Esc close"
      };
  return `<!doctype html>
  <html lang="${isChinese ? "zh-CN" : "en"}">
  <head>
    <meta charset="utf-8">
    <style>${popupCss}</style>
    <style>
      html, body { width: 460px; height: 520px; overflow: hidden; }
      main { padding-top: 36px; }
      textarea { resize: none; }
    </style>
  </head>
  <body>
    <main>
      <header>
        <div><h1>${copy.title}</h1><p>${copy.open}</p></div>
        <button class="select-trigger" style="width:88px;height:32px;padding:5px 9px 5px 10px;font-size:12px;font-weight:650">
          <span>${copy.language}</span><span class="select-chevron"></span>
        </button>
      </header>
      <label>${copy.word}</label>
      <input value="serendipity">
      <label>${copy.deck}</label>
      <button class="select-trigger"><span>Vocabulary Inbox</span><span class="select-chevron"></span></button>
      <label>${copy.context}</label>
      <textarea rows="3">We met by pure serendipity.</textarea>
      <button id="add">${copy.button}</button>
      <p id="result"></p>
      <p class="hint">${copy.hint}</p>
    </main>
  </body>
  </html>`;
}

function compositionHtml(locale, popupDataUrl) {
  const isChinese = locale === "zh";
  const title = isChinese ? "从任何地方捕捉生词" : "Capture words from anywhere";
  const body = isChinese
    ? "PDF、Word、视频或播客里遇到的词，按 ⌥⇧W 就能快速记录。"
    : "PDFs, documents, videos, and podcasts. Press ⌥⇧W and keep reading.";
  return `<!doctype html>
  <html lang="${isChinese ? "zh-CN" : "en"}">
  <head>
    <meta charset="utf-8">
    <style>
      * { box-sizing: border-box; }
      html, body { width: 1280px; height: 800px; margin: 0; overflow: hidden; }
      body {
        display: grid; grid-template-columns: 1fr 520px; align-items: center; gap: 72px;
        padding: 64px 86px; color: #10271e; background:
          radial-gradient(circle at 12% 8%, rgba(23,178,106,.17), transparent 34%),
          linear-gradient(135deg, #f8fcf9 0%, #e7f6ed 100%);
        font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
      }
      .copy img { width: 72px; height: 72px; margin-bottom: 34px; }
      h1 { max-width: 560px; margin: 0; font-size: ${isChinese ? 54 : 62}px; line-height: 1.04; letter-spacing: -.045em; }
      p { max-width: 520px; margin: 28px 0 0; color: #475467; font-size: 23px; line-height: 1.5; }
      .flow { margin-top: 42px; color: #067647; font-size: 16px; font-weight: 750; letter-spacing: .02em; }
      .window {
        overflow: hidden; border: 1px solid rgba(16,39,30,.14); border-radius: 18px;
        background: #f8fafc; box-shadow: 0 28px 70px rgba(16,39,30,.22);
      }
      .titlebar {
        height: 34px; display: flex; align-items: center; gap: 8px; padding: 0 14px;
        border-bottom: 1px solid #e4e7ec; background: rgba(255,255,255,.94);
      }
      .dot { width: 10px; height: 10px; border-radius: 50%; background: #d0d5dd; }
      .window img { display: block; width: 460px; height: 520px; }
    </style>
  </head>
  <body>
    <section class="copy">
      <img src="data:image/png;base64,${logoBase64}" alt="">
      <h1>${title}</h1>
      <p>${body}</p>
      <div class="flow">Collect → Understand → Review → Use</div>
    </section>
    <section class="window">
      <div class="titlebar"><span class="dot"></span><span class="dot"></span><span class="dot"></span></div>
      <img src="${popupDataUrl}" alt="">
    </section>
  </body>
  </html>`;
}

function marketingSvg(width, height, kind) {
  const isSmall = kind === "small";
  const logoSize = isSmall ? 104 : 250;
  const logoX = isSmall ? 38 : 92;
  const logoY = Math.round((height - logoSize) / 2);
  const titleX = isSmall ? 166 : 410;
  const titleY = isSmall ? 116 : 245;
  const titleSize = isSmall ? 39 : 88;
  const subtitleSize = isSmall ? 18 : 35;
  const subtitle = isSmall ? "Catch it. Learn it. Keep it." : "Remember the words you actually encounter.";
  return Buffer.from(`<svg width="${width}" height="${height}" xmlns="http://www.w3.org/2000/svg">
    <defs>
      <linearGradient id="bg" x1="0" y1="0" x2="1" y2="1">
        <stop offset="0" stop-color="#052e22"/>
        <stop offset="1" stop-color="#067647"/>
      </linearGradient>
      <radialGradient id="glow" cx=".88" cy=".12" r=".75">
        <stop offset="0" stop-color="#6ce9a6" stop-opacity=".32"/>
        <stop offset="1" stop-color="#6ce9a6" stop-opacity="0"/>
      </radialGradient>
    </defs>
    <rect width="${width}" height="${height}" fill="url(#bg)"/>
    <rect width="${width}" height="${height}" fill="url(#glow)"/>
    <image href="data:image/png;base64,${logoBase64}" x="${logoX}" y="${logoY}" width="${logoSize}" height="${logoSize}"/>
    <text x="${titleX}" y="${titleY}" fill="#ffffff" font-family="-apple-system,BlinkMacSystemFont,Segoe UI,sans-serif" font-size="${titleSize}" font-weight="750" letter-spacing="-2">Wordflow</text>
    <text x="${titleX}" y="${titleY + (isSmall ? 40 : 70)}" fill="#d1fadf" font-family="-apple-system,BlinkMacSystemFont,Segoe UI,sans-serif" font-size="${subtitleSize}" font-weight="550">${subtitle}</text>
  </svg>`);
}

const systemChrome = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome";
const executablePath = await fs.access(systemChrome).then(() => systemChrome).catch(() => undefined);
const browser = await chromium.launch({ headless: true, executablePath });
try {
  for (const locale of ["en", "zh"]) {
    const capturePage = await browser.newPage({ viewport: { width: 1280, height: 800 }, deviceScaleFactor: 1 });
    await capturePage.setContent(articleHtml(locale), { waitUntil: "load" });
    await capturePage.screenshot({
      path: path.join(output, `screenshot-capture-${locale}-1280x800.png`)
    });
    await capturePage.close();

    const popupPage = await browser.newPage({ viewport: { width: 460, height: 520 }, deviceScaleFactor: 1 });
    await popupPage.setContent(popupPreviewHtml(locale), { waitUntil: "load" });
    const popupBytes = await popupPage.screenshot();
    await popupPage.close();
    const popupDataUrl = `data:image/png;base64,${popupBytes.toString("base64")}`;

    const quickAddPage = await browser.newPage({ viewport: { width: 1280, height: 800 }, deviceScaleFactor: 1 });
    await quickAddPage.setContent(compositionHtml(locale, popupDataUrl), { waitUntil: "load" });
    await quickAddPage.screenshot({
      path: path.join(output, `screenshot-quick-add-${locale}-1280x800.png`)
    });
    await quickAddPage.close();
  }
} finally {
  await browser.close();
}

await sharp(marketingSvg(440, 280, "small"))
  .png()
  .toFile(path.join(output, "small-promo-440x280.png"));

await sharp(marketingSvg(1400, 560, "marquee"))
  .png()
  .toFile(path.join(output, "marquee-promo-1400x560.png"));

for (const file of await fs.readdir(output)) {
  const metadata = await sharp(path.join(output, file)).metadata();
  console.log(`${file}: ${metadata.width}x${metadata.height}`);
}
