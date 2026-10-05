import http, { type IncomingMessage, type Server } from "http";
import { matchMockRule } from "./mock";
import { parseHookSlug } from "./server-utils";
import type { MockRule, ServerStatus } from "../src/types";

/** Sunucunun ihtiyaç duyduğu veri işlemleri (main'de SQLite, testlerde bellek içi). */
export type HookStore = {
  /** slug için endpoint id; slug yoksa varsayılan endpoint, bilinmeyen slug için null */
  resolveEndpoint(slug: string | null): string | null;
  mockRules(endpointId: string): MockRule[];
  record(endpointId: string, req: IncomingMessage, body: string): void;
  maxBodyBytes(): number;
};

const PORT_ATTEMPTS = 5;

export function createHookServer(store: HookStore) {
  let server: Server | null = null;
  let current: ServerStatus = { running: false, port: 0 };

  function handle(req: IncomingMessage, res: http.ServerResponse) {
    // Gövde bellekte en fazla maxBodyBytes+1 bayta kadar tutulur; fazlası okunur ama saklanmaz
    // (önceden sınırsız birikiyordu). +1 bayt, truncateBody'nin "kısaltıldı" notu ekleyebilmesi için.
    const limit = store.maxBodyBytes() + 1;
    const chunks: Buffer[] = [];
    let kept = 0;
    req.on("data", (chunk: Buffer) => {
      if (kept >= limit) return;
      chunks.push(chunk);
      kept += chunk.length;
    });
    req.on("end", () => {
      try {
        const rawBody = Buffer.concat(chunks).subarray(0, limit).toString("utf8");
        const url = req.url ?? "/";
        const slug = parseHookSlug(url);
        const endpointId = store.resolveEndpoint(slug);
        if (!endpointId) {
          res.writeHead(404, { "Content-Type": "application/json" });
          res.end(JSON.stringify({ error: "unknown_hook", slug }));
          return;
        }

        const mock = matchMockRule(store.mockRules(endpointId), endpointId, req.method ?? "GET", url);
        store.record(endpointId, req, rawBody);

        if (mock) {
          res.writeHead(mock.statusCode, { "Content-Type": mock.contentType });
          res.end(mock.body);
          return;
        }
        res.writeHead(200, { "Content-Type": "application/json" });
        res.end(JSON.stringify({ ok: true, received: true }));
      } catch (e) {
        // Kayıt hatası ana süreci çökertmez; gönderen 500 alır.
        if (!res.headersSent) res.writeHead(500, { "Content-Type": "application/json" });
        res.end(JSON.stringify({ error: "internal_error", message: e instanceof Error ? e.message : String(e) }));
      }
    });
  }

  function stop() {
    if (server) {
      server.close();
      server.closeAllConnections();
      server = null;
    }
    current = { running: false, port: current.port };
  }

  function start(port: number): Promise<ServerStatus> {
    stop();
    if (!Number.isInteger(port) || port < 1 || port > 65535) {
      current = { running: false, port, error: `Geçersiz port: ${port}. 1-65535 arası bir sayı girin.` };
      return Promise.resolve(current);
    }

    return new Promise((resolve) => {
      const tryListen = (p: number, attemptsLeft: number) => {
        const s = http.createServer(handle);
        s.once("error", (err: NodeJS.ErrnoException) => {
          // Port doluysa sıradaki portları dener; bulunan port arayüze geri döner
          if (err.code === "EADDRINUSE" && attemptsLeft > 0 && p < 65535) {
            tryListen(p + 1, attemptsLeft - 1);
            return;
          }
          current = {
            running: false,
            port,
            error:
              err.code === "EADDRINUSE"
                ? `Port ${port}-${p} aralığı kullanımda. Başka bir port deneyin.`
                : err.message,
          };
          resolve(current);
        });
        // Yalnızca loopback'e bağlanır: dışarıdan erişilemez (tünel/ngrok ile yönlendirilebilir)
        s.listen(p, "127.0.0.1", () => {
          server = s;
          current = { running: true, port: p };
          resolve(current);
        });
      };
      tryListen(port, PORT_ATTEMPTS);
    });
  }

  return { start, stop, status: (): ServerStatus => ({ ...current, running: server !== null }) };
}
