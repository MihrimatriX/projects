const DEFAULT_TAGS = ["geliştirme", "tasarım", "ai", "okuma"];

function renderQuickTags(tags) {
  const el = document.getElementById("quick-tags");
  el.innerHTML = tags
    .map(
      (t) =>
        `<button type="button" class="quick-tag" data-tag="${escapeHtml(t)}">${escapeHtml(t)}</button>`
    )
    .join("");

  el.querySelectorAll(".quick-tag").forEach((btn) => {
    btn.addEventListener("click", () => {
      const tag = btn.dataset.tag;
      const input = document.getElementById("tag-input");
      const current = input.value
        .split(",")
        .map((s) => s.trim())
        .filter(Boolean);
      input.value = current.includes(tag)
        ? current.filter((x) => x !== tag).join(", ")
        : [...current, tag].join(", ");
    });
  });
}

function escapeHtml(s) {
  return String(s)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}

async function getPageSelection(tabId) {
  if (!tabId) return "";
  try {
    const [{ result }] = await chrome.scripting.executeScript({
      target: { tabId },
      func: () => window.getSelection()?.toString().trim() ?? "",
    });
    return result ?? "";
  } catch {
    return "";
  }
}

document.addEventListener("DOMContentLoaded", async () => {
  const titleEl = document.getElementById("page-title");
  const metaEl = document.getElementById("page-meta");
  const statusEl = document.getElementById("status");
  const saveBtn = document.getElementById("save-btn");
  const listBtn = document.getElementById("list-btn");
  const tagInput = document.getElementById("tag-input");

  const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
  const pageTitle = tab?.title ?? "Başlıksız sayfa";
  const pageUrl = tab?.url ?? "";

  titleEl.textContent = pageTitle;
  try {
    metaEl.textContent = new URL(pageUrl).hostname.replace(/^www\./, "");
  } catch {
    metaEl.textContent = pageUrl.slice(0, 40);
  }

  const { recentTags = [] } = await chrome.storage.sync.get(["recentTags"]);
  renderQuickTags([...new Set([...DEFAULT_TAGS, ...recentTags])].slice(0, 8));

  listBtn.addEventListener("click", async () => {
    // sidePanel.open kullanıcı hareketi ister; mesajla service worker'a aktarılınca bu bağlam kaybolur
    await chrome.sidePanel.open({ windowId: tab.windowId });
  });

  saveBtn.addEventListener("click", async () => {
    if (!pageUrl.startsWith("http")) {
      statusEl.textContent = "Bu sayfa kaydedilemez.";
      statusEl.className = "status err";
      return;
    }

    saveBtn.disabled = true;
    statusEl.textContent = "Kaydediliyor…";
    statusEl.className = "status";

    const tags = tagInput.value
      .split(",")
      .map((t) => t.trim().toLowerCase())
      .filter(Boolean);

    const highlight = await getPageSelection(tab?.id);
    const result = await chrome.runtime.sendMessage({
      type: "SAVE_CLIP",
      tabId: tab?.id,
      payload: { url: pageUrl, title: pageTitle, tags, highlight: highlight || undefined },
    });

    saveBtn.disabled = false;

    if (result?.clip) {
      statusEl.textContent = result.duplicate ? "Zaten kayıtlı ✓" : "Kaydedildi ✓";
      statusEl.className = "status ok";
      if (tags.length) {
        const merged = [...new Set([...tags, ...recentTags])].slice(0, 12);
        await chrome.storage.sync.set({ recentTags: merged });
      }
    } else {
      statusEl.textContent = result?.error ?? "Kayıt başarısız";
      statusEl.className = "status err";
    }
  });
});
