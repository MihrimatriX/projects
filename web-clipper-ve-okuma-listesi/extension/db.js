// Tüm kayıtlar chrome.storage.local'da tek bir dizi olarak tutulur (unlimitedStorage izniyle 10 MB sınırı yok)
const CLIPS_KEY = "clips_v1";

async function loadClips() {
  const { [CLIPS_KEY]: clips = [] } = await chrome.storage.local.get(CLIPS_KEY);
  return clips;
}

async function saveClips(clips) {
  await chrome.storage.local.set({ [CLIPS_KEY]: clips });
}

function newId() {
  return crypto.randomUUID();
}

function domainFromUrl(url) {
  try {
    return new URL(url).hostname.replace(/^www\./, "");
  } catch {
    return null;
  }
}

async function addClip(payload) {
  const clips = await loadClips();
  const existing = clips.find((c) => c.url === payload.url);
  if (existing) {
    if (payload.tags?.length) {
      existing.tags = [...new Set([...existing.tags, ...payload.tags.map((t) => t.toLowerCase())])];
    }
    if (payload.excerpt && !existing.excerpt) existing.excerpt = payload.excerpt;
    if (payload.content && !existing.content) existing.content = payload.content;
    if (payload.highlight) {
      existing.highlights = existing.highlights || [];
      existing.highlights.push({
        id: newId(),
        text: payload.highlight.slice(0, 5000),
        note: null,
        createdAt: new Date().toISOString(),
      });
    }
    await saveClips(clips);
    return { clip: existing, duplicate: true };
  }

  const clip = {
    id: newId(),
    url: payload.url,
    title: payload.title || domainFromUrl(payload.url) || payload.url,
    excerpt: payload.excerpt || null,
    content: payload.content || null,
    domain: domainFromUrl(payload.url),
    isRead: false,
    isStarred: false,
    tags: (payload.tags || []).map((t) => t.toLowerCase()),
    highlights: payload.highlight
      ? [{ id: newId(), text: payload.highlight.slice(0, 5000), note: null, createdAt: new Date().toISOString() }]
      : [],
    createdAt: new Date().toISOString(),
    parseStatus: "done",
  };
  clips.unshift(clip);
  await saveClips(clips);
  return { clip, duplicate: false };
}

async function listClips(opts = {}) {
  const { filter = "all", tag = null, q = "" } = opts;
  let clips = await loadClips();
  if (filter === "unread") clips = clips.filter((c) => !c.isRead);
  if (filter === "starred") clips = clips.filter((c) => c.isStarred);
  if (tag) clips = clips.filter((c) => c.tags.includes(tag));
  if (q) {
    const lower = q.toLowerCase();
    clips = clips.filter(
      (c) => c.title.toLowerCase().includes(lower) || (c.domain || "").toLowerCase().includes(lower)
    );
  }
  return clips;
}

async function getStats() {
  const clips = await loadClips();
  return {
    all: clips.length,
    unread: clips.filter((c) => !c.isRead).length,
    starred: clips.filter((c) => c.isStarred).length,
  };
}

async function getClip(id) {
  return (await loadClips()).find((c) => c.id === id) || null;
}

async function patchClip(id, patch) {
  const clips = await loadClips();
  const i = clips.findIndex((c) => c.id === id);
  if (i < 0) return null;
  clips[i] = { ...clips[i], ...patch };
  await saveClips(clips);
  return clips[i];
}

async function deleteClip(id) {
  await saveClips((await loadClips()).filter((c) => c.id !== id));
}

async function getTags() {
  const map = new Map();
  for (const c of await loadClips()) {
    for (const t of c.tags) map.set(t, (map.get(t) || 0) + 1);
  }
  return [...map.entries()].map(([name, count]) => ({ name, count }));
}

async function deleteAllClips() {
  await saveClips([]);
}

async function importClips(data) {
  if (Array.isArray(data) && data[0]?.url && data[0]?.title) {
    const clips = await loadClips();
    const urls = new Set(clips.map((c) => c.url));
    let imported = 0;
    for (const item of data) {
      if (!item.url || urls.has(item.url)) continue;
      clips.unshift({
        id: newId(),
        url: item.url,
        title: item.title,
        excerpt: item.excerpt || null,
        content: item.content || null,
        domain: item.domain || domainFromUrl(item.url),
        isRead: Boolean(item.isRead),
        isStarred: Boolean(item.isStarred),
        tags: item.tags || [],
        highlights: item.highlights || [],
        createdAt: item.createdAt || new Date().toISOString(),
        parseStatus: "done",
      });
      urls.add(item.url);
      imported++;
    }
    await saveClips(clips);
    return imported;
  }

  const incoming = Array.isArray(data) ? data : data?.items || data?.links || [];
  let imported = 0;
  for (const item of incoming) {
    const url = item.url || item.link;
    if (!url) continue;
    const r = await addClip({
      url,
      title: item.title || item.name,
      excerpt: item.excerpt || item.description,
      tags: item.tags || [],
    });
    if (!r.duplicate) imported++;
  }
  return imported;
}
