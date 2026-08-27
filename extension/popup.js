const DEFAULT_SERVICE_URL = "http://127.0.0.1:8766";
const $ = (selector) => document.querySelector(selector);
let resultClearTimer;
let languagePreference = "auto";
let learningMode = "full";
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

function localizePage() {
  document.documentElement.lang = languageCode() === "zh" ? "zh-CN" : "en";
  document.querySelectorAll("[data-i18n]").forEach((element) => {
    element.textContent = t(element.dataset.i18n, undefined, element.textContent);
  });
  document.querySelectorAll("[data-i18n-placeholder]").forEach((element) => {
    element.placeholder = t(element.dataset.i18nPlaceholder, undefined, element.placeholder);
  });
  document.querySelectorAll("[data-i18n-aria-label]").forEach((element) => {
    element.setAttribute("aria-label", t(element.dataset.i18nAriaLabel, undefined, element.getAttribute("aria-label")));
  });
  document.querySelectorAll("[data-i18n-title]").forEach((element) => {
    element.title = t(element.dataset.i18nTitle, undefined, element.title);
  });
  $("#language").value = languagePreference;
  $("#learning-mode").value = learningMode;
  refreshSelectDisplay("language");
  refreshSelectDisplay("learning-mode");
  refreshSelectDisplay("deck");
}

function selectParts(name) {
  const root = document.querySelector(`[data-select="${name}"]`);
  return {
    root,
    input: $(`#${name}`),
    trigger: $(`#${name}-trigger`),
    menu: $(`#${name}-listbox`)
  };
}

function refreshSelectDisplay(name) {
  const { root, input, trigger, menu } = selectParts(name);
  if (!root || !input || !trigger || !menu) return;
  const options = [...menu.querySelectorAll(".select-option")];
  const selected = options.find((option) => option.dataset.value === input.value);
  trigger.querySelector(".select-value").textContent = selected?.textContent.trim() || input.value;
  options.forEach((option) => {
    option.setAttribute("aria-selected", String(option === selected));
  });
}

function closeSelect(name, restoreFocus = false) {
  const { trigger, menu } = selectParts(name);
  if (!trigger || !menu || menu.hidden) return false;
  menu.hidden = true;
  trigger.setAttribute("aria-expanded", "false");
  if (restoreFocus) trigger.focus();
  return true;
}

function closeAllSelects(except = "") {
  let closed = false;
  document.querySelectorAll("[data-select]").forEach((root) => {
    if (root.dataset.select !== except) {
      closed = closeSelect(root.dataset.select) || closed;
    }
  });
  return closed;
}

function openSelect(name, focusPosition = "selected") {
  const { input, trigger, menu } = selectParts(name);
  if (!input || !trigger || !menu || trigger.disabled) return;
  closeAllSelects(name);
  menu.hidden = false;
  trigger.setAttribute("aria-expanded", "true");
  const options = [...menu.querySelectorAll(".select-option")];
  if (!options.length || focusPosition === "none") return;
  const selectedIndex = options.findIndex((option) => option.dataset.value === input.value);
  const targetIndex = focusPosition === "last"
    ? options.length - 1
    : selectedIndex >= 0
      ? selectedIndex
      : 0;
  options[targetIndex].focus();
}

function chooseSelectOption(name, value) {
  const { input } = selectParts(name);
  if (!input) return;
  const changed = input.value !== value;
  input.value = value;
  refreshSelectDisplay(name);
  closeSelect(name, true);
  if (changed) input.dispatchEvent(new Event("change", { bubbles: true }));
}

function setSelectOptions(name, values, selectedValue) {
  const { input, trigger, menu } = selectParts(name);
  if (!input || !trigger || !menu) return;
  menu.replaceChildren(
    ...values.map(({ value, label }) => {
      const option = document.createElement("button");
      option.type = "button";
      option.className = "select-option";
      option.setAttribute("role", "option");
      option.dataset.value = value;
      option.textContent = label;
      return option;
    })
  );
  input.value = values.some((option) => option.value === selectedValue)
    ? selectedValue
    : values[0]?.value || "";
  trigger.disabled = values.length === 0;
  refreshSelectDisplay(name);
}

