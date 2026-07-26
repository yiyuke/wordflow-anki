function cleanText(value) {
  return (value || "").replace(/\s+/g, " ").trim();
}

function selectionContext() {
  const selection = window.getSelection();
  if (!selection || selection.rangeCount === 0) {
    return { text: "", context: "" };
  }

  const text = cleanText(selection.toString());
  const range = selection.getRangeAt(0);
  const node = range.commonAncestorContainer;
  const element = node.nodeType === Node.ELEMENT_NODE ? node : node.parentElement;
  const container = element?.closest("p, li, blockquote, td, th, figcaption") || element;
  let context = cleanText(container?.innerText || container?.textContent || "");

  if (context.length > 600) {
    const index = context.toLocaleLowerCase().indexOf(text.toLocaleLowerCase());
    if (index >= 0) {
      const start = Math.max(0, index - 240);
      context = context.slice(start, index + text.length + 240);
    } else {
      context = context.slice(0, 600);
    }
  }

  return { text, context };
}

function showToast(message, kind = "success") {
  document.getElementById("wordflow-anki-toast")?.remove();
  const toast = document.createElement("div");
  toast.id = "wordflow-anki-toast";
  toast.textContent = message;
  Object.assign(toast.style, {
    position: "fixed",
    zIndex: "2147483647",
    right: "20px",
    bottom: "20px",
    maxWidth: "360px",
    overflow: "hidden",
    textOverflow: "ellipsis",
    whiteSpace: "nowrap",
    padding: "12px 16px",
    borderRadius: "10px",
    color: "white",
    background: kind === "error" ? "#b42318" : kind === "duplicate" ? "#475467" : "#067647",
    boxShadow: "0 8px 30px rgba(0,0,0,.24)",
    font: "600 14px/1.4 system-ui, sans-serif"
  });
  document.documentElement.appendChild(toast);
  setTimeout(() => toast.remove(), 4200);
}

chrome.runtime.onMessage.addListener((message, _sender, sendResponse) => {
  if (message.type === "GET_SELECTION_CONTEXT") {
    sendResponse(selectionContext());
    return;
  }
  if (message.type === "SHOW_CAPTURE_RESULT") {
    showToast(message.message, message.kind);
  }
});
