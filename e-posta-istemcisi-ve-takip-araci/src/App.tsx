import { useCallback, useEffect, useRef, useState } from "react";
import { AboutModal } from "./components/AboutModal";
import { ComposeModal } from "./components/ComposeModal";
import { HelpModal } from "./components/HelpModal";
import { MailList } from "./components/MailList";
import { MailReader } from "./components/MailReader";
import { SettingsModal } from "./components/SettingsModal";
import { Sidebar } from "./components/Sidebar";
import { TemplatesModal } from "./components/TemplatesModal";
import { TitleBar } from "./components/TitleBar";
import { WelcomeModal } from "./components/WelcomeModal";
import type { Account, ComposeMode, FolderCounts, MailFolderView, MailMessage } from "./types";

const EMPTY_COUNTS: FolderCounts = {
  inbox: 0,
  unified: 0,
  sent: 0,
  drafts: 0,
  archive: 0,
  trash: 0,
  starred: 0,
  tracking: 0,
  snoozed: 0,
};

function useNarrowLayout() {
  const [narrow, setNarrow] = useState(() => window.matchMedia("(max-width: 900px)").matches);
  useEffect(() => {
    const mq = window.matchMedia("(max-width: 900px)");
    const onChange = () => setNarrow(mq.matches);
    mq.addEventListener("change", onChange);
    return () => mq.removeEventListener("change", onChange);
  }, []);
  return narrow;
}

