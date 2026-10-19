import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { EndpointCreateModal } from "./components/EndpointCreateModal";
import { EndpointSidebar } from "./components/EndpointSidebar";
import { FilterBar } from "./components/FilterBar";
import { IconMenu } from "./components/Icons";
import { MockRulesModal } from "./components/MockRulesModal";
import { RequestDetail } from "./components/RequestDetail";
import { RequestList } from "./components/RequestList";
import { SettingsModal } from "./components/SettingsModal";
import { ShortcutsModal } from "./components/ShortcutsModal";
import { Toast } from "./components/Toast";
import { useKeyboardNav } from "./hooks/useKeyboardNav";
import { useToast } from "./hooks/useToast";
import { toCurl } from "./lib/curl";
import { matchesFilters } from "./lib/filterRequests";
import type { AppSettings, MockRule, RequestFilters, WebhookEndpoint, WebhookRequest } from "./types";

export default function App() {
  const api = window.electronAPI;
  const toast = useToast();
  const showToast = toast.show;
  const filterRef = useRef<HTMLInputElement>(null);

  const [settings, setSettings] = useState<AppSettings>({
    defaultPort: 8787,
    maxRequests: 1000,
    maxBodyBytes: 512_000,
    maskSecrets: true,
    autoStart: true,
  });
  const [portInput, setPortInput] = useState("8787");
  const [port, setPort] = useState(8787);
  const [isRunning, setIsRunning] = useState(false);
  const [serverError, setServerError] = useState<string | null>(null);
  const [endpoints, setEndpoints] = useState<WebhookEndpoint[]>([]);
  const [activeEndpointId, setActiveEndpointId] = useState<string | null>(null);
  const [requests, setRequests] = useState<WebhookRequest[]>([]);
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [newId, setNewId] = useState<string | null>(null);
  const [filters, setFilters] = useState<RequestFilters>({ methods: [], path: "" });
  const [settingsOpen, setSettingsOpen] = useState(false);
  const [mockOpen, setMockOpen] = useState(false);
  const [createOpen, setCreateOpen] = useState(false);
  const [shortcutsOpen, setShortcutsOpen] = useState(false);
  const [drawerOpen, setDrawerOpen] = useState(false);
  const [mockRules, setMockRules] = useState<MockRule[]>([]);
  const activeRef = useRef(activeEndpointId);
  activeRef.current = activeEndpointId;

  const loadEndpoints = useCallback(async () => {
    const eps = await api?.getEndpoints();
    if (eps?.length) {
      setEndpoints(eps);
      setActiveEndpointId((prev) => prev ?? eps[0].id);
    }
  }, [api]);

  const loadMockRules = useCallback(
    async (endpointId: string | null) => {
      if (!api || !endpointId) return;
      setMockRules(await api.listMockRules(endpointId));
    },
    [api]
  );

  useEffect(() => {
    if (!api) return;
    api.getSettings().then((s) => {
      setSettings(s);
      setPortInput(String(s.defaultPort));
    });
    api.getServerStatus().then((s) => {
      setIsRunning(s.running);
      if (s.port) setPort(s.port);
      if (s.running) setPortInput(String(s.port));
      if (s.error) setServerError(s.error); // ör. açılışta otomatik başlatma başarısız
    });
    api.getRequests().then(setRequests);
    loadEndpoints();
    return api.onRequest((req) => {
      setRequests((prev) => [req, ...prev]);
      setNewId(req.id);
      setTimeout(() => setNewId(null), 500);
      if (!activeRef.current || req.endpointId === activeRef.current) {
        setSelectedId(req.id);
      }
      toast.show("Yeni istek alındı");
    });
  }, [api, loadEndpoints, showToast]);

  useEffect(() => {
    loadMockRules(activeEndpointId);
  }, [activeEndpointId, loadMockRules, mockOpen]);

  const filteredRequests = useMemo(() => {
    let list = requests;
    if (activeEndpointId) list = list.filter((r) => r.endpointId === activeEndpointId);
    return list.filter((r) => matchesFilters(r, filters));
  }, [requests, activeEndpointId, filters]);

  const requestCounts = useMemo(() => {
    const counts: Record<string, number> = {};
    for (const r of requests) counts[r.endpointId] = (counts[r.endpointId] ?? 0) + 1;
    return counts;
  }, [requests]);

  const selected = filteredRequests.find((r) => r.id === selectedId) ?? null;
  const activeEndpoint = endpoints.find((e) => e.id === activeEndpointId);

  const closeOverlays = useCallback(() => {
    setSettingsOpen(false);
    setMockOpen(false);
    setCreateOpen(false);
    setShortcutsOpen(false);
    setDrawerOpen(false);
  }, []);

  useKeyboardNav({
    ids: filteredRequests.map((r) => r.id),
    selectedId,
    onSelect: setSelectedId,
    onReplay: selected ? () => api?.replayRequest(selected.id).then((r) => toast.show(r.ok ? "Yeniden gönderildi" : (r.error ?? "Hata"), !r.ok)) : undefined,
    onCopyCurl: selected
      ? () => navigator.clipboard.writeText(toCurl(selected, port)).then(() => toast.show("curl kopyalandı"))
      : undefined,
    onFocusFilter: () => filterRef.current?.focus(),
    onCreateEndpoint: () => setCreateOpen(true),
    onCopyActiveUrl: activeEndpoint
      ? () =>
          navigator.clipboard
            .writeText(`http://127.0.0.1:${port}/hook/${activeEndpoint.slug}`)
            .then(() => toast.show("URL kopyalandı"))
      : undefined,
    onOpenShortcuts: () => setShortcutsOpen(true),
    onCloseOverlay: closeOverlays,
    enabled: Boolean(api),
    modalOpen: settingsOpen || mockOpen || createOpen || shortcutsOpen,
  });

  async function toggleServer() {
    if (!api) return;
    setServerError(null);
    if (isRunning) {
      await api.stopServer();
      setIsRunning(false);
    } else {
      const res = await api.startServer(Number(portInput) || settings.defaultPort);
      if (res.error) {
        setServerError(res.error);
        setIsRunning(false);
        return;
      }
      setPort(res.port);
      setPortInput(String(res.port));
      setIsRunning(res.running);
      toast.show(`Sunucu :${res.port} üzerinde dinliyor`);
    }
  }

  async function handleCreateEndpoint() {
    const ep = await api?.createEndpoint();
    if (ep) {
      setEndpoints((prev) => [...prev, ep]);
      setActiveEndpointId(ep.id);
      toast.show("Endpoint oluşturuldu");
    }
  }

  async function handleDeleteEndpoint(id: string) {
    const ok = await api?.deleteEndpoint(id);
    if (!ok) return;
    setEndpoints((prev) => {
      const next = prev.filter((e) => e.id !== id);
      if (activeEndpointId === id) setActiveEndpointId(next[0]?.id ?? null);
      return next;
    });
    setRequests((prev) => prev.filter((r) => r.endpointId !== id));
  }

  async function handleClear() {
    if (!api || !activeEndpointId) return;
    await api.clearRequests(activeEndpointId);
    setRequests((prev) => prev.filter((r) => r.endpointId !== activeEndpointId));
    setSelectedId(null);
    toast.show("Liste temizlendi");
  }

  if (!api) {
    return (
      <div className="browser-fallback">
        <h1>HookYerel</h1>
        <p>Bu arayüz yalnızca Electron masaüstü uygulamasında çalışır.</p>
        <p>
          <code>.\run.ps1</code> veya <code>npm run dev</code> ile başlatın.
        </p>
      </div>
    );
  }

  return (
    <div className="electron-shell" aria-live="polite">
      <header className="titlebar" aria-label="Uygulama başlığı">
        <span className="titlebar-title">Yerel Webhook Test Aracı</span>
        <span className={`titlebar-badge ${isRunning ? "" : "off"}`}>127.0.0.1{isRunning ? `:${port}` : ""}</span>
      </header>

      <div className="app" role="application" aria-label="Webhook test arayüzü">
        <EndpointSidebar
          endpoints={endpoints}
          activeId={activeEndpointId}
          port={port}
          isRunning={isRunning}
          portInput={portInput}
          serverError={serverError}
          drawerOpen={drawerOpen}
          onPortChange={setPortInput}
          onToggleServer={toggleServer}
          onSelect={(id) => {
            setActiveEndpointId(id);
            setDrawerOpen(false);
          }}
          onCreate={() => setCreateOpen(true)}
          onDelete={handleDeleteEndpoint}
          onCopyUrl={async (url) => {
            await navigator.clipboard.writeText(url);
            toast.show("URL kopyalandı");
          }}
          onOpenSettings={() => setSettingsOpen(true)}
          onOpenMockRules={() => setMockOpen(true)}
          requestCounts={requestCounts}
        />

        <div className="request-list-panel">
          <FilterBar filters={filters} onChange={setFilters} inputRef={filterRef} />
          <RequestList
            requests={filteredRequests}
            selectedId={selectedId}
            newId={newId}
            filters={filters}
            onSelect={setSelectedId}
            onClear={handleClear}
          />
        </div>

        <RequestDetail
          request={selected}
          port={port}
          isRunning={isRunning}
          onDelete={async (id) => {
            await api.deleteRequest(id);
            setRequests((prev) => prev.filter((r) => r.id !== id));
            if (selectedId === id) setSelectedId(null);
            toast.show("İstek silindi");
          }}
          onReplay={(id) => api.replayRequest(id)}
          onVerifySignature={(requestId, preset, secret) => api.verifySignature({ requestId, preset, secret })}
          onToast={toast.show}
        />
      </div>

      <button
        type="button"
        className="drawer-toggle"
        aria-expanded={drawerOpen}
        onClick={() => setDrawerOpen((v) => !v)}
      >
        <IconMenu />
        Endpoint&apos;ler
      </button>
      <div
        className={`drawer-backdrop ${drawerOpen ? "open" : ""}`}
        onClick={() => setDrawerOpen(false)}
        aria-hidden={!drawerOpen}
      />

      <Toast message={toast.message} error={toast.error} />

      <SettingsModal
        open={settingsOpen}
        settings={settings}
        onClose={() => setSettingsOpen(false)}
        onSave={async (partial) => {
          const next = await api.saveSettings(partial);
          setSettings(next);
          setPortInput(String(next.defaultPort));
          toast.show("Ayarlar kaydedildi");
        }}
        onExport={async () => {
          const res = await api.exportRequests();
          toast.show(res.ok ? "Dışa aktarıldı" : "İptal edildi", !res.ok);
        }}
      />

      <MockRulesModal
        open={mockOpen}
        endpointId={activeEndpointId}
        rules={mockRules}
        onClose={() => setMockOpen(false)}
        onSave={async (rule) => {
          await api.saveMockRule(rule);
          await loadMockRules(activeEndpointId);
          toast.show("Mock kuralı eklendi");
        }}
        onDelete={async (id) => {
          await api.deleteMockRule(id);
          await loadMockRules(activeEndpointId);
        }}
      />

      <EndpointCreateModal
        open={createOpen}
        port={port}
        serverError={serverError}
        onClose={() => setCreateOpen(false)}
        onCreate={handleCreateEndpoint}
      />

      <ShortcutsModal open={shortcutsOpen} onClose={() => setShortcutsOpen(false)} />
    </div>
  );
}
