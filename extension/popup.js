const DEFAULT_SERVICE_URL = "http://127.0.0.1:8766";
const $ = (selector) => document.querySelector(selector);
let resultClearTimer;

function t(key, substitutions, fallback = key) {
  return chrome.i18n.getMessage(key, substitutions) || fallback;
}

function languageCode() {
  return chrome.i18n.getUILanguage().toLowerCase().startsWith("zh") ? "zh" : "en";
}

function localizePage() {
  document.documentElement.lang = languageCode() === "zh" ? "zh-CN" : "en";
  document.querySelectorAll("[data-i18n]").forEach((element) => {
    element.textContent = t(element.dataset.i18n, undefined, element.textContent);
  });
  document.querySelectorAll("[data-i18n-placeholder]").forEach((element) => {
    element.placeholder = t(element.dataset.i18nPlaceholder, undefined, element.placeholder);
  });
}

function setResult(message, { error = false, clearAfter = 0 } = {}) {
  clearTimeout(resultClearTimer);
  const result = $("#result");
  result.className = error ? "error" : "";
  result.textContent = message;
  if (clearAfter > 0 && message) {
    resultClearTimer = setTimeout(() => {
      if (result.textContent === message) result.textContent = "";
    }, clearAfter);
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

async function getServiceUrl() {
  const data = await chrome.storage.sync.get({ serviceUrl: DEFAULT_SERVICE_URL });
  return data.serviceUrl.replace(/\/$/, "");
}

async function checkHealth() {
  try {
    const response = await fetch(`${await getServiceUrl()}/health`);
    const data = await response.json();
    if (!data.anki?.ok) throw new Error(data.anki?.error || t("ankiDisconnected", undefined, "Anki is not connected"));
  } catch (_error) {
    setResult(friendlyMessage(_error), { error: true, clearAfter: 10000 });
  }
}

function clientHeaders() {
  return {
    "Content-Type": "application/json",
    "X-Wordflow-Client": "wordflow-local"
  };
}

async function returnToPreviousBrowserWindow() {
  try {
    const { manualInputReturnWindowId } = await chrome.storage.session.get("manualInputReturnWindowId");
    if (Number.isInteger(manualInputReturnWindowId)) {
      await chrome.windows.update(manualInputReturnWindowId, { focused: true });
      return;
    }
  } catch (_error) {
    // Losing focus is still preferable to closing the user's input window.
  }
  window.blur();
}

async function loadDecks() {
  const deck = $("#deck");
  try {
    const response = await fetch(`${await getServiceUrl()}/api/decks`, {
      headers: clientHeaders()
    });
    const data = await response.json();
    if (!response.ok || !data.ok || !Array.isArray(data.decks) || !data.decks.length) {
      throw new Error(data.error || t("decksLoadFailed", undefined, "Could not load Anki decks"));
    }
    deck.replaceChildren(...data.decks.map((name) => new Option(name, name)));
    deck.value = data.selected;
    deck.disabled = false;
  } catch (error) {
    setResult(friendlyMessage(error), { error: true, clearAfter: 10000 });
  }
}

async function saveDeck() {
  const response = await fetch(`${await getServiceUrl()}/api/decks/select`, {
    method: "POST",
    headers: clientHeaders(),
    body: JSON.stringify({ deck: $("#deck").value })
  });
  const data = await response.json();
  if (!response.ok || !data.ok) throw new Error(data.error || t("deckSaveFailed", undefined, "Could not save the deck choice"));
}

async function addWord(returnAfterSave = false) {
  const word = $("#word").value.trim();
  if (!word) {
    setResult(t("wordRequired", undefined, "Enter a word or phrase first"), { error: true, clearAfter: 10000 });
    return;
  }
  const button = $("#add");
  button.disabled = true;
  setResult(t("generating", undefined, "Creating your card…"));
  try {
    const response = await fetch(`${await getServiceUrl()}/api/capture`, {
      method: "POST",
      headers: clientHeaders(),
      body: JSON.stringify({
        text: word,
        context: $("#context").value.trim(),
        deck: $("#deck").value,
        language: languageCode(),
        source_title: t("sourceManual", undefined, "Wordflow manual input"),
        source_url: "",
        source_type: "browser-manual"
      })
    });
    const data = await response.json();
    if (!response.ok || !data.ok) throw new Error(data.error || `HTTP ${response.status}`);
    const message = data.duplicate
      ? t("duplicateInDeck", [data.card.word, data.deck], `“${data.card.word}” already exists in ${data.deck}`)
      : t("addedToDeck", [data.deck, data.card.word], `Added to ${data.deck}: ${data.card.word}`);
    setResult(message, { clearAfter: 6000 });
    if (!data.duplicate) {
      $("#word").value = "";
      $("#context").value = "";
    }
    if (returnAfterSave) await returnToPreviousBrowserWindow();
  } catch (error) {
    setResult(friendlyMessage(error), { error: true, clearAfter: 10000 });
  } finally {
    button.disabled = false;
  }
}

document.addEventListener("DOMContentLoaded", async () => {
  localizePage();
  $("#word").focus();
  checkHealth();
  loadDecks();
});
$("#add").addEventListener("click", addWord);
$("#deck").addEventListener("change", () => {
  saveDeck().catch((error) => {
    setResult(friendlyMessage(error), { error: true, clearAfter: 10000 });
  });
});
$("#word").addEventListener("keydown", (event) => {
  if (event.key === "Enter") {
    event.preventDefault();
    event.stopPropagation();
    addWord(event.metaKey || event.ctrlKey);
  } else if (event.key === "ArrowDown") {
    event.preventDefault();
    $("#context").focus();
  }
});
$("#context").addEventListener("keydown", (event) => {
  if (event.key === "Enter" && (event.metaKey || event.ctrlKey)) {
    event.preventDefault();
    event.stopPropagation();
    addWord(true);
  }
});
document.addEventListener("keydown", (event) => {
  if (event.key === "Enter" && (event.metaKey || event.ctrlKey)) {
    event.preventDefault();
    addWord(true);
    return;
  }
  if (event.key.toLowerCase() === "d" && (event.metaKey || event.ctrlKey)) {
    event.preventDefault();
    $("#deck").focus();
    return;
  }
  if (event.key === "Escape") window.close();
});
