// Testler icin yerel feed sunucusu: tests/fixtures/*.xml dosyalarini sunar, internete ihtiyac duymaz.
// /hata.xml -> 500, /bozuk.xml -> RSS olmayan icerik. Kullanim: node tests/fixtures/serve.mjs <port>
import http from "node:http";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const dir = path.dirname(fileURLToPath(import.meta.url));

/**
 * @param {http.Server} server
 * @param {number} [port]
 * @returns {Promise<http.Server>}
 */
export function listen(server, port = 0) {
  return new Promise((resolve) => server.listen(port, "127.0.0.1", () => resolve(server)));
}

/**
 * @param {number} [port]
 * @returns {Promise<http.Server>}
 */
export function startFixtureServer(port = 0) {
  const server = http.createServer((req, res) => {
    const name = path.basename(new URL(req.url ?? "/", "http://x").pathname);
    if (name === "hata.xml") {
      res.writeHead(500).end("sunucu hatasi");
      return;
    }
    if (name === "bozuk.xml") {
      res.writeHead(200, { "Content-Type": "text/html" }).end("<html><body>RSS degil</body></html>");
      return;
    }
    const file = path.join(dir, name);
    if (!name.endsWith(".xml") || !fs.existsSync(file)) {
      res.writeHead(404).end();
      return;
    }
    res.writeHead(200, { "Content-Type": "application/xml; charset=utf-8" });
    fs.createReadStream(file).pipe(res);
  });
  return listen(server, port);
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const server = await startFixtureServer(Number(process.argv[2] || 3214));
  const address = /** @type {import("node:net").AddressInfo} */ (server.address());
  console.log(`fikstur sunucusu: http://127.0.0.1:${address.port}/`);
}
