const MENU_ID = "wordflow-add-to-anki";
const DEFAULT_SERVICE_URL = "http://127.0.0.1:8766";
let languagePreference = "auto";
let messageCatalog = {};

function t(key, substitutions, fallback = key) {
  const entry = messageCatalog[key];
  if (!entry?.message) return chrome.i18n.getMessage(key, substitutions) || fallback;
  let message = entry.message;
  const values = Array.isArray(substitutions) ? substitutions : substitutions == null ? [] : [substitutions];
  Object.entries(entry.placeholders || {}).forEach(([name, placeholder]) => {
    const index = Number(String(placeholder.content || "").replace("$", "")) - 1;
    const replacement = Number.isInteger(index) && index >= 0 ? String(values[index] ?? "") : "";
    message = message.replace(new RegExp(`\\$${name}\\$`, "gi"), replacement);
  });
  return message;
}

function systemLanguageCode() {
  return chrome.i18n.getUILanguage().toLowerCase().startsWith("zh") ? "zh" : "en";
}

function languageCode() {
  return ["zh", "en"].includes(languagePreference) ? languagePreference : systemLanguageCode();
}

async function loadMessageCatalog() {
  const locale = languageCode() === "zh" ? "zh_CN" : "en";
  try {
    const response = await fetch(chrome.runtime.getURL(`_locales/${locale}/messages.json`));
    messageCatalog = await response.json();
  } catch (_error) {
    messageCatalog = {};
  }
}

function friendlyMessage(error) {
  const message = String(error?.message || error || t("errorGeneric", undefined, "Something went wrong")).trim();
  if (/Anki 启动失败|could not open Anki/i.test(message)) {
    return t("ankiLaunchFailed", undefined, "Could not open Anki");
  }
  if (/AnkiConnect|Anki 未连接|连接中断|Anki is not connected/i.test(message)) {
    return t("ankiDisconnected", undefined, "Anki is not connected");
  }
  if (/OPENAI_API_KEY|API Key/i.test(message)) return t("apiKeyMissing", undefined, "Set up your OpenAI API key first");
  if (/OpenAI|网络连接失败|network error/i.test(message)) return t("networkFailed", undefined, "Network error — try again");
  if (/Failed to fetch|could not connect|本地服务|local service/i.test(message)) {
    return t("serviceDisconnected", undefined, "Wordflow service is not connected");
  }
  const limit = languageCode() === "zh" ? 42 : 58;
  return message.length > limit ? `${message.slice(0, limit - 1)}…` : message;
}

function installContextMenu() {
  chrome.contextMenus.removeAll(() => {
    chrome.contextMenus.create({
      id: MENU_ID,
      title: t("contextMenuTitle", undefined, "Add to Anki: %s"),
      contexts: ["selection"]
    });
  });
}

async function refreshContextMenu() {
  await loadLanguagePreference();
  await loadMessageCatalog();
  installContextMenu();
}

chrome.runtime.onInstalled.addListener(() => refreshContextMenu());
chrome.runtime.onStartup.addListener(() => refreshContextMenu());

async function settings() {
  return chrome.storage.sync.get({
    serviceUrl: DEFAULT_SERVICE_URL,
    languagePreference: "auto"
  });
}

async function loadLanguagePreference() {
  const saved = await settings();
  if (["auto", "zh", "en"].includes(saved.languagePreference)) {
    languagePreference = saved.languagePreference;
  }
  try {
    const response = await fetch(`${saved.serviceUrl.replace(/\/$/, "")}/api/settings`, {
      headers: { "X-Wordflow-Client": "wordflow-local" }
    });
    const data = await response.json();
    if (response.ok && data.ok && ["auto", "zh", "en"].includes(data.language)) {
      languagePreference = data.language;
      await chrome.storage.sync.set({ languagePreference });
    }
  } catch (_error) {
    // The browser's saved or automatic language remains available offline.
  }
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
  await loadLanguagePreference();
  await loadMessageCatalog();
  payload.language = languageCode();
  const { serviceUrl } = await settings();
  try {
    const response = await fetch(`${serviceUrl.replace(/\/$/, "")}/api/capture`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-Wordflow-Client": "wordflow-local"
      },
      body: JSON.stringify(payload)
    });
    const data = await response.json();
    if (!response.ok || !data.ok) throw new Error(data.error || `HTTP ${response.status}`);

    if (data.duplicate) {
      await showResult(
        tabId,
        t("duplicateInAnki", [data.card.word], `“${data.card.word}” is already in Anki`),
        "duplicate"
      );
    } else {
      await showResult(tabId, t("addedToAnki", [data.card.word], `Added to Anki: ${data.card.word}`), "success");
    }
    return data;
  } catch (error) {
    await showResult(tabId, friendlyMessage(error), "error");
    throw error;
  }
}

async function openManualInput() {
  const { serviceUrl } = await settings();
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 1500);
  try {
    const response = await fetch(`${serviceUrl.replace(/\/$/, "")}/api/window/open`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-Wordflow-Client": "wordflow-local"
      },
      body: "{}",
      signal: controller.signal
    });
    const data = await response.json();
    if (response.ok && data.ok) return;
  } catch (_error) {
    // The browser window below keeps manual capture usable without the native companion.
  } finally {
    clearTimeout(timeout);
  }

  try {
    const previousWindow = await chrome.windows.getLastFocused({ windowTypes: ["normal"] });
    if (previousWindow?.id) {
      await chrome.storage.session.set({ manualInputReturnWindowId: previousWindow.id });
    }
  } catch (_error) {
    // The fallback popup still works even if Arc cannot report its previous window.
  }

  await chrome.windows.create({
    url: chrome.runtime.getURL("popup.html"),
    type: "popup",
    width: 460,
    height: 520,
    focused: true
  });
}

chrome.action.onClicked.addListener(() => openManualInput());

chrome.runtime.onMessage.addListener((message) => {
  if (message?.type === "LANGUAGE_CHANGED" && ["auto", "zh", "en"].includes(message.language)) {
    languagePreference = message.language;
    loadMessageCatalog().then(installContextMenu);
  }
});

chrome.contextMenus.onClicked.addListener(async (info, tab) => {
  if (info.menuItemId !== MENU_ID) return;
  const selected = (info.selectionText || "").trim();
  const pageContext = await getContext(tab?.id);
  await capture({
    text: selected || pageContext.text,
    context: pageContext.context,
    language: languageCode(),
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
  await loadLanguagePreference();
  await loadMessageCatalog();
  const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
  const selected = await getContext(tab?.id);
  if (!selected.text) {
    await showResult(tab?.id, t("selectionRequired", undefined, "Select a word or phrase first"), "error");
    return;
  }
  await capture({
    text: selected.text,
    context: selected.context,
    language: languageCode(),
    source_title: tab?.title || "",
    source_url: tab?.url || "",
    source_type: "browser"
  }, tab?.id).catch(() => {});
});
