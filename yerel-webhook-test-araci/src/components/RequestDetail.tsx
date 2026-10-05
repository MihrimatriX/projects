import { useEffect, useState } from "react";
import { MethodBadge } from "./MethodBadge";
import { IconCopy, IconReplay } from "./Icons";
import { toCurl } from "../lib/curl";
import { tryPrettyJson } from "../lib/formatJson";
import type { ReplayResult, SignaturePreset, WebhookRequest } from "../types";

type Props = {
  request: WebhookRequest | null;
  port: number;
  isRunning: boolean;
  onDelete: (id: string) => void;
  onReplay: (id: string) => Promise<ReplayResult>;
  onVerifySignature: (
    requestId: string,
    preset: SignaturePreset,
    secret: string
  ) => Promise<{ valid: boolean; message: string }>;
  onToast: (msg: string, error?: boolean) => void;
};

function hasSignatureHeader(headers: Record<string, string>): boolean {
  return Object.keys(headers).some((k) => {
    const key = k.toLowerCase();
    return key.includes("signature") || key.includes("hmac");
  });
}

function formatBytes(n: number): string {
  if (n < 1024) return `${n} bayt`;
  return `${(n / 1024).toFixed(n < 10240 ? 1 : 0)} KB`;
}

export function RequestDetail({
  request,
  port,
  isRunning,
  onDelete,
  onReplay,
  onVerifySignature,
  onToast,
}: Props) {
  const [replaying, setReplaying] = useState(false);
  const [headersOpen, setHeadersOpen] = useState(true);
  const [bodyOpen, setBodyOpen] = useState(true);
  const [sigOpen, setSigOpen] = useState(false);
  const [preset, setPreset] = useState<SignaturePreset>("stripe");
  const [secret, setSecret] = useState("");
  const [sigState, setSigState] = useState<"missing" | "valid" | "invalid">("missing");

  useEffect(() => {
    if (!request) return;
    setSigState("missing");
    setSecret("");
  }, [request?.id]);

  if (!request) {
    return (
      <section className="detail-panel" aria-label="İstek detayı">
        <p className="detail-empty">
          Detay için listeden bir istek seçin. ↑↓ gezin, <kbd>r</kbd> replay, <kbd>c</kbd> curl, <kbd>?</kbd> yardım.
        </p>
      </section>
    );
  }

  const { pretty, isJson } = tryPrettyJson(request.body);
  const headerEntries = Object.entries(request.headers).filter(([k]) => !k.startsWith(":"));
  const hmacBadge =
    sigState === "valid" ? "İmza geçerli" : sigState === "invalid" ? "İmza başarısız" : hasSignatureHeader(request.headers) ? "İmza doğrulanmadı" : "İmza yok";

  async function handleReplay() {
    if (!isRunning) {
      onToast("Önce sunucuyu başlatın", true);
      return;
    }
    setReplaying(true);
    const res = await onReplay(request!.id);
    setReplaying(false);
    if (res.ok) {
      onToast(`Yeniden gönderildi · ${res.statusCode ?? "—"}`);
    } else {
      onToast(res.error ?? "Replay başarısız", true);
    }
  }

  async function handleCopyCurl() {
    await navigator.clipboard.writeText(toCurl(request!, port));
    onToast("curl kopyalandı");
  }

  async function handleVerify() {
    const res = await onVerifySignature(request!.id, preset, secret);
    setSigState(res.valid ? "valid" : "invalid");
    onToast(res.message, !res.valid);
  }

  return (
    <section className="detail-panel" aria-label="İstek detayı">
      <div className="detail-toolbar">
        <MethodBadge method={request.method} />
        <span className="detail-url">
          {request.method} http://127.0.0.1:{port}
          {request.url}
        </span>
        <span className={`hmac-badge hmac-${sigState}`}>{hmacBadge}</span>
        <button
          type="button"
          className={`btn-outline ${replaying ? "loading" : ""}`}
          aria-label="Yeniden gönder (r)"
          disabled={!isRunning || replaying}
          onClick={() => void handleReplay()}
        >
          <IconReplay />
          Replay
        </button>
        <button type="button" className="btn-outline" aria-label="curl kopyala (c)" onClick={() => void handleCopyCurl()}>
          <IconCopy />
          curl
        </button>
        <button type="button" className="btn-outline danger" aria-label="İsteği sil" onClick={() => onDelete(request.id)}>
          Sil
        </button>
      </div>

      <div className="detail-body">
        <div className={`detail-section ${sigOpen ? "" : "collapsed"}`}>
          <button type="button" className="detail-section-header" aria-expanded={sigOpen} onClick={() => setSigOpen((v) => !v)}>
            <h3>İmza doğrulama</h3>
            <span className="count">{preset}</span>
          </button>
          <div className="detail-section-content sig-inline">
            <select value={preset} aria-label="İmza preset" onChange={(e) => setPreset(e.target.value as SignaturePreset)}>
              <option value="stripe">Stripe</option>
              <option value="github">GitHub</option>
              <option value="shopify">Shopify</option>
            </select>
            <input
              type="password"
              placeholder="Webhook secret"
              value={secret}
              aria-label="Webhook secret"
              onChange={(e) => setSecret(e.target.value)}
            />
            <button type="button" className="btn-outline" onClick={() => void handleVerify()}>
              Doğrula
            </button>
          </div>
        </div>

        <div className={`detail-section ${headersOpen ? "" : "collapsed"}`}>
          <button type="button" className="detail-section-header" aria-expanded={headersOpen} onClick={() => setHeadersOpen((v) => !v)}>
            <h3>Headers</h3>
            <span className="count">{headerEntries.length} alan</span>
          </button>
          <div className="detail-section-content">
            <table className="header-table">
              <tbody>
                {headerEntries.map(([k, v]) => (
                  <tr key={k}>
                    <td>{k}</td>
                    <td className={v.includes("••••") ? "secret-value" : undefined}>{v}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>

        {request.body && (
          <div className={`detail-section ${bodyOpen ? "" : "collapsed"}`}>
            <button type="button" className="detail-section-header" aria-expanded={bodyOpen} onClick={() => setBodyOpen((v) => !v)}>
              <h3>Body</h3>
              <span className="count">
                {isJson ? "JSON" : "Metin"} · {formatBytes(new TextEncoder().encode(request.body).length)}
              </span>
            </button>
            <div className="detail-section-content">
              <pre className="json-viewer">{pretty}</pre>
            </div>
          </div>
        )}

        <p className="meta-line">{new Date(request.timestamp).toLocaleString("tr-TR")}</p>
      </div>
    </section>
  );
}
