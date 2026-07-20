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
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        text: word,
        context: $("#context").value.trim(),
        source_title: "Arc 扩展手动输入",
        source_url: "",
        source_type: "browser-manual"
      })
    });
    const data = await response.json();
    if (!response.ok || !data.ok) throw new Error(data.error || `HTTP ${response.status}`);
    result.textContent = data.duplicate ? `“${data.card.word}” 已存在` : `已加入：${data.card.word}`;
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
});
$("#add").addEventListener("click", addWord);
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
  if (event.key === "Escape") window.close();
});
