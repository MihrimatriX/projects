import http from "http";
import net from "net";
import { afterEach, describe, expect, it } from "vitest";
import { createHookServer, type HookStore } from "../electron/hookServer";
import type { MockRule } from "../src/types";

type Recorded = { endpointId: string; method: string; url: string; body: string };

function memoryStore(opts: { maxBody?: number; rules?: MockRule[]; failRecord?: boolean } = {}) {
  const recorded: Recorded[] = [];
  const store: HookStore = {
    resolveEndpoint: (slug) => (slug === null ? "ep-default" : slug === "abc" ? "ep-abc" : null),
    mockRules: (id) => (opts.rules ?? []).filter((r) => r.endpointId === id),
    record(endpointId, req, body) {
      if (opts.failRecord) throw new Error("disk dolu");
      recorded.push({ endpointId, method: req.method ?? "", url: req.url ?? "", body });
    },
    maxBodyBytes: () => opts.maxBody ?? 512_000,
  };
  return { store, recorded };
}

function send(port: number, method: string, path: string, body?: string | Buffer) {
  return new Promise<{ status: number; body: string; type?: string }>((resolve, reject) => {
    const req = http.request({ host: "127.0.0.1", port, method, path }, (res) => {
      const chunks: Buffer[] = [];
      res.on("data", (c) => chunks.push(c));
      res.on("end", () =>
        resolve({ status: res.statusCode ?? 0, body: Buffer.concat(chunks).toString(), type: res.headers["content-type"] })
      );
    });
    req.on("error", reject);
    if (body) req.write(body);
    req.end();
  });
}

const servers: ReturnType<typeof createHookServer>[] = [];
const blockers: net.Server[] = [];
afterEach(async () => {
  servers.splice(0).forEach((s) => s.stop());
  await Promise.all(blockers.splice(0).map((b) => new Promise((r) => b.close(r))));
});

async function freePort() {
  const s = net.createServer();
  await new Promise<void>((r) => s.listen(0, "127.0.0.1", () => r()));
  const port = (s.address() as net.AddressInfo).port;
  await new Promise((r) => s.close(r));
  return port;
}

async function started(opts?: Parameters<typeof memoryStore>[0]) {
  const mem = memoryStore(opts);
  const srv = createHookServer(mem.store);
  servers.push(srv);
  const status = await srv.start(await freePort());
  return { ...mem, srv, port: status.port, status };
}

describe("webhook HTTP sunucusu", () => {
  it("/hook/<slug> isteğini kaydeder, varsayılan 200 JSON döner", async () => {
    const { recorded, port, status } = await started();
    expect(status.running).toBe(true);
    const res = await send(port, "POST", "/hook/abc?x=1", '{"event":"paid"}');
    expect(res.status).toBe(200);
    expect(JSON.parse(res.body)).toEqual({ ok: true, received: true });
    expect(recorded).toEqual([{ endpointId: "ep-abc", method: "POST", url: "/hook/abc?x=1", body: '{"event":"paid"}' }]);
  });

  it("bilinmeyen slug 404 döner ve kaydedilmez; slug'sız istek varsayılan endpoint'e gider", async () => {
    const { recorded, port } = await started();
    expect((await send(port, "POST", "/hook/yok")).status).toBe(404);
    expect((await send(port, "GET", "/saglik")).status).toBe(200);
    expect(recorded.map((r) => r.endpointId)).toEqual(["ep-default"]);
  });

  it("mock kuralı durum kodu, içerik tipi ve gövdeyi belirler", async () => {
    const rule: MockRule = {
      id: "m1",
      endpointId: "ep-abc",
      method: "POST",
      pathPattern: "^/hook/abc/odeme$",
      statusCode: 202,
      body: "kabul",
      contentType: "text/plain",
      priority: 1,
    };
    const { port } = await started({ rules: [rule] });
    expect(await send(port, "POST", "/hook/abc/odeme")).toMatchObject({ status: 202, body: "kabul", type: "text/plain" });
    expect((await send(port, "GET", "/hook/abc/odeme")).status).toBe(200);
  });

  it("port doluysa sonraki porta geçer", async () => {
    const port = await freePort();
    const blocker = net.createServer();
    blockers.push(blocker);
    await new Promise<void>((r) => blocker.listen(port, "127.0.0.1", () => r()));
    const srv = createHookServer(memoryStore().store);
    servers.push(srv);
    const st = await srv.start(port);
    expect(st.running).toBe(true);
    expect(st.port).toBeGreaterThan(port);
    expect(srv.status()).toMatchObject({ running: true, port: st.port });
  });

  it("geçersiz port hata mesajı döner (çökme yok)", async () => {
    const srv = createHookServer(memoryStore().store);
    servers.push(srv);
    for (const bad of [0, 70000, Number.NaN]) {
      const st = await srv.start(bad);
      expect(st.running).toBe(false);
      expect(st.error).toMatch(/Geçersiz port/);
    }
  });

  it("gövde maxBodyBytes'tan büyükse bellekte sınırlı tutulur", async () => {
    const { recorded, port } = await started({ maxBody: 1000 });
    await send(port, "POST", "/hook/abc", Buffer.alloc(200_000, "a"));
    expect(recorded[0].body.length).toBe(1001);
  });

  it("kayıt hatası 500 döner, sunucu çalışmaya devam eder", async () => {
    const { srv, port } = await started({ failRecord: true });
    const res = await send(port, "POST", "/hook/abc", "x");
    expect(res.status).toBe(500);
    expect(JSON.parse(res.body)).toMatchObject({ error: "internal_error", message: "disk dolu" });
    expect(srv.status().running).toBe(true);
  });

  it("durdurunca port serbest kalır", async () => {
    const { srv, port } = await started();
    srv.stop();
    expect(srv.status().running).toBe(false);
    await expect(send(port, "GET", "/")).rejects.toThrow();
  });
});
