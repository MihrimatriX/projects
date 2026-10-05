importScripts("db.js");

function sanitizeHtml(html) {
  if (!html) return "";
  return html
    .replace(/<script[\s\S]*?<\/script>/gi, "")
    .replace(/<style[\s\S]*?<\/style>/gi, "")
    .replace(/\son\w+="[^"]*"/gi, "")
    .replace(/\son\w+='[^']*'/gi, "");
}

// Sayfa içinde çalışan fonksiyon: article/main gövdesini ve özeti çıkarır (scripting izni + activeTab)
async function extractFromTab(tabId) {
  const [{ result }] = await chrome.scripting.executeScript({
    target: { tabId },
    func: () => {
      const desc =
        document.querySelector('meta[name="description"]')?.content ||
        document.querySelector('meta[property="og:description"]')?.content ||
        "";
      const root = document.querySelector("article, main, [role=main]") || document.body;
      const text = (root.innerText || "").replace(/\s+/g, " ").trim();
      const excerpt = (desc || text.slice(0, 280)).trim();
      const clone = root.cloneNode(true);
      clone.querySelectorAll("script,style,noscript,iframe,svg").forEach((el) => el.remove());
      const html = clone.innerHTML.trim();
      return { excerpt, content: html.length > 80 ? html.slice(0, 500000) : null };
    },
  });
  return result ?? {};
}

async function saveClipFromPayload(payload, tabId) {
  if (tabId && !payload.content) {
    try {
      const extracted = await extractFromTab(tabId);
      payload = { ...payload, ...extracted };
    } catch {
      /* ponytail: sayfa erişilemezse yalnızca metadata kaydet */
    }
  }
  if (payload.content) payload.content = sanitizeHtml(payload.content);
  return addClip(payload);
}

chrome.runtime.onMessage.addListener((message, sender, sendResponse) => {
  const tabId = sender.tab?.id;

  (async () => {
    switch (message.type) {
      case "SAVE_CLIP":
        return saveClipFromPayload(message.payload, message.tabId ?? tabId);
      case "LIST_CLIPS":
        return { clips: await listClips(message.opts) };
      case "GET_CLIP":
        return { clip: await getClip(message.id) };
      case "PATCH_CLIP":
        return { clip: await patchClip(message.id, message.patch) };
      case "DELETE_CLIP":
        await deleteClip(message.id);
        return { ok: true };
      case "GET_STATS":
        return getStats();
      case "GET_TAGS":
        return { tags: await getTags() };
      case "DELETE_ALL":
        await deleteAllClips();
        return { ok: true };
      case "EXPORT_CLIPS":
        return { clips: await loadClips() };
      case "IMPORT_CLIPS":
        return { imported: await importClips(message.data) };
      case "OPEN_LIST":
        if (message.windowId) await chrome.sidePanel.open({ windowId: message.windowId });
        return { ok: true };
      default:
        return { error: "Bilinmeyen işlem" };
    }
  })()
    .then(sendResponse)
    // Hata olursa da yanıt dön; aksi halde popup "Kaydediliyor…" durumunda takılı kalır
    .catch((err) => sendResponse({ error: err?.message || String(err) }));

  // true: yanıt async gönderilecek (MV3 service worker mesaj kanalı açık kalır)
  return true;
});

chrome.runtime.onInstalled.addListener(() => {
  if (chrome.sidePanel?.setPanelBehavior) {
    chrome.sidePanel.setPanelBehavior({ openPanelOnActionClick: false });
  }
});
