import net from "net";

export type FakeSmtp = { port: number; mails: string[]; close: () => Promise<void> };

/** Ağa çıkmadan test için minimal SMTP sunucusu (AUTH PLAIN, STARTTLS yok). */
export function startFakeSmtp(user: string, pass: string): Promise<FakeSmtp> {
  const mails: string[] = [];
  const sockets = new Set<net.Socket>();
  const server = net.createServer((sock) => {
    sockets.add(sock);
    sock.on("close", () => sockets.delete(sock));
    let buf = "";
    let inData = false;
    let data = "";
    let authed = false;
    let awaitingPlain = false;
    const checkPlain = (token: string) => {
      const [, u, p] = Buffer.from(token, "base64").toString("utf8").split("\0");
      authed = u === user && p === pass;
      sock.write(authed ? "235 2.7.0 OK\r\n" : "535 5.7.8 Kimlik dogrulama basarisiz\r\n");
    };
    sock.write("220 fake ESMTP\r\n");
    sock.on("error", () => {});
    sock.on("data", (chunk) => {
      buf += chunk.toString("utf8");
      let idx: number;
      while ((idx = buf.indexOf("\r\n")) >= 0) {
        const line = buf.slice(0, idx);
        buf = buf.slice(idx + 2);
        if (inData) {
          if (line === ".") {
            inData = false;
            mails.push(data);
            data = "";
            sock.write("250 2.0.0 OK queued\r\n");
          } else data += (line.startsWith("..") ? line.slice(1) : line) + "\r\n";
          continue;
        }
        if (awaitingPlain) {
          awaitingPlain = false;
          checkPlain(line.trim());
          continue;
        }
        const cmd = line.toUpperCase();
        if (cmd.startsWith("EHLO")) sock.write("250-fake\r\n250-AUTH PLAIN\r\n250 8BITMIME\r\n");
        else if (cmd.startsWith("HELO")) sock.write("250 fake\r\n");
        else if (cmd.startsWith("AUTH PLAIN")) {
          const token = line.slice("AUTH PLAIN".length).trim();
          if (token) checkPlain(token);
          else {
            awaitingPlain = true;
            sock.write("334 \r\n");
          }
        } else if (cmd.startsWith("MAIL FROM")) sock.write(authed ? "250 OK\r\n" : "530 5.7.0 Authentication required\r\n");
        else if (cmd.startsWith("RCPT TO")) sock.write("250 OK\r\n");
        else if (cmd === "DATA") {
          inData = true;
          sock.write("354 End data with <CR><LF>.<CR><LF>\r\n");
        } else if (cmd === "QUIT") {
          sock.write("221 Bye\r\n");
          sock.end();
        } else if (cmd === "RSET" || cmd === "NOOP") sock.write("250 OK\r\n");
        else sock.write("502 Command not implemented\r\n");
      }
    });
  });
  return new Promise((resolve) => {
    server.listen(0, "127.0.0.1", () => {
      const port = (server.address() as net.AddressInfo).port;
      resolve({
        port,
        mails,
        close: () =>
          new Promise<void>((r) => {
            server.close(() => r());
            for (const s of sockets) s.destroy();
          }),
      });
    });
  });
}
