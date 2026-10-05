import type { Server as HttpServer } from "http";
import { Server } from "socket.io";
import { parseCookie } from "cookie";
import { prisma } from "@/lib/prisma";
import { getSessionUserFromId } from "@/lib/auth-core";
import { REDIS_URL, SESSION_COOKIE } from "@/lib/config";
import type { SocketMessage } from "@/types";

// server.ts ile Next route'ları bu modülün ayrı kopyalarını yükler; modül değişkeni route'larda hep null
// kalıyordu ve anlık mesajlar diğer kullanıcılara ulaşmıyordu. Tek örnek globalThis üzerinden paylaşılır.
const shared = globalThis as unknown as { __sohbetIO?: Server };

export function getIO(): Server | null {
  return shared.__sohbetIO ?? null;
}

async function attachRedisAdapter(server: Server) {
  if (!REDIS_URL) return;
  try {
    const { createAdapter } = await import("@socket.io/redis-adapter");
    const { createClient } = await import("redis");
    const pub = createClient({ url: REDIS_URL });
    const sub = pub.duplicate();
    await Promise.all([pub.connect(), sub.connect()]);
    server.adapter(createAdapter(pub, sub));
    console.log("> Socket.IO Redis adapter aktif");
  } catch (err) {
    console.warn("> Redis adapter başlatılamadı, tek instance modu:", err);
  }
}

export async function initSocket(httpServer: HttpServer) {
  const io = new Server(httpServer, {
    path: "/api/socket",
    cors: { origin: process.env.NEXT_PUBLIC_APP_URL || "*", credentials: true },
  });

  shared.__sohbetIO = io;
  await attachRedisAdapter(io);

  // El sıkışmada httpOnly oturum çerezi okunur; geçerli oturum yoksa bağlantı reddedilir
  io.use(async (socket, next) => {
    try {
      const raw = socket.request.headers.cookie ?? "";
      const cookies = parseCookie(raw);
      const sessionId = cookies[SESSION_COOKIE];
      if (!sessionId) return next(new Error("Oturum gerekli"));
      const user = await getSessionUserFromId(sessionId);
      if (!user) return next(new Error("Geçersiz oturum"));
      socket.data.user = user;
      next();
    } catch {
      next(new Error("Kimlik doğrulama hatası"));
    }
  });

  io.on("connection", (socket) => {
    const user = socket.data.user as { id: string; name: string };

    socket.join(`user:${user.id}`);
    // Üyesi olunan tüm kanal odalarına katılır: aktif olmayan kanal/DM mesajları da gelir
    // (okunmamış rozeti ve yeni DM anlık görünür). Sonradan açılan kanallar joinUsersToChannel ile eklenir.
    prisma.channelMember
      .findMany({ where: { userId: user.id }, select: { channelId: true } })
      .then((rows) => socket.join(rows.map((r) => `channel:${r.channelId}`)))
      .catch(() => {});
    prisma.user
      .update({
        where: { id: user.id },
        data: { status: "ONLINE", lastSeenAt: new Date() },
      })
      .then(() =>
        io.emit("presence:update", { userId: user.id, status: "ONLINE" }),
      )
      .catch(() => {});

    // Mesajlar "channel:<id>" odasına yayınlanır; odaya yalnızca kanal üyesi katılabilir
    socket.on("channel:join", async (channelId: string) => {
      const member = await prisma.channelMember.findUnique({
        where: { channelId_userId: { channelId, userId: user.id } },
      });
      if (member) socket.join(`channel:${channelId}`);
    });

    socket.on("channel:leave", (channelId: string) => {
      socket.leave(`channel:${channelId}`);
    });

    socket.on("typing:start", (channelId: string) => {
      socket.to(`channel:${channelId}`).emit("typing:start", {
        channelId,
        userId: user.id,
        userName: user.name,
      });
    });

    socket.on("typing:stop", (channelId: string) => {
      socket.to(`channel:${channelId}`).emit("typing:stop", {
        channelId,
        userId: user.id,
        userName: user.name,
      });
    });

    socket.on("disconnect", async () => {
      // Hesap silindiyse update hata verir; yakalanmazsa işlenmemiş reddetme tüm sunucuyu düşürür
      try {
        await prisma.user.update({
          where: { id: user.id },
          data: { status: "OFFLINE", lastSeenAt: new Date() },
        });
      } catch {
        return;
      }
      io.emit("presence:update", { userId: user.id, status: "OFFLINE" });
    });
  });

  return io;
}

// Yeni kanal/DM oluşunca üyelerin açık soketleri odaya alınır ve kenar çubukları yenilenir
export function joinUsersToChannel(userIds: string[], channelId: string) {
  const io = getIO();
  if (!io || userIds.length === 0) return;
  const rooms = userIds.map((id) => `user:${id}`);
  io.in(rooms).socketsJoin(`channel:${channelId}`);
  io.to(rooms).emit("channels:changed");
}

export function emitNewMessage(message: SocketMessage) {
  getIO()?.to(`channel:${message.channelId}`).emit("message:new", message);
}

export function emitReadReceipt(channelId: string, userId: string) {
  getIO()?.to(`channel:${channelId}`).emit("message:read", { channelId, userId });
}
