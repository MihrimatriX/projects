import Link from "next/link";

const screens: {
  href: string;
  title: string;
  tags: { label: string; live?: boolean }[];
  desc: string;
  code: string;
  primary?: boolean;
}[] = [
  {
    href: "/lab",
    title: "Laboratuvar",
    tags: [{ label: "Canlı", live: true }, { label: "Web" }],
    desc: "Bayrak çubuğu, grup tablosu, replace önizleme, ReDoS uyarısı ve lz-string paylaşım. Geniş ekranda üç panel; dar ekranda sekmeli düzen.",
    code: "Ctrl+Enter eşleştir · F10 debugger · F1 yardım",
    primary: true,
  },
  {
    href: "/cheatsheet",
    title: "Cheatsheet",
    tags: [{ label: "Web" }],
    desc: "Aranabilir, kategorili referans kartları. Tıklayınca pattern örnek metinle laboratuvara yüklenir.",
    code: "e-posta, URL, tarih, lookahead örnekleri",
  },
];

const facts = [
  { term: "ReDoS", detail: "İç içe quantifier taraması; 2 sn timeout uyarısı" },
  { term: "Worker", detail: "5000+ karakterde arka plan eşleştirme" },
  { term: "Paylaşım", detail: "Sıkıştırılmış ?s= bağlantısı (yalnızca web)" },
];

