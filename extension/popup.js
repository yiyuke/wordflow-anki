const DEFAULT_SERVICE_URL = "http://127.0.0.1:8766";
const $ = (selector) => document.querySelector(selector);

async function getServiceUrl() {
  const data = await chrome.storage.sync.get({ serviceUrl: DEFAULT_SERVICE_URL });
  return data.serviceUrl.replace(/\/$/, "");
}

async function checkHealth() {
  try {
    const response = await fetch(`${await getServiceUrl()}/health`);
    const data = await response.json();
    if (!data.anki?.ok) throw new Error("请先打开 Anki");
  } catch (_error) {
    const result = $("#result");
    result.className = "error";
    result.textContent = _error.message || "Wordflow 本地服务未启动";
  }
}

function clientHeaders() {
  return {
    "Content-Type": "application/json",
    "X-Wordflow-Client": "wordflow-local"
  };
}

async function loadDecks() {
  const deck = $("#deck");
  try {
    const response = await fetch(`${await getServiceUrl()}/api/decks`, {
      headers: clientHeaders()
    });
    const data = await response.json();
    if (!response.ok || !data.ok || !Array.isArray(data.decks) || !data.decks.length) {
      throw new Error(data.error || "无法读取牌组");
    }
    deck.replaceChildren(...data.decks.map((name) => new Option(name, name)));
    deck.value = data.selected;
    deck.disabled = false;
  } catch (error) {
    const result = $("#result");
    result.className = "error";
    result.textContent = error.message;
  }
}

async function saveDeck() {
  const response = await fetch(`${await getServiceUrl()}/api/decks/select`, {
    method: "POST",
    headers: clientHeaders(),
    body: JSON.stringify({ deck: $("#deck").value })
  });
  const data = await response.json();
  if (!response.ok || !data.ok) throw new Error(data.error || "牌组选择未保存");
}

async function addWord() {
  const word = $("#word").value.trim();
  if (!word) return;
  const button = $("#add");
  const result = $("#result");
  button.disabled = true;
  result.className = "";
  result.textContent = "正在生成词卡…";
  try {
    const response = await fetch(`${await getServiceUrl()}/api/capture`, {
      method: "POST",
      headers: clientHeaders(),
      body: JSON.stringify({
        text: word,
        context: $("#context").value.trim(),
        deck: $("#deck").value,
        source_title: "Arc 扩展手动输入",
        source_url: "",
        source_type: "browser-manual"
      })
    });
    const data = await response.json();
    if (!response.ok || !data.ok) throw new Error(data.error || `HTTP ${response.status}`);
    result.textContent = data.duplicate
      ? `“${data.card.word}” 已存在于 ${data.deck}`
      : `已加入 ${data.deck}：${data.card.word}`;
    if (!data.duplicate) {
      $("#word").value = "";
      $("#context").value = "";
    }
  } catch (error) {
    result.className = "error";
    result.textContent = error.message;
  } finally {
    button.disabled = false;
  }
}

document.addEventListener("DOMContentLoaded", async () => {
  $("#word").focus();
  checkHealth();
  loadDecks();
});
$("#add").addEventListener("click", addWord);
$("#deck").addEventListener("change", () => {
  saveDeck().catch((error) => {
    const result = $("#result");
    result.className = "error";
    result.textContent = error.message;
  });
});
$("#word").addEventListener("keydown", (event) => {
  if (event.key === "Enter") {
    event.preventDefault();
    addWord();
  } else if (event.key === "ArrowDown") {
    event.preventDefault();
    $("#context").focus();
  }
});
$("#context").addEventListener("keydown", (event) => {
  if (event.key === "Enter" && (event.metaKey || event.ctrlKey)) {
    event.preventDefault();
    addWord();
  }
});
document.addEventListener("keydown", (event) => {
  if (event.key.toLowerCase() === "d" && (event.metaKey || event.ctrlKey)) {
    event.preventDefault();
    $("#deck").focus();
    return;
  }
  if (event.key === "Escape") window.close();
});
