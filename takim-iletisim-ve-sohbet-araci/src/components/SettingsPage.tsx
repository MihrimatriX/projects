"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useCallback, useEffect, useRef, useState } from "react";
import { IconBack } from "@/components/icons";
import type { ChannelSummary, WebhookItem } from "@/types";

const THEME_KEY = "sohbet-tema";

function readTheme(): "dark" | "light" {
  try {
    return localStorage.getItem(THEME_KEY) === "light" ? "light" : "dark";
  } catch {
    return "dark";
  }
}

const inputStyle = {
  background: "var(--bg-input)",
  border: "none",
  borderRadius: "var(--radius-md)",
  padding: "10px 14px",
  width: "100%",
  color: "var(--text-primary)",
} as const;

export function SettingsPage() {
  const router = useRouter();
  const [name, setName] = useState("");
  const [savedName, setSavedName] = useState("");
  const [email, setEmail] = useState("");
  const [serverUrl, setServerUrl] = useState("");
  const [theme, setTheme] = useState<"dark" | "light">("dark");
  const [channels, setChannels] = useState<ChannelSummary[]>([]);
  const [webhooks, setWebhooks] = useState<WebhookItem[]>([]);
  const [whName, setWhName] = useState("");
  const [whChannel, setWhChannel] = useState("");
  const [deleteConfirm, setDeleteConfirm] = useState("");
  const [toast, setToast] = useState("");

  // Yeni bildirim öncekinin zamanlayıcısını iptal eder; aksi halde art arda gelenler erken kaybolurdu
  const toastTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  const showToast = useCallback((msg: string) => {
    setToast(msg);
    if (toastTimer.current) clearTimeout(toastTimer.current);
    toastTimer.current = setTimeout(() => setToast(""), 2800);
  }, []);

  useEffect(() => {
    setTheme(readTheme());
    async function load() {
      const me = await fetch("/api/auth/me");
      const meData = await me.json();
      if (!meData.user) {
        router.push("/login");
        return;
      }
      setName(meData.user.name);
      setSavedName(meData.user.name);
      setEmail(meData.user.email);
      setServerUrl(window.location.origin);

      const ch = await fetch("/api/channels");
      const chData = await ch.json();
      setChannels(chData.channels ?? []);

      const wh = await fetch("/api/settings/webhooks");
      const whData = await wh.json();
      setWebhooks(whData.webhooks ?? []);
    }
    load();
  }, [router]);

  function changeTheme(next: "dark" | "light") {
    setTheme(next);
    document.documentElement.dataset.theme = next;
    try {
      localStorage.setItem(THEME_KEY, next);
    } catch {
      // depolama kapalıysa tema yalnızca bu oturumda geçerli
    }
  }

  async function saveName(e: React.FormEvent) {
    e.preventDefault();
    const res = await fetch("/api/auth/me", {
      method: "PATCH",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ name }),
    });
    const data = await res.json().catch(() => ({}));
    if (!res.ok) return showToast(data.error ?? "Ad kaydedilemedi");
    setName(data.user.name);
    setSavedName(data.user.name);
    showToast("Görünen ad kaydedildi");
  }

  async function createWebhook(e: React.FormEvent) {
    e.preventDefault();
    const res = await fetch("/api/settings/webhooks", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ name: whName, channelId: whChannel }),
    });
    const data = await res.json().catch(() => ({}));
    if (!res.ok) return showToast(data.error ?? "Webhook oluşturulamadı");
    setWhName("");
    setWebhooks((prev) => [data.webhook, ...prev]);
    showToast("Webhook oluşturuldu");
  }

  async function testWebhook(url: string) {
    const res = await fetch(url, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ text: "Test mesajı — CI webhook" }),
    }).catch(() => null);
    showToast(res?.ok ? "Test mesajı kanala gönderildi" : "Test mesajı gönderilemedi");
  }

  async function deleteWebhook(id: string) {
    if (!confirm("Webhook silinsin mi? Bu URL'yi kullanan entegrasyonlar çalışmaz.")) return;
    const res = await fetch(`/api/settings/webhooks?id=${encodeURIComponent(id)}`, { method: "DELETE" });
    if (!res.ok) return showToast("Webhook silinemedi (yalnızca oluşturan silebilir)");
    setWebhooks((prev) => prev.filter((w) => w.id !== id));
    showToast("Webhook silindi");
  }

  async function copy(text: string) {
    try {
      await navigator.clipboard.writeText(text);
      showToast("Webhook URL kopyalandı");
    } catch {
      showToast("Panoya kopyalanamadı");
    }
  }

  async function logout() {
    await fetch("/api/auth/logout", { method: "POST" });
    router.push("/login");
  }

  async function deleteAccount() {
    if (deleteConfirm.trim().toLowerCase() !== email) {
      return showToast("Onay için e-posta adresinizi aynen yazın");
    }
    if (!confirm("Hesabınız kalıcı olarak silinecek. Emin misiniz?")) return;
    const res = await fetch("/api/user/delete", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ confirm: deleteConfirm.trim().toLowerCase() }),
    });
    if (res.ok) router.push("/login");
    else {
      const data = await res.json().catch(() => ({}));
      showToast(data.error ?? "Silme başarısız");
    }
  }

  const sectionTitle = "text-[13px] font-semibold uppercase tracking-widest mb-3";
  const publicChannels = channels.filter((c) => c.type === "PUBLIC");

  return (
    <div className="settings-layout" style={{ background: "var(--bg-main)" }}>
      <Link href="/chat" className="settings-back">
        <IconBack />
        Sohbete dön
      </Link>
      <h1 className="text-[28px] font-bold tracking-tight mb-2">Ayarlar</h1>
      <p className="text-[15px] mb-8 max-w-prose leading-relaxed" style={{ color: "var(--text-muted)" }}>
        Self-host sunucu yapılandırması, profil ve KVKK uyumlu veri yönetimi. Telemetri yok; tüm veriler kendi sunucunuzda.
      </p>

      <section className="mb-8" aria-labelledby="profil-baslik">
        <h2 id="profil-baslik" className={sectionTitle} style={{ color: "var(--text-muted)" }}>
          Profil ve görünüm
        </h2>
        <div className="settings-card">
          <form className="settings-field" onSubmit={saveName}>
            <label htmlFor="displayName">Görünen ad</label>
            <div className="flex gap-2 items-center">
              <input
                id="displayName"
                type="text"
                value={name}
                minLength={2}
                maxLength={40}
                required
                onChange={(e) => setName(e.target.value)}
              />
              <button type="submit" className="btn btn-primary shrink-0" disabled={name.trim() === savedName}>
                Kaydet
              </button>
            </div>
            <p className="text-[13px] mt-2" style={{ color: "var(--text-muted)" }}>
              Oturum: {email}
            </p>
          </form>
          <div className="settings-field">
            <label htmlFor="theme">Tema</label>
            <select
              id="theme"
              value={theme}
              onChange={(e) => changeTheme(e.target.value === "light" ? "light" : "dark")}
              style={inputStyle}
            >
              <option value="dark">Koyu</option>
              <option value="light">Açık</option>
            </select>
          </div>
          <div className="settings-field">
            <label htmlFor="serverUrl">Sunucu URL</label>
            <input id="serverUrl" type="url" value={serverUrl} readOnly />
            <p className="text-[13px] mt-2 leading-snug" style={{ color: "var(--text-muted)" }}>
              Next.js + Socket.IO sunucusu. Docker Compose ile prod ortamına alınabilir.
            </p>
          </div>
        </div>
      </section>

      <section className="mb-8" aria-labelledby="webhook-baslik">
        <h2 id="webhook-baslik" className={sectionTitle} style={{ color: "var(--text-muted)" }}>
          Webhook / CI
        </h2>
        <div className="settings-card">
          {webhooks.length === 0 && (
            <div className="settings-field">
              <p className="text-[13px]" style={{ color: "var(--text-muted)" }}>
                Henüz webhook yok. CI/CD bildirimleri için bir kanal seçip oluşturun; URL&apos;ye
                <code> {"{\"text\": \"...\"}"} </code> gövdesiyle POST atılır.
              </p>
            </div>
          )}
          {webhooks.map((w) => (
            <div key={w.id} className="settings-field" aria-label={`${w.name} webhook`} role="group">
              <label htmlFor={`wh-${w.id}`}>
                {w.name} → #{w.channelName}
              </label>
              <div className="flex gap-2 items-center flex-wrap">
                <input id={`wh-${w.id}`} type="text" readOnly value={w.url} className="font-mono text-[13px] flex-1" />
                <button type="button" className="btn btn-ghost shrink-0" onClick={() => copy(w.url)}>
                  Kopyala
                </button>
                <button type="button" className="btn btn-ghost shrink-0" onClick={() => testWebhook(w.url)}>
                  Test
                </button>
                <button type="button" className="btn btn-danger shrink-0" onClick={() => deleteWebhook(w.id)}>
                  Sil
                </button>
              </div>
            </div>
          ))}
          <form onSubmit={createWebhook} className="settings-field space-y-3">
            <label htmlFor="whName">Yeni webhook</label>
            <input
              id="whName"
              style={inputStyle}
              placeholder="Webhook adı (ör. GitHub CI)"
              value={whName}
              onChange={(e) => setWhName(e.target.value)}
              required
            />
            <select
              aria-label="Webhook kanalı"
              style={inputStyle}
              value={whChannel}
              onChange={(e) => setWhChannel(e.target.value)}
              required
            >
              <option value="">Kanal seçin</option>
              {publicChannels.map((c) => (
                <option key={c.id} value={c.id}>
                  #{c.name}
                </option>
              ))}
            </select>
            <button type="submit" className="btn btn-primary">
              Webhook oluştur
            </button>
          </form>
        </div>
      </section>

      <section className="mb-8" aria-labelledby="kvkk-baslik">
        <h2 id="kvkk-baslik" className={sectionTitle} style={{ color: "var(--text-muted)" }}>
          KVKK — Veri yönetimi
        </h2>
        <div className="settings-card">
          <div className="settings-field">
            <label>Veri dışa aktarma</label>
            <p className="text-[13px] leading-snug" style={{ color: "var(--text-muted)" }}>
              Tüm mesajlarınız, DM&apos;leriniz ve profil bilgileriniz JSON arşivi olarak indirilir.
            </p>
            <div className="flex gap-2.5 flex-wrap mt-3">
              <a className="btn btn-primary" href="/api/user/export" download>
                Verilerimi dışa aktar
              </a>
            </div>
          </div>
          <div className="settings-field">
            <label htmlFor="deleteConfirm">Hesap silme</label>
            <p className="text-[13px] leading-snug mb-3" style={{ color: "var(--text-muted)" }}>
              Kalıcı silme geri alınamaz. Onay için e-posta adresinizi yazın: {email}
            </p>
            <input
              id="deleteConfirm"
              placeholder={email}
              value={deleteConfirm}
              autoComplete="off"
              onChange={(e) => setDeleteConfirm(e.target.value)}
              className="mb-3"
              style={inputStyle}
            />
            <button
              type="button"
              className="btn btn-danger"
              onClick={deleteAccount}
              disabled={deleteConfirm.trim().toLowerCase() !== email}
            >
              Hesabımı sil
            </button>
          </div>
        </div>
      </section>

      <div className="flex justify-end">
        <button type="button" className="btn btn-ghost" onClick={logout}>
          Çıkış yap
        </button>
      </div>

      <div className={`toast ${toast ? "visible" : ""}`} role="status">
        {toast}
      </div>
    </div>
  );
}
