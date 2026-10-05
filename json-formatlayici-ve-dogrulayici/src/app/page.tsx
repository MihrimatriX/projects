"use client";

import Link from "next/link";
import { useBodyClass } from "@/hooks/useBodyClass";

const SCREENS = [
  {
    href: "/lab",
    tag: "Ana ekran",
    title: "Ana Laboratuvar",
    desc: "Split editör, syntax highlight, ağaç senkronu, format/minify/sort, hata paneli.",
  },
  {
    href: "/jsonpath",
    tag: "Sorgu",
    title: "JSONPath / jq-lite",
    desc: "$.store.book[*].title sorgusu; eval yok, güvenli istemci tarafı filtreleme.",
  },
  {
    href: "/schema",
    tag: "Doğrulama",
    title: "Şema Doğrulama",
    desc: "Draft-07 şema textarea; alan bazlı hata listesi.",
  },
  {
    href: "/diff",
    tag: "Karşılaştır",
    title: "Diff Görünümü",
    desc: "İki JSON yan yana; ekleme/silme satır vurgusu.",
  },
  {
    href: "/file",
    tag: "Tauri",
    title: "Dosya Entegrasyonu",
    desc: "Aç / izle / kaydet; son dosyalar ve değişiklik badge'i.",
  },
];

export default function LauncherPage() {
  useBodyClass("launcher-page");

  return (
    <>
      <a href="#screens" className="sr-only">
        Ekran listesine atla
      </a>
      <div className="launcher">
        <div className="launcher-inner">
          <h1>JSON Formatlayıcı</h1>
          <p className="launcher-version">
            <span className="dot" aria-hidden />
            v1.4.0 · CodeMirror 6 · Electron / Tauri
          </p>
          <p className="launcher-lead">
            VS Code tarzı split editör + ağaç görünümü. Veri istemcide kalır; tree, JSONPath, şema
            doğrulama ve diff ayrı ekranlarda.
          </p>
          <main id="screens">
            <div className="screen-grid">
              {SCREENS.map((s) => (
                <Link key={s.href} href={s.href} className="screen-card">
                  <span className="tag">{s.tag}</span>
                  <h2>{s.title}</h2>
                  <p>{s.desc}</p>
                </Link>
              ))}
            </div>
          </main>
          <p className="launcher-footer">
            Tüm parse ve doğrulama istemci tarafında çalışır. Paylaşım linkleri lz-string ile salt
            okunur mod açar.
          </p>
        </div>
      </div>
    </>
  );
}