export default function App() {
  const narrow = useNarrowLayout();
  const [folder, setFolder] = useState<MailFolderView>("inbox");
  const [messages, setMessages] = useState<MailMessage[]>([]);
  const [counts, setCounts] = useState<FolderCounts>(EMPTY_COUNTS);
  const [tracking, setTracking] = useState<MailMessage[]>([]);
  const [accounts, setAccounts] = useState<Account[]>([]);
  const [activeAccountId, setActiveAccountId] = useState<string | undefined>();
  const [selected, setSelected] = useState<MailMessage | null>(null);
  const [selectedIndex, setSelectedIndex] = useState(0);
  const [selectedIds, setSelectedIds] = useState<Set<string>>(new Set());
  const [bulkMode, setBulkMode] = useState(false);
  const [search, setSearch] = useState("");
  const [status, setStatus] = useState("");
  const [syncing, setSyncing] = useState(false);
  const [composeOpen, setComposeOpen] = useState(false);
  const [composeMode, setComposeMode] = useState<ComposeMode>("new");
  const [composeSource, setComposeSource] = useState<MailMessage | null>(null);
  const [draft, setDraft] = useState<MailMessage | null>(null);
  const [settingsOpen, setSettingsOpen] = useState(false);
  const [templatesOpen, setTemplatesOpen] = useState(false);
  const [helpOpen, setHelpOpen] = useState(false);
  const [aboutOpen, setAboutOpen] = useState(false);
  const [welcomeOpen, setWelcomeOpen] = useState(false);
  const [mobileReader, setMobileReader] = useState(false);
  // Son geri alınabilir işlem: işlem öncesi mesaj kopyaları (sil / arşivle / ertele / toplu işlem).
  const [undo, setUndo] = useState<MailMessage[] | null>(null);
  // Takip panelinden başka klasördeki bir mail açılınca: klasör değişip liste gelince seçilecek id.
  const pendingOpen = useRef<string | null>(null);

  const multiAccount = accounts.length > 1;
  const activeAccount = accounts.find((a) => a.id === activeAccountId) ?? accounts[0] ?? null;

  const refresh = useCallback(async () => {
    const filters = { query: search };
    const [list, folderCounts, trackingList, accs] = await Promise.all([
      window.electronAPI.listMail(folder, filters),
      window.electronAPI.folderCounts(),
      window.electronAPI.trackingList(),
      window.electronAPI.listAccounts(),
    ]);
    setMessages(list);
    setCounts(folderCounts);
    setTracking(trackingList);
    setAccounts(accs);
    setActiveAccountId((prev) => prev ?? accs[0]?.id);
    const pendingIdx = pendingOpen.current ? list.findIndex((m) => m.id === pendingOpen.current) : -1;
    pendingOpen.current = null;
    if (pendingIdx >= 0) {
      setSelectedIndex(pendingIdx);
      setSelected(list[pendingIdx]);
      setMobileReader(true);
      return;
    }
    setSelected((prev) => {
      if (!prev) return null;
      return list.find((m) => m.id === prev.id) ?? trackingList.find((m) => m.id === prev.id) ?? null;
    });
  }, [folder, search]);

  useEffect(() => {
    window.electronAPI.getSettings().then((s) => {
      if (!s.onboardingDone) setWelcomeOpen(true);
    });
  }, []);

  useEffect(() => {
    refresh();
  }, [refresh]);

  useEffect(() => {
    const unsub = window.electronAPI.onMailSynced(({ total, errors }) => {
      setSyncing(false);
      if (total > 0) setStatus(`${total} mesaj senkronize edildi`);
      if (errors.length) setStatus(errors[0]);
      refresh();
    });
    return unsub;
  }, [refresh]);

  useEffect(() => {
    setSelectedIndex(0);
    setSelected(null);
    setSelectedIds(new Set());
    setMobileReader(false);
  }, [folder, search]);

  useEffect(() => {
    if (!status) return;
    const t = setTimeout(() => {
      setStatus("");
      setUndo(null);
    }, undo ? 8000 : 3200);
    return () => clearTimeout(t);
  }, [status, undo]);

  /** İşlemi yapar, öncesindeki kopyaları "Geri al" için saklar. */
  const undoable = useCallback(
    async (ids: string[], label: string, op: () => Promise<unknown>) => {
      const before = [...messages, ...tracking].filter((m, i, all) => ids.includes(m.id) && all.findIndex((x) => x.id === m.id) === i);
      await op();
      setUndo(before.length ? before : null);
      setStatus(label);
    },
    [messages, tracking]
  );

  const performUndo = useCallback(async () => {
    if (!undo) return;
    await window.electronAPI.restoreMail(undo);
    setUndo(null);
    setStatus("Geri alındı");
    await refresh();
  }, [undo, refresh]);

  async function openMessage(msg: MailMessage) {
    setSelected(msg);
    setMobileReader(true);
    const idx = messages.findIndex((m) => m.id === msg.id);
    if (idx >= 0) setSelectedIndex(idx);
    if (!msg.read) {
      await window.electronAPI.markRead(msg.id, true);
      await refresh();
    }
  }

  function openCompose(mode: ComposeMode, source?: MailMessage | null) {
    setComposeMode(mode);
    setComposeSource(source ?? null);
    setDraft(mode === "draft" ? source ?? null : null);
    setComposeOpen(true);
  }

  async function syncImap() {
    if (!accounts.some((a) => a.email && a.server)) {
      setStatus("Senkronize edilecek hesap yok — Ayarlar'dan hesap ekleyin");
      return;
    }
    try {
      setSyncing(true);
      setStatus("IMAP senkronize ediliyor…");
      const res = await window.electronAPI.syncImap();
      setSyncing(false);
      if (res.errors.length) setStatus(res.errors.join("; "));
      else setStatus(`${res.count} mesaj indirildi`);
      if (multiAccount) setFolder("unified");
      await refresh();
    } catch (e) {
      setSyncing(false);
      setStatus(e instanceof Error ? e.message : String(e));
    }
  }

  const modalOpen = composeOpen || settingsOpen || templatesOpen || helpOpen || aboutOpen || welcomeOpen;

  const handleArchive = useCallback(async (id: string) => {
    await undoable([id], "Arşivlendi", () => window.electronAPI.archiveMail(id));
    setSelected(null);
    setMobileReader(false);
    await refresh();
  }, [refresh, undoable]);

  const handleDelete = useCallback(async (id: string) => {
    const permanent = [...messages, ...tracking].find((m) => m.id === id)?.folder === "trash";
    await undoable([id], permanent ? "Kalıcı silindi" : "Çöpe taşındı", () => window.electronAPI.deleteMail(id));
    setSelected(null);
    setMobileReader(false);
    await refresh();
  }, [refresh, undoable, messages, tracking]);

  const handleStar = useCallback(async (id: string) => {
    await window.electronAPI.toggleStar(id);
    await refresh();
  }, [refresh]);

  const handleMarkUnread = useCallback(async (id: string) => {
    await window.electronAPI.markRead(id, false);
    setStatus("Okunmadı işaretlendi");
    await refresh();
  }, [refresh]);

  const readerProps = {
    onReply: (msg: MailMessage) => openCompose("reply", msg),
    onForward: (msg: MailMessage) => openCompose("forward", msg),
    onStar: handleStar,
    onArchive: handleArchive,
    onDelete: handleDelete,
    onSnooze: async (id: string, until: string) => {
      await undoable([id], "Mail ertelendi", () => window.electronAPI.snoozeMail(id, until));
      setSelected(null);
      setMobileReader(false);
      await refresh();
    },
    onRestore: async (id: string) => {
      const msg = [...messages, ...tracking].find((m) => m.id === id);
      if (!msg) return;
      // ponytail: çöpten dönüşte asıl klasör saklanmıyor; sunucudan gelen -> Gelen, yerel -> Gönderilmiş.
      const folder = msg.folder === "trash" ? (msg.remote ? "inbox" : "sent") : msg.folder;
      await window.electronAPI.restoreMail([{ ...msg, folder, archived: false, snoozedUntil: null }]);
      setSelected(null);
      setStatus(folder === "sent" ? "Gönderilmiş klasörüne taşındı" : "Gelen kutusuna taşındı");
      await refresh();
    },
    onToggleTrack: async (msg: MailMessage) => {
      if (msg.tracking?.waitingReply) {
        await window.electronAPI.trackMail(msg.id, null);
        setStatus("Takip kaldırıldı");
      } else {
        await window.electronAPI.trackMail(msg.id, {
          waitingReply: true,
          startedAt: new Date().toISOString(),
          reminderDays: 3,
        });
        setStatus("Yanıt takibi başlatıldı");
      }
      await refresh();
    },
    onMarkUnread: handleMarkUnread,
  };

  useEffect(() => {
    function onKeyDown(e: KeyboardEvent) {
      const target = e.target as HTMLElement;
      const typing =
        target.tagName === "INPUT" ||
        target.tagName === "TEXTAREA" ||
        target.tagName === "SELECT";

      if (e.key === "F1") {
        e.preventDefault();
        setHelpOpen(true);
        return;
      }
      if (typing || modalOpen) return;

      if (e.key.toLowerCase() === "z" && (e.ctrlKey || e.metaKey)) {
        e.preventDefault();
        void performUndo();
        return;
      }
      if (e.ctrlKey || e.metaKey || e.altKey) return;

      const sel = selected;
      const actions: Record<string, (() => void) | null> = {
        j: () => setSelectedIndex((i) => Math.min(i + 1, messages.length - 1)),
        k: () => setSelectedIndex((i) => Math.max(i - 1, 0)),
        // Odak bir düğme/satırdaysa Enter onu çalıştırır; burada yalnızca odak boştayken mail açılır.
        Enter: target === document.body && messages[selectedIndex] ? () => openMessage(messages[selectedIndex]) : null,
        r: sel ? () => openCompose("reply", sel) : null,
        f: sel ? () => openCompose("forward", sel) : null,
        e: sel ? () => handleArchive(sel.id) : null,
        u: sel ? () => handleMarkUnread(sel.id) : null,
        "#": sel ? () => handleDelete(sel.id) : null,
        s: sel ? () => handleStar(sel.id) : null,
        c: () => openCompose("new"),
        "/": () => document.querySelector<HTMLInputElement>(".search-wrap input")?.focus(),
      };
      const run = actions[e.key];
      if (!run) return;
      // Önceden tuş varsayılanı engellenmiyordu: "r" ile açılan yanıtta Kime alanına "r" yazılıyordu.
      e.preventDefault();
      run();
    }

    window.addEventListener("keydown", onKeyDown);
    return () => window.removeEventListener("keydown", onKeyDown);
  }, [modalOpen, messages, selectedIndex, selected, handleArchive, handleDelete, handleStar, handleMarkUnread, performUndo]);

  useEffect(() => {
    const msg = messages[selectedIndex];
    if (msg && !narrow) setSelected(msg);
  }, [selectedIndex, messages, narrow]);

  return (
    <div className="window">
      <TitleBar syncing={syncing} onSync={syncImap} onSettings={() => setSettingsOpen(true)} />

      <div className="app">
        <Sidebar
          folder={folder}
          counts={counts}
          tracking={tracking}
          multiAccount={multiAccount}
          account={activeAccount}
          onFolderChange={(f) => setFolder(f)}
          onCompose={() => openCompose("new")}
          onOpenMessage={(id) => {
            const msg = messages.find((m) => m.id === id) ?? tracking.find((m) => m.id === id);
            if (!msg) return;
            const target = msg.folder === "sent" ? "sent" : "inbox";
            if (target === folder) return void openMessage(msg);
            // Önceden klasör değişince seçim sıfırlanıyor, başka bir mail açılıyordu.
            pendingOpen.current = msg.id;
            setFolder(target);
          }}
        />

        <MailList
          folder={folder}
          messages={messages}
          selectedId={selected?.id ?? null}
          selectedIds={selectedIds}
          search={search}
          bulkMode={bulkMode}
          multiAccount={multiAccount}
          onFolderChange={setFolder}
          onCompose={() => openCompose("new")}
          onSearchChange={setSearch}
          onSelect={(msg) => {
            if (msg.folder === "drafts") {
              openCompose("draft", msg);
              return;
            }
            openMessage(msg);
          }}
          onToggleSelect={(id) => {
            setSelectedIds((prev) => {
              const next = new Set(prev);
              if (next.has(id)) next.delete(id);
              else next.add(id);
              return next;
            });
          }}
          onStar={(id) => window.electronAPI.toggleStar(id).then(refresh)}
          onBulk={async (action, payload) => {
            const ids = [...selectedIds];
            await undoable(ids, `${ids.length} mail güncellendi`, () =>
              window.electronAPI.bulkAction(ids, action, payload)
            );
            setSelectedIds(new Set());
            setBulkMode(false);
            await refresh();
          }}
          onToggleBulk={() => setBulkMode((v) => !v)}
        />

        {(!narrow || !mobileReader) && (
          <MailReader message={selected} {...readerProps} />
        )}

        {narrow && mobileReader && selected && (
          <MailReader
            message={selected}
            overlay
            onClose={() => setMobileReader(false)}
            {...readerProps}
          />
        )}
      </div>

      {status && (
        <div className="status-bar show" role="status" aria-live="polite">
          {status}
          {undo && (
            <button type="button" className="toolbar-link status-undo" onClick={performUndo} title="Geri al (Ctrl+Z)">
              Geri al
            </button>
          )}
        </div>
      )}
      <div className="shortcut-hint">
        <kbd>j</kbd> <kbd>k</kbd> · <kbd>c</kbd> · <kbd>/</kbd> · <kbd>F1</kbd>
      </div>

      <ComposeModal
        open={composeOpen}
        mode={composeMode}
        source={composeSource}
        draft={draft}
        accountId={activeAccountId}
        onClose={() => {
          setComposeOpen(false);
          setComposeSource(null);
          setDraft(null);
        }}
        onSend={async (input) => {
          await window.electronAPI.sendMail(input);
          setComposeOpen(false);
          setFolder("sent");
          setStatus("Mesaj gönderildi");
          await refresh();
        }}
        onSaveDraft={async (input) => {
          await window.electronAPI.saveDraft(input);
          setStatus("Taslak kaydedildi");
          setComposeOpen(false);
          setFolder("drafts");
          await refresh();
        }}
      />

      <SettingsModal
        open={settingsOpen}
        onClose={() => setSettingsOpen(false)}
        onSaved={(message) => {
          setStatus(message);
          refresh();
        }}
        onTemplates={() => {
          setSettingsOpen(false);
          setTemplatesOpen(true);
        }}
        onHelp={() => {
          setSettingsOpen(false);
          setHelpOpen(true);
        }}
        onAbout={() => {
          setSettingsOpen(false);
          setAboutOpen(true);
        }}
        onMarkAllRead={async () => {
          const n = await window.electronAPI.markAllRead(folder);
          setStatus(`${n} mail okundu işaretlendi`);
          await refresh();
        }}
        onEmptyTrash={async () => {
          const n = await window.electronAPI.emptyTrash();
          setStatus(`${n} mail kalıcı silindi`);
          await refresh();
        }}
      />

      <TemplatesModal open={templatesOpen} onClose={() => setTemplatesOpen(false)} />
      <HelpModal open={helpOpen} onClose={() => setHelpOpen(false)} />
      <AboutModal open={aboutOpen} onClose={() => setAboutOpen(false)} />
      <WelcomeModal
        open={welcomeOpen}
        onClose={() => setWelcomeOpen(false)}
        onOpenSettings={() => {
          setWelcomeOpen(false);
          setSettingsOpen(true);
        }}
      />
    </div>
  );
}