export default function HomeScreen() {
  return (
    <div className="grid-bg min-h-dvh relative">
      <a
        href="#screens"
        className="sr-only focus:not-sr-only focus:absolute focus:left-0 focus:top-0 focus:z-50 focus:bg-[var(--accent)] focus:px-4 focus:py-2 focus:font-semibold focus:text-[var(--bg-app)]"
      >
        Ekranlara atla
      </a>

      <header className="sticky top-0 z-10 flex h-[var(--header-height)] items-center justify-between gap-4 border-b border-[var(--border)] bg-[color-mix(in_srgb,var(--bg-toolbar)_92%,transparent)] px-5 backdrop-blur-md">
        <div className="flex min-w-0 items-center gap-2.5">
          <span
            className="grid h-7 w-7 shrink-0 place-items-center rounded-[var(--radius-btn)] border border-[var(--border)] bg-[var(--bg-editor)] font-mono text-[13px] font-medium text-[var(--syntax-group)]"
            aria-hidden
          >
            /.*/
          </span>
          <span className="truncate text-sm font-semibold tracking-tight">Regex Test ve Öğrenme</span>
        </div>
        <span className="hidden font-mono text-[11px] text-[var(--text-muted)] sm:inline">v1.2 · istemci tarafı</span>
      </header>

      <main className="relative mx-auto max-w-[1080px] px-5 pb-14 pt-8">
        <section className="mb-10 grid items-end gap-7 md:grid-cols-[1.15fr_0.85fr]">
          <div>
            <h1 className="mb-3 max-w-[14ch] text-[clamp(28px,4.2vw,40px)] font-semibold leading-[1.12] tracking-tight">
              Pattern yaz, anında test et
            </h1>
            <p className="max-w-[48ch] text-base leading-relaxed text-[var(--text-secondary)]">
              Üç bölgeli koyu laboratuvar: regex editörü, vurgulu test metni, yakalama grupları. Veri
              tarayıcıda kalır; sunucuya gönderilmez.
            </p>
          </div>
          <aside className="flex flex-col gap-3.5 rounded-[var(--radius-panel)] border border-[var(--border)] bg-[var(--bg-editor)] p-5">
            <span className="text-xs font-semibold tracking-wide text-[var(--text-secondary)]">
              Örnek: e-posta pattern
            </span>
            <pre
              className="overflow-x-auto whitespace-pre rounded-[var(--radius-btn)] border border-[var(--border)] bg-[var(--bg-surface)] p-3 font-mono text-xs leading-relaxed"
              aria-hidden
            >
              <span className="text-[var(--text-muted)]">/</span>
              <span className="text-[var(--syntax-group)]">^</span>
              <span className="text-[var(--syntax-quant)]">[a-z0-9._%+-]+</span>
              <span className="text-[var(--syntax-group)]">@</span>
              <span className="text-[var(--syntax-quant)]">[a-z0-9.-]+</span>
              <span className="text-[var(--syntax-group)]">\.</span>
              <span className="text-[var(--syntax-quant)]">[a-z]{"{2,}"}</span>
              <span className="text-[var(--syntax-group)]">$</span>
              <span className="text-[var(--text-muted)]">/gi</span>
              {"\n"}
              <span className="rounded-sm bg-[var(--match-0)]">destek@ornek.com</span>{"  "}
              <span className="rounded-sm bg-[var(--match-1)]">user.name+tag@site.co</span>
            </pre>
            <Link
              href="/lab"
              className="inline-flex min-h-10 w-fit items-center justify-center gap-2 self-start rounded-[var(--radius-btn)] border border-[color-mix(in_srgb,var(--accent)_55%,var(--border))] bg-[color-mix(in_srgb,var(--accent)_18%,var(--bg-editor))] px-4 text-[13px] font-semibold tracking-wide text-[var(--text-primary)] transition hover:border-[var(--accent)] hover:bg-[color-mix(in_srgb,var(--accent)_28%,var(--bg-editor))] active:scale-[0.98]"
            >
              Laboratuvara git
            </Link>
          </aside>
        </section>

        <section id="screens" aria-labelledby="screens-heading">
          <h2 id="screens-heading" className="mb-3 text-xs font-semibold tracking-wide text-[var(--text-secondary)]">
            Uygulama ekranları
          </h2>
          <div className="overflow-hidden rounded-[var(--radius-panel)] border border-[var(--border)] bg-[var(--border)]">
            {screens.map((screen) => (
              <Link
                key={screen.href}
                href={screen.href}
                className={`grid items-center gap-4 px-5 py-4 transition md:grid-cols-[1fr_auto] ${
                  screen.primary
                    ? "bg-[color-mix(in_srgb,var(--accent)_6%,var(--bg-editor))] hover:bg-[color-mix(in_srgb,var(--accent)_10%,var(--bg-editor))]"
                    : "bg-[var(--bg-editor)] hover:bg-[var(--bg-surface)]"
                }`}
              >
                <div className="min-w-0">
                  <div className="mb-1.5 flex flex-wrap items-baseline gap-2.5">
                    <span className="text-base font-semibold tracking-tight">{screen.title}</span>
                    {screen.tags.map((tag) => (
                      <span
                        key={tag.label}
                        className={`rounded border px-1.5 py-0.5 font-mono text-[10px] font-medium uppercase tracking-widest ${
                          tag.live
                            ? "border-[color-mix(in_srgb,var(--success)_35%,var(--border))] text-[var(--success)]"
                            : "border-[var(--border)] bg-[var(--bg-app)] text-[var(--text-muted)]"
                        }`}
                      >
                        {tag.label}
                      </span>
                    ))}
                  </div>
                  <p className="max-w-[58ch] text-[13px] leading-snug text-[var(--text-secondary)]">{screen.desc}</p>
                  <p className="mt-2 truncate font-mono text-[11px] text-[var(--text-muted)]">{screen.code}</p>
                </div>
                <span className="font-mono text-lg text-[var(--text-muted)] transition group-hover:text-[var(--accent)] md:justify-self-end">
                  →
                </span>
              </Link>
            ))}
          </div>
        </section>

        <dl className="mt-7 grid overflow-hidden rounded-[var(--radius-panel)] border border-[var(--border)] bg-[var(--border)] md:grid-cols-3">
          {facts.map((f) => (
            <div key={f.term} className="bg-[var(--bg-editor)] px-4 py-3.5">
              <dt className="mb-1 text-[11px] font-semibold uppercase tracking-widest text-[var(--text-muted)]">
                {f.term}
              </dt>
              <dd className="text-[13px] leading-snug text-[var(--text-secondary)]">{f.detail}</dd>
            </div>
          ))}
        </dl>
      </main>

      <footer className="relative mx-auto flex max-w-[1080px] flex-wrap justify-between gap-3 border-t border-[var(--border)] px-5 py-5 text-xs text-[var(--text-muted)]">
        <span className="max-w-[42ch] leading-snug">Next.js 16 + CodeMirror 6 · tamamen istemci tarafı</span>
        <span>F10 debugger, AST ağacı, Türkçe adım açıklaması</span>
      </footer>
    </div>
  );
}
