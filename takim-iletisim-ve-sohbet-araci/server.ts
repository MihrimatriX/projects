import { createServer } from "http";

async function main() {
  const next = (await import("next")).default;
  const { initSocket } = await import("./src/lib/socket-server");

  const dev = process.env.NODE_ENV !== "production";
  const hostname = process.env.HOSTNAME || "localhost";
  const port = parseInt(process.env.PORT || "3106", 10);

  const app = next({ dev, hostname, port });
  const handle = app.getRequestHandler();

  await app.prepare();

  const server = createServer((req, res) => handle(req, res));

  await initSocket(server);

  // LISTEN_HOST verilmezse tüm arayüzler dinlenir (Docker); masaüstü kabuğu 127.0.0.1 verir
  server.listen(port, process.env.LISTEN_HOST || undefined, () => {
    console.log(`> Takım Sohbet hazır: http://${hostname}:${port}`);
  });
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
