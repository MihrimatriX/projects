"use client";

import { useRef, useState } from "react";
import PageBack from "@/components/PageBack";

type Status = { type: "success" | "error"; msg: string } | null;

export default function SettingsPage() {
  const fileRef = useRef<HTMLInputElement>(null);
  const [status, setStatus] = useState<Status>(null);
  const [busy, setBusy] = useState(false);

  async function importBackup(file: File) {
    setBusy(true);
    setStatus(null);
    try {
      let data: unknown;
      try {
        data = JSON.parse(await file.text());
      } catch {
        throw new Error("Dosya geçerli bir JSON değil.");
      }
      const res = await fetch("/api/backup", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(data),
      });
      const result = await res.json();
      if (!res.ok) throw new Error(result.error ?? "İçe aktarma başarısız");
      setStatus({
        type: "success",
        msg: `${result.imported} kayıt içe aktarıldı, ${result.skipped} kayıt zaten vardı.`,
      });
    } catch (err) {
      setStatus({ type: "error", msg: err instanceof Error ? err.message : "İçe aktarma başarısız" });
    } finally {
      setBusy(false);
    }
  }

  async function deleteAll() {
    if (!confirm("Web arayüzündeki tüm kayıtlar, vurgular ve feed'ler silinecek. Emin misiniz?")) return;
    setBusy(true);
    const res = await fetch("/api/settings", { method: "DELETE" }).catch(() => null);
    setBusy(false);
    setStatus(res?.ok ? { type: "success", msg: "Tüm veriler silindi." } : { type: "error", msg: "Silinemedi." });
  }

  return (
    <main className="standalone-page">
      <PageBack />
      <h1 className="standalone-title">Ayarlar</h1>
      <p className="standalone-desc">
        Chrome eklentisi verileri tarayıcıda saklar; bu web / masaüstü arayüzü kendi veritabanını kullanır.
        İkisi arasında JSON yedeğiyle kayıt taşıyabilirsiniz.
      </p>

      <section className="card-section">
        <h2 className="section-title">Yedek</h2>
        <p className="section-desc">
          Yedek, eklentinin Ayarlar → &quot;JSON indir&quot; çıktısıyla aynı biçimdedir: eklenti yedeğini buraya,
          buradaki yedeği eklentiye yükleyebilirsiniz. Aynı adresli kayıtlar atlanır.
        </p>
        <div className="flex gap-3 flex-wrap">
          <a className="btn-primary" href="/api/backup" download>
            Yedeği indir (JSON)
          </a>
          <button type="button" className="btn-secondary" disabled={busy} onClick={() => fileRef.current?.click()}>
            Yedeği içe aktar
          </button>
          <input
            ref={fileRef}
            type="file"
            accept=".json,application/json"
            hidden
            aria-label="Yedek dosyası seç"
            onChange={(e) => {
              const file = e.target.files?.[0];
              e.target.value = "";
              if (file) void importBackup(file);
            }}
          />
        </div>
        {status && <p className={`import-result ${status.type}`}>{status.msg}</p>}
      </section>

      <section className="card-section">
        <h2 className="section-title">Chrome eklentisi</h2>
        <p className="section-desc">
          <code className="font-mono text-xs">extension/</code> klasörünü{" "}
          <code className="font-mono text-xs">chrome://extensions</code> → Geliştirici modu → &quot;Paketlenmemiş öğe
          yükle&quot; ile yükleyin. Popup ile kaydedin, yan panelden okuma listesine erişin.
        </p>
      </section>

      <section className="card-section danger">
        <h2 className="section-title">Tehlikeli bölge</h2>
        <p className="section-desc">Bu arayüzdeki tüm kayıtları kalıcı olarak siler (eklentideki veriler etkilenmez).</p>
        <button type="button" className="btn-danger" disabled={busy} onClick={() => void deleteAll()}>
          Tüm verileri sil
        </button>
      </section>
    </main>
  );
}