function setupSelect(name) {
  const { root, trigger, menu } = selectParts(name);
  if (!root || !trigger || !menu) return;

  trigger.addEventListener("click", () => {
    if (menu.hidden) openSelect(name, "none");
    else closeSelect(name);
  });
  trigger.addEventListener("keydown", (event) => {
    if (["Enter", " ", "ArrowDown", "ArrowUp"].includes(event.key)) {
      event.preventDefault();
      openSelect(name, event.key === "ArrowUp" ? "last" : "selected");
    }
  });
  menu.addEventListener("click", (event) => {
    const option = event.target.closest(".select-option");
    if (option) chooseSelectOption(name, option.dataset.value);
  });
  menu.addEventListener("keydown", (event) => {
    const options = [...menu.querySelectorAll(".select-option")];
    const currentIndex = options.indexOf(document.activeElement);
    let nextIndex = currentIndex;
    if (event.key === "ArrowDown") nextIndex = Math.min(currentIndex + 1, options.length - 1);
    else if (event.key === "ArrowUp") nextIndex = Math.max(currentIndex - 1, 0);
    else if (event.key === "Home") nextIndex = 0;
    else if (event.key === "End") nextIndex = options.length - 1;
    else if (["Enter", " "].includes(event.key) && currentIndex >= 0) {
      event.preventDefault();
      chooseSelectOption(name, options[currentIndex].dataset.value);
      return;
    } else if (event.key === "Escape") {
      event.preventDefault();
      event.stopPropagation();
      closeSelect(name, true);
      return;
    } else {
      return;
    }
    event.preventDefault();
    options[nextIndex]?.focus();
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

async function loadPreferences() {
  const stored = await chrome.storage.sync.get({
    languagePreference: "auto",
    learningMode: "full"
  });
  if (["auto", "zh", "en"].includes(stored.languagePreference)) {
    languagePreference = stored.languagePreference;
  }
  if (["full", "exam"].includes(stored.learningMode)) {
    learningMode = stored.learningMode;
  }
  try {
    const response = await fetch(`${await getServiceUrl()}/api/settings`, {
      headers: clientHeaders()
    });
    const data = await response.json();
    if (response.ok && data.ok && ["auto", "zh", "en"].includes(data.language)) {
      languagePreference = data.language;
    }
    if (response.ok && data.ok && ["full", "exam"].includes(data.learning_mode)) {
      learningMode = data.learning_mode;
    }
    await chrome.storage.sync.set({ languagePreference, learningMode });
  } catch (_error) {
    // The saved browser preference and automatic language remain available offline.
  }
}

async function saveLearningMode() {
  learningMode = $("#learning-mode").value;
  await chrome.storage.sync.set({ learningMode });
  const response = await fetch(`${await getServiceUrl()}/api/settings/learning-mode`, {
    method: "POST",
    headers: clientHeaders(),
    body: JSON.stringify({ learning_mode: learningMode })
  });
  const data = await response.json();
  if (!response.ok || !data.ok) {
    throw new Error(data.error || t("learningModeSaveFailed", undefined, "Could not save the learning mode"));
  }
}

async function saveLanguagePreference() {
  languagePreference = $("#language").value;
  await chrome.storage.sync.set({ languagePreference });
  await loadMessageCatalog();
  localizePage();
  chrome.runtime.sendMessage({ type: "LANGUAGE_CHANGED", language: languagePreference }).catch(() => {});
  const response = await fetch(`${await getServiceUrl()}/api/settings/language`, {
    method: "POST",
    headers: clientHeaders(),
    body: JSON.stringify({ language: languagePreference })
  });
  const data = await response.json();
  if (!response.ok || !data.ok) {
    throw new Error(data.error || t("languageSaveFailed", undefined, "Could not save the language"));
  }
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
  try {
    const response = await fetch(`${await getServiceUrl()}/api/decks`, {
      headers: clientHeaders()
    });
    const data = await response.json();
    if (!response.ok || !data.ok || !Array.isArray(data.decks) || !data.decks.length) {
      throw new Error(data.error || t("decksLoadFailed", undefined, "Could not load Anki decks"));
    }
    setSelectOptions(
      "deck",
      data.decks.map((name) => ({ value: name, label: name })),
      data.selected
    );
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
        learning_mode: learningMode,
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

setupSelect("language");
setupSelect("learning-mode");
setupSelect("deck");
document.addEventListener("click", (event) => {
  if (!event.target.closest("[data-select]")) closeAllSelects();
});

document.addEventListener("DOMContentLoaded", async () => {
  await loadPreferences();
  await loadMessageCatalog();
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
$("#language").addEventListener("change", () => {
  saveLanguagePreference().catch((error) => {
    setResult(friendlyMessage(error), { error: true, clearAfter: 10000 });
  });
});
$("#learning-mode").addEventListener("change", () => {
  saveLearningMode().catch((error) => {
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
    $("#deck-trigger").focus();
    openSelect("deck");
    return;
  }
  if (event.key === "Escape" && !closeAllSelects()) window.close();
});
