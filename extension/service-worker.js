const MENU_ID = "wordflow-add-to-anki";
const DEFAULT_SERVICE_URL = "http://127.0.0.1:8766";

chrome.runtime.onInstalled.addListener(() => {
  chrome.contextMenus.removeAll(() => {
    chrome.contextMenus.create({
      id: MENU_ID,
      title: "加入 Anki：%s",
      contexts: ["selection"]
    });
  });
});

async function settings() {
  return chrome.storage.sync.get({ serviceUrl: DEFAULT_SERVICE_URL });
}

async function getContext(tabId) {
  if (!tabId) return { text: "", context: "" };
  try {
    return await chrome.tabs.sendMessage(tabId, { type: "GET_SELECTION_CONTEXT" });
  } catch (_error) {
    return { text: "", context: "" };
  }
}

async function showResult(tabId, message, kind) {
  try {
    await chrome.tabs.sendMessage(tabId, { type: "SHOW_CAPTURE_RESULT", message, kind });
  } catch (_error) {
    await chrome.action.setBadgeBackgroundColor({ color: kind === "error" ? "#B42318" : "#067647" });
    await chrome.action.setBadgeText({ text: kind === "error" ? "ERR" : "OK", tabId });
    setTimeout(() => chrome.action.setBadgeText({ text: "", tabId }), 3500);
  }
}

async function capture(payload, tabId) {
  const { serviceUrl } = await settings();
  try {
    const response = await fetch(`${serviceUrl.replace(/\/$/, "")}/api/capture`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payload)
    });
    const data = await response.json();
    if (!response.ok || !data.ok) throw new Error(data.error || `HTTP ${response.status}`);

    if (data.duplicate) {
      await showResult(tabId, `“${data.card.word}” 已经在 Anki 里`, "duplicate");
    } else {
      await showResult(tabId, `已加入 Anki：${data.card.word}`, "success");
    }
    return data;
  } catch (error) {
    await showResult(tabId, `加入失败：${error.message}`, "error");
    throw error;
  }
}

async function openManualInput() {
  const popupUrl = chrome.runtime.getURL("popup.html");
  await chrome.windows.create({
    url: popupUrl,
    type: "popup",
    width: 380,
    height: 520,
    focused: true
  });
}

chrome.contextMenus.onClicked.addListener(async (info, tab) => {
  if (info.menuItemId !== MENU_ID) return;
  const selected = (info.selectionText || "").trim();
  const pageContext = await getContext(tab?.id);
  await capture({
    text: selected || pageContext.text,
    context: pageContext.context,
    source_title: tab?.title || "",
    source_url: info.pageUrl || tab?.url || "",
    source_type: "browser"
  }, tab?.id).catch(() => {});
});

chrome.commands.onCommand.addListener(async (command) => {
  if (command === "open-manual-input") {
    await openManualInput();
    return;
  }
  if (command !== "capture-selection") return;
  const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
  const selected = await getContext(tab?.id);
  if (!selected.text) {
    await showResult(tab?.id, "请先选中一个单词或短语", "error");
    return;
  }
  await capture({
    text: selected.text,
    context: selected.context,
    source_title: tab?.title || "",
    source_url: tab?.url || "",
    source_type: "browser"
  }, tab?.id).catch(() => {});
});
