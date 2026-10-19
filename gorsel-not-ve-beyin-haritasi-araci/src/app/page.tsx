"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { AppMark, IconPlus } from "@/components/AppMark";
import {
  BtnDanger,
  BtnGhost,
  BtnPrimary,
  FieldInput,
  FieldLabel,
  Modal,
  ModalActions,
} from "@/components/Modal";
import { StatusToast } from "@/components/StatusToast";
import { parseImport } from "@/lib/board-utils";
import { formatBoardDate } from "@/lib/format-date";

type Board = { id: string; name: string; updatedAt: string; isEmpty: boolean };

function BoardThumb({ empty }: { empty: boolean }) {
  if (empty) {
    return (
      <div
        className="h-[108px] rounded-[var(--radius-md)] canvas-dots border border-[color-mix(in_srgb,var(--border)_80%,transparent)] relative overflow-hidden after:content-[''] after:absolute after:inset-0 after:opacity-35 after:bg-[repeating-linear-gradient(-45deg,transparent,transparent_8px,color-mix(in_srgb,var(--border)_40%,transparent)_8px,color-mix(in_srgb,var(--border)_40%,transparent)_9px)]"
        aria-hidden
      />
    );
  }

  return (
    <div
      className="h-[108px] rounded-[var(--radius-md)] canvas-dots border border-[color-mix(in_srgb,var(--border)_80%,transparent)] relative overflow-hidden"
      aria-hidden
    >
      <span className="absolute w-[52%] h-[38%] top-[28%] left-[22%] grid place-items-center text-[9px] font-medium text-[var(--text-primary)] border-2 border-[var(--stroke)] rounded-md bg-[var(--node-1)] px-1">
        Merkez
      </span>
      <span className="absolute w-[34%] h-[28%] top-[12%] left-[58%] grid place-items-center text-[9px] font-medium border-2 border-[var(--stroke)] rounded-md bg-[var(--node-2)]">
        Dal
      </span>
      <span className="absolute w-[34%] h-[28%] top-[58%] left-[8%] grid place-items-center text-[9px] font-medium border-2 border-[var(--stroke)] rounded-md bg-[var(--node-2)]">
        Dal
      </span>
      <span className="absolute w-[28%] h-[24%] top-[62%] left-[58%] grid place-items-center text-[8px] font-medium border-2 border-[var(--stroke)] rounded-md bg-[var(--node-3)]">
        Yaprak
      </span>
    </div>
  );
}

