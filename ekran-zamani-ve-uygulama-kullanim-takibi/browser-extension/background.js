const DEFAULT_PORT = 47123;
// MV3 service worker ~30 sn boşta kalınca kapanır; setInterval güvenilmez. Alarm worker'ı uyandırır.
const FLUSH_ALARM = "ez-flush";
const FLUSH_MINUTES = 0.5;
// Tek gönderimde en fazla bu kadar saniye: daha uzun aralık = bilgisayar uyudu / tarayıcı askıdaydı.
const MAX_CHUNK_SEC = 120;
const IDLE_DETECT_SEC = 300;

// Oturum chrome.storage.session'da tutulur; worker yeniden başlasa da kaybolmaz.
async function getSession() {
  const { session } = await chrome.storage.session.get("session");
  return session || null; // { domain, title, start }
}

async function setSession(session) {
  if (session) await chrome.storage.session.set({ session });
  else await chrome.storage.session.remove("session");
}

async function getPort() {
  const { bridgePort } = await chrome.storage.local.get("bridgePort");
  return bridgePort || DEFAULT_PORT;
}

function domainFromUrl(url) {
  try {
    const u = new URL(url);
    if (u.protocol !== "http:" && u.protocol !== "https:") return "";
    return u.hostname.replace(/^www\./, "");
  } catch {
    return "";
  }
}

async function sendUsage(domain, title, seconds) {
  if (!domain || seconds <= 0) return;
  try {
    await fetch(`http://127.0.0.1:${await getPort()}/api/web-usage`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ domain, title, seconds: Math.min(seconds, MAX_CHUNK_SEC) })
    });
  } catch {
    // Ekran Zamanı uygulaması kapalı olabilir
  }
}

// Biriken süreyi gönderir. restart=true ise aynı sayfada yeni dilim başlatır.
async function flush(restart) {
  const s = await getSession();
  if (!s) return;
  const now = Date.now();
  const elapsed = Math.floor((now - s.start) / 1000);
  if (elapsed > 0) await sendUsage(s.domain, s.title, elapsed);
  await setSession(restart ? { ...s, start: now } : null);
}

async function startFromTab(tab) {
  await flush(false);
  const domain = tab ? domainFromUrl(tab.url || "") : "";
  if (!domain) return;
  await setSession({ domain, title: tab.title || "", start: Date.now() });
}

// Odaktaki pencerenin aktif sekmesinden yeniden başlat (odak dönüşü, boşta dönüşü, worker açılışı).
async function resumeFromFocusedWindow() {
  try {
    const win = await chrome.windows.getLastFocused({ populate: true });
    if (!win || !win.focused) return flush(false);
    const state = await chrome.idle.queryState(IDLE_DETECT_SEC);
    if (state !== "active") return flush(false);
    await startFromTab((win.tabs || []).find((t) => t.active));
  } catch {
    await flush(false);
  }
}

chrome.tabs.onActivated.addListener(async (info) => {
  try {
    await startFromTab(await chrome.tabs.get(info.tabId));
  } catch {
    await flush(false);
  }
});

chrome.tabs.onUpdated.addListener(async (tabId, changeInfo, tab) => {
  if (!tab.active || !changeInfo.url) return;
  const s = await getSession();
  // Süre site bazında toplanır: aynı sitede sayfa/başlık değişimi oturumu bölmesin.
  if (s && s.domain === domainFromUrl(tab.url || "")) return;
  const win = await chrome.windows.getLastFocused().catch(() => null);
  if (!win || !win.focused || win.id !== tab.windowId) return; // arka plandaki pencere
  await startFromTab(tab);
});

chrome.windows.onFocusChanged.addListener(async (windowId) => {
  if (windowId === chrome.windows.WINDOW_ID_NONE) await flush(false);
  else await resumeFromFocusedWindow();
});

chrome.idle.setDetectionInterval(IDLE_DETECT_SEC);
chrome.idle.onStateChanged.addListener(async (state) => {
  if (state === "active") await resumeFromFocusedWindow();
  else await flush(false); // boşta / kilitli: süre sayılmaz
});

chrome.alarms.onAlarm.addListener(async (alarm) => {
  if (alarm.name === FLUSH_ALARM) await flush(true);
});

async function init() {
  if (!(await chrome.alarms.get(FLUSH_ALARM))) {
    chrome.alarms.create(FLUSH_ALARM, { periodInMinutes: FLUSH_MINUTES });
  }
  if (!(await getSession())) await resumeFromFocusedWindow();
}

chrome.runtime.onStartup.addListener(init);
chrome.runtime.onInstalled.addListener(init);
init();
