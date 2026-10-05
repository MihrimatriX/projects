const state = { filter: "all", tag: null, q: "", currentId: null };

function api(type, payload = {}) {
  return chrome.runtime.sendMessage({ type, ...payload });
}

function esc(s) {
  const d = document.createElement("div");
  d.textContent = s;
  return d.innerHTML;
}

function formatDate(iso) {
  const d = new Date(iso);
  const diff = Math.floor((Date.now() - d) / 86400000);
  if (diff === 0) return "bugün";
  if (diff === 1) return "dün";
  if (diff < 7) return `${diff} gün önce`;
  return d.toLocaleDateString("tr-TR", { day: "numeric", month: "short" });
}

async function loadList() {
  const { clips = [] } = await api("LIST_CLIPS", { opts: { filter: state.filter, tag: state.tag, q: state.q } });
  const { tags = [] } = await api("GET_TAGS");

  const tagsEl = document.getElementById("tags");
  tagsEl.innerHTML = tags
    .map(
      (t) =>
        `<button type="button" class="tag-chip ${state.tag === t.name ? "active" : ""}" data-tag="${esc(t.name)}">${esc(t.name)} (${t.count})</button>`
    )
    .join("");
  tagsEl.querySelectorAll(".tag-chip").forEach((btn) => {
    btn.onclick = () => {
      state.tag = state.tag === btn.dataset.tag ? null : btn.dataset.tag;
      loadList();
    };
  });

  const list = document.getElementById("clips");
  if (!clips.length) {
    list.innerHTML = `<p class="empty">Henüz kayıt yok.<br/>Popup ile sayfa kaydedin.</p>`;
    return;
  }

  list.innerHTML = clips
    .map(
      (c) => `
    <article class="clip-card ${c.isRead ? "" : "unread"}" data-id="${c.id}">
      <div class="clip-domain">${esc(c.domain || "web")}</div>
      <div class="clip-title">${esc(c.title)}</div>
      <p class="clip-excerpt">${esc(c.excerpt || "Özet yok")}</p>
      <div class="clip-meta">
        <span>${formatDate(c.createdAt)}</span>
        ${c.isStarred ? "<span>★</span>" : ""}
        ${c.tags.slice(0, 2).map((t) => `<span>#${esc(t)}</span>`).join("")}
      </div>
    </article>`
    )
    .join("");

  list.querySelectorAll(".clip-card").forEach((card) => {
    card.onclick = () => openReader(card.dataset.id);
  });
}

async function openReader(id) {
  const { clip } = await api("GET_CLIP", { id });
  if (!clip) return;

  state.currentId = id;
  document.getElementById("list-view").classList.add("hidden");
  document.getElementById("reader-view").classList.remove("hidden");

  document.getElementById("r-domain").textContent = clip.domain || "web";
  document.getElementById("r-title").textContent = clip.title;
  document.getElementById("r-meta").textContent = formatDate(clip.createdAt);
  document.getElementById("open-original").href = clip.url;

  const content = document.getElementById("r-content");
  if (clip.content) {
    content.innerHTML = clip.content;
  } else if (clip.excerpt) {
    content.innerHTML = `<p>${esc(clip.excerpt)}</p><p><a href="${esc(clip.url)}" target="_blank" rel="noopener">Tam makaleyi kaynakta açın</a></p>`;
  } else {
    content.innerHTML = `<p><a href="${esc(clip.url)}" target="_blank" rel="noopener">Makaleyi kaynakta açın</a></p>`;
  }

  document.getElementById("star-btn").textContent = clip.isStarred ? "★" : "☆";
  document.getElementById("read-btn").textContent = clip.isRead ? "↩" : "✓";

  const hl = clip.highlights || [];
  const hlBox = document.getElementById("r-highlights");
  const hlList = document.getElementById("r-highlight-list");
  if (hl.length) {
    hlBox.classList.remove("hidden");
    hlList.innerHTML = hl.map((h) => `<div class="highlight-item">${esc(h.text)}</div>`).join("");
  } else {
    hlBox.classList.add("hidden");
  }

  if (!clip.isRead) {
    await api("PATCH_CLIP", { id, patch: { isRead: true } });
  }
}

function closeReader() {
  document.getElementById("reader-view").classList.add("hidden");
  document.getElementById("list-view").classList.remove("hidden");
  state.currentId = null;
  loadList();
}

document.getElementById("back-btn").onclick = closeReader;

document.getElementById("search").oninput = (e) => {
  state.q = e.target.value.trim();
  loadList();
};

document.querySelectorAll(".filter-btn").forEach((btn) => {
  btn.onclick = () => {
    state.filter = btn.dataset.filter;
    state.tag = null;
    document.querySelectorAll(".filter-btn").forEach((b) => b.classList.toggle("active", b === btn));
    loadList();
  };
});

document.getElementById("star-btn").onclick = async () => {
  if (!state.currentId) return;
  const { clip } = await api("GET_CLIP", { id: state.currentId });
  await api("PATCH_CLIP", { id: state.currentId, patch: { isStarred: !clip.isStarred } });
  openReader(state.currentId);
};

document.getElementById("read-btn").onclick = async () => {
  if (!state.currentId) return;
  const { clip } = await api("GET_CLIP", { id: state.currentId });
  await api("PATCH_CLIP", { id: state.currentId, patch: { isRead: !clip.isRead } });
  openReader(state.currentId);
};

document.getElementById("delete-btn").onclick = async () => {
  if (!state.currentId || !confirm("Bu kaydı silmek istiyor musunuz?")) return;
  await api("DELETE_CLIP", { id: state.currentId });
  closeReader();
};

chrome.storage.onChanged.addListener((changes, area) => {
  if (area === "local" && changes.clips_v1) loadList();
});

loadList();