export default function Home() {
  const router = useRouter();
  const [boards, setBoards] = useState<Board[]>([]);
  const [status, setStatus] = useState<string | null>(null);
  const [createOpen, setCreateOpen] = useState(false);
  const [renameOpen, setRenameOpen] = useState(false);
  const [deleteOpen, setDeleteOpen] = useState(false);
  const [createName, setCreateName] = useState("");
  const [renameValue, setRenameValue] = useState("");
  const [target, setTarget] = useState<Board | null>(null);
  const [removingId, setRemovingId] = useState<string | null>(null);
  const [flashId, setFlashId] = useState<string | null>(null);
  const [query, setQuery] = useState("");
  const [loadFailed, setLoadFailed] = useState(false);
  const fileRef = useRef<HTMLInputElement>(null);

  const load = useCallback(async () => {
    try {
      const res = await fetch("/api/boards");
      if (!res.ok) throw new Error();
      setBoards((await res.json()).boards ?? []);
      setLoadFailed(false);
    } catch {
      setLoadFailed(true);
    }
  }, []);

  const visibleBoards = useMemo(() => {
    const q = query.trim().toLocaleLowerCase("tr");
    return q ? boards.filter((b) => b.name.toLocaleLowerCase("tr").includes(q)) : boards;
  }, [boards, query]);

  async function importFile(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0];
    e.target.value = "";
    if (!file) return;
    try {
      const board = parseImport(await file.text(), file.name.replace(/\.(json|tldr)$/i, ""));
      const res = await fetch("/api/boards", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(board),
      });
      if (!res.ok) throw new Error("Pano kaydedilemedi.");
      setStatus(`"${board.name}" içe aktarıldı`);
      await load();
    } catch (err) {
      setStatus(`İçe aktarılamadı: ${err instanceof Error ? err.message : "bilinmeyen hata"}`);
    }
  }

  useEffect(() => {
    void load();
  }, [load]);

  useEffect(() => {
    function onKey(e: KeyboardEvent) {
      if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === "n") {
        const tag = (e.target as HTMLElement).tagName;
        if (tag === "INPUT" || tag === "TEXTAREA") return;
        e.preventDefault();
        setCreateName("");
        setCreateOpen(true);
      }
    }
    document.addEventListener("keydown", onKey);
    return () => document.removeEventListener("keydown", onKey);
  }, []);

  async function createBoard(e: React.FormEvent) {
    e.preventDefault();
    const name = createName.trim() || "Yeni pano";
    const res = await fetch("/api/boards", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ name }),
    }).catch(() => null);
    if (!res?.ok) {
      setStatus("Pano oluşturulamadı");
      return;
    }
    const data = await res.json();
    setCreateOpen(false);
    setCreateName("");
    router.push(`/board/${data.board.id}`);
  }

  async function confirmRename(e: React.FormEvent) {
    e.preventDefault();
    if (!target) return;
    const val = renameValue.trim();
    if (val) {
      const res = await fetch(`/api/boards/${target.id}`, {
        method: "PATCH",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ name: val }),
      }).catch(() => null);
      if (res?.ok) {
        setFlashId(target.id);
        setStatus(`"${val}" olarak kaydedildi`);
      } else {
        setStatus("Ad değiştirilemedi");
      }
      await load();
    }
    setRenameOpen(false);
    setTarget(null);
  }

  async function confirmDelete() {
    if (!target) {
      setDeleteOpen(false);
      return;
    }
    const name = target.name;
    const id = target.id;
    setDeleteOpen(false);
    setTarget(null);
    setRemovingId(id);
    const res = await fetch(`/api/boards/${id}`, { method: "DELETE" }).catch(() => null);
    await load();
    setRemovingId(null);
    // 404: zaten silinmiş
    setStatus(res?.ok || res?.status === 404 ? `"${name}" silindi` : `"${name}" silinemedi`);
  }

  return (
    <div className="page-dots">
      <div className="max-w-[960px] mx-auto p-[var(--page-padding)] max-[480px]:p-4">
        <header className="flex flex-wrap items-start justify-between gap-4 mb-7 animate-reveal-in">
          <div className="flex gap-3.5 items-start">
            <AppMark />
            <div>
              <h1 className="text-[clamp(1.25rem,3vw,1.5rem)] font-semibold leading-tight tracking-tight">
                Görsel Not ve Beyin Haritası
              </h1>
              <p className="mt-1 text-sm text-[var(--text-secondary)] max-w-[42ch]">
                tldraw tuvali ile otomatik kayıt, PNG dışa aktarım ve hafif pano yönetimi
              </p>
              <p className="inline-flex items-center gap-1 mt-2 text-xs text-[var(--text-muted)] max-[480px]:hidden">
                <kbd className="px-1.5 py-0.5 text-[11px] font-medium border border-[var(--border)] rounded bg-[var(--bg-ui)] text-[var(--text-secondary)]">
                  Ctrl
                </kbd>
                +
                <kbd className="px-1.5 py-0.5 text-[11px] font-medium border border-[var(--border)] rounded bg-[var(--bg-ui)] text-[var(--text-secondary)]">
                  N
                </kbd>
                <span className="ml-1">yeni pano</span>
              </p>
            </div>
          </div>
          <div className="flex gap-2 max-[480px]:w-full">
            <button
              type="button"
              onClick={() => fileRef.current?.click()}
              className="inline-flex items-center gap-2 px-4 py-2.5 text-[13px] font-medium text-[var(--text-secondary)] bg-[var(--bg-ui)] border border-[var(--border)] rounded-[var(--radius-md)] tracking-wide transition-[background,transform] duration-[var(--dur-fast)] hover:bg-[var(--bg-hover)] active:scale-[0.98] max-[480px]:flex-1 max-[480px]:justify-center"
              title="Bu uygulamanın JSON yedeği veya tldraw .tldr dosyası"
            >
              İçe aktar
            </button>
            <input
              ref={fileRef}
              type="file"
              accept=".json,.tldr,application/json"
              className="hidden"
              aria-label="Pano dosyası seç"
              onChange={(e) => void importFile(e)}
            />
            <button
              type="button"
              onClick={() => {
                setCreateName("");
                setCreateOpen(true);
              }}
              className="inline-flex items-center gap-2 px-4 py-2.5 text-[13px] font-medium text-white bg-[var(--accent)] rounded-[var(--radius-md)] tracking-wide transition-[background,transform] duration-[var(--dur-fast)] hover:bg-[var(--accent-hover)] active:scale-[0.98] max-[480px]:flex-1 max-[480px]:justify-center"
            >
              <IconPlus />
              Yeni pano
            </button>
          </div>
        </header>

        {loadFailed && (
          <p role="alert" className="mb-4 text-sm text-[var(--danger)]">
            Panolar yüklenemedi.{" "}
            <button type="button" className="underline" onClick={() => void load()}>
              Tekrar dene
            </button>
          </p>
        )}

        {boards.length > 0 && (
          <input
            type="search"
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            placeholder="Panolarda ara…"
            aria-label="Panolarda ara"
            className="w-full mb-4 px-3 py-2 text-sm bg-[var(--bg-ui)] border border-[var(--border)] rounded-[var(--radius-md)] outline-none focus:border-[var(--border-focus)]"
          />
        )}
        {boards.length > 0 && visibleBoards.length === 0 && (
          <p className="text-sm text-[var(--text-muted)] py-8 text-center">&ldquo;{query}&rdquo; ile eşleşen pano yok.</p>
        )}

        {boards.length > 0 ? (
          <div className="grid grid-cols-[repeat(auto-fill,minmax(260px,1fr))] gap-4" role="list" aria-label="Pano listesi">
            {visibleBoards.map((b, i) => (
              <article
                key={b.id}
                role="listitem"
                className={`flex flex-col bg-[var(--bg-ui)] border border-[var(--border)] rounded-[var(--radius-lg)] overflow-hidden animate-card-in transition-[box-shadow,border-color,transform] duration-[var(--dur-ui)] hover:shadow-[var(--shadow-card-hover)] hover:border-[color-mix(in_srgb,var(--border)_50%,var(--accent))] hover:-translate-y-0.5 focus-within:border-[var(--border-focus)] focus-within:shadow-[var(--shadow-card),var(--focus-ring)] ${
                  removingId === b.id ? "animate-card-out" : ""
                }`}
                style={{ animationDelay: `${60 + i * 50}ms` }}
                onAnimationEnd={(e) => {
                  if (e.animationName === "title-flash") setFlashId(null);
                }}
              >
                <Link href={`/board/${b.id}`} className="flex-1 p-5 flex flex-col gap-3">
                  <BoardThumb empty={b.isEmpty} />
                  <h2
                    className={`text-sm font-semibold leading-snug tracking-tight ${
                      flashId === b.id ? "animate-title-flash" : ""
                    }`}
                  >
                    {b.name}
                  </h2>
                  <p className="text-xs text-[var(--text-muted)] tracking-wide">
                    {formatBoardDate(b.updatedAt)}
                    {b.isEmpty ? " · boş" : ""}
                  </p>
                </Link>
                <div className="flex border-t border-[var(--border)] opacity-85 group-hover:opacity-100">
                  <button
                    type="button"
                    className="flex-1 py-2.5 text-xs font-medium text-[var(--text-secondary)] tracking-wide transition-[background,color,transform] duration-[var(--dur-fast)] hover:bg-[var(--bg-hover)] hover:text-[var(--text-primary)] active:scale-[0.98]"
                    onClick={() => {
                      setTarget(b);
                      setRenameValue(b.name);
                      setRenameOpen(true);
                    }}
                  >
                    Yeniden adlandır
                  </button>
                  <button
                    type="button"
                    className="flex-1 py-2.5 text-xs font-medium text-[var(--text-secondary)] border-l border-[var(--border)] tracking-wide transition-[background,color,transform] duration-[var(--dur-fast)] hover:bg-[var(--bg-hover)] hover:text-[var(--danger)] active:scale-[0.98]"
                    onClick={() => {
                      setTarget(b);
                      setDeleteOpen(true);
                    }}
                  >
                    Sil
                  </button>
                </div>
              </article>
            ))}
          </div>
        ) : (
          <div className="flex flex-col items-center text-center py-12 px-6 border-2 border-dashed border-[var(--border)] rounded-[var(--radius-lg)] bg-[var(--bg-ui)] animate-reveal-in">
            <svg
              className="w-16 h-16 mb-4 text-[var(--text-muted)]"
              viewBox="0 0 64 64"
              fill="none"
              stroke="currentColor"
              strokeWidth="1.5"
              aria-hidden
            >
              <rect x="8" y="12" width="48" height="40" rx="4" />
              <path d="M20 28h24M20 36h16" />
              <circle cx="44" cy="20" r="8" strokeDasharray="3 3" />
            </svg>
            <h2 className="text-lg font-semibold tracking-tight mb-2">Henüz pano yok</h2>
            <p className="text-sm text-[var(--text-secondary)] max-w-[32ch] mb-5">
              İlk beyin haritanızı veya görsel not panonuzu oluşturarak başlayın.
            </p>
            <button
              type="button"
              onClick={() => {
                setCreateName("");
                setCreateOpen(true);
              }}
              className="inline-flex items-center gap-2 px-4 py-2.5 text-[13px] font-medium text-white bg-[var(--accent)] rounded-[var(--radius-md)] hover:bg-[var(--accent-hover)]"
            >
              <IconPlus />
              İlk tahtanı oluştur
            </button>
          </div>
        )}
      </div>

      <StatusToast message={status} />

      <Modal open={createOpen} onClose={() => setCreateOpen(false)} title="Yeni pano">
        <form onSubmit={createBoard}>
          <FieldLabel htmlFor="board-name">Pano adı</FieldLabel>
          <FieldInput
            id="board-name"
            value={createName}
            onChange={(e) => setCreateName(e.target.value)}
            placeholder="Örn. Ürün yol haritası"
            autoComplete="off"
            autoFocus
          />
          <ModalActions>
            <BtnGhost type="button" onClick={() => setCreateOpen(false)}>
              İptal
            </BtnGhost>
            <BtnPrimary compact>Oluştur</BtnPrimary>
          </ModalActions>
        </form>
      </Modal>

      <Modal open={renameOpen} onClose={() => setRenameOpen(false)} title="Yeniden adlandır">
        <form onSubmit={confirmRename}>
          <FieldLabel htmlFor="rename-input">Yeni ad</FieldLabel>
          <FieldInput
            id="rename-input"
            value={renameValue}
            onChange={(e) => setRenameValue(e.target.value)}
            autoComplete="off"
            autoFocus
            required
          />
          <ModalActions>
            <BtnGhost type="button" onClick={() => setRenameOpen(false)}>
              İptal
            </BtnGhost>
            <BtnPrimary compact>Kaydet</BtnPrimary>
          </ModalActions>
        </form>
      </Modal>

      <Modal
        open={deleteOpen}
        onClose={() => setDeleteOpen(false)}
        title="Panoyu sil?"
        role="alertdialog"
        describedBy="delete-desc"
      >
        <p id="delete-desc" className="text-sm text-[var(--text-secondary)] mb-5">
          &ldquo;{target?.name}&rdquo; kalıcı olarak silinecek. Bu işlem geri alınamaz.
        </p>
        <ModalActions>
          <BtnGhost type="button" onClick={() => setDeleteOpen(false)}>
            İptal
          </BtnGhost>
          <BtnDanger onClick={() => void confirmDelete()}>Sil</BtnDanger>
        </ModalActions>
      </Modal>
    </div>
  );
}
