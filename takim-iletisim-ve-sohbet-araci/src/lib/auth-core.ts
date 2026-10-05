import { randomBytes, scryptSync, timingSafeEqual } from "crypto";
import { prisma } from "@/lib/prisma";
import { SESSION_SECRET } from "@/lib/config";
import type { AuthUser } from "@/types";

function hashPassword(password: string): string {
  const salt = randomBytes(16).toString("hex");
  const hash = scryptSync(password, salt + SESSION_SECRET, 64).toString("hex");
  return `${salt}:${hash}`;
}

function verifyPassword(password: string, stored: string): boolean {
  const [salt, hash] = stored.split(":");
  if (!salt || !hash) return false;
  const derived = scryptSync(password, salt + SESSION_SECRET, 64);
  const expected = Buffer.from(hash, "hex");
  if (expected.length !== derived.length) return false;
  return timingSafeEqual(expected, derived);
}

export async function registerUser(
  email: string,
  name: string,
  password: string,
) {
  const normalizedEmail = email.trim().toLowerCase();
  const existing = await prisma.user.findUnique({
    where: { email: normalizedEmail },
  });
  if (existing) throw new Error("Bu e-posta zaten kayıtlı");

  const user = await prisma.user.create({
    data: {
      email: normalizedEmail,
      name: name.trim(),
      passwordHash: hashPassword(password),
    },
  });

  let workspace = await prisma.workspace.findFirst();
  if (!workspace) {
    workspace = await prisma.workspace.create({
      data: { name: "Acme Takım", slug: "acme" },
    });
    for (const ch of ["genel", "geliştirme", "tasarım"]) {
      const channel = await prisma.channel.create({
        data: {
          workspaceId: workspace.id,
          name: ch,
          type: "PUBLIC",
        },
      });
      await prisma.channelMember.create({
        data: { channelId: channel.id, userId: user.id },
      });
    }
  }

  await prisma.workspaceMember.create({
    data: { workspaceId: workspace.id, userId: user.id },
  });

  const channels = await prisma.channel.findMany({
    where: { workspaceId: workspace.id, type: "PUBLIC" },
  });
  for (const ch of channels) {
    const member = await prisma.channelMember.findUnique({
      where: { channelId_userId: { channelId: ch.id, userId: user.id } },
    });
    if (!member) {
      await prisma.channelMember.create({
        data: { channelId: ch.id, userId: user.id },
      });
    }
  }

  return user;
}

export async function loginUser(email: string, password: string) {
  const normalizedEmail = email.trim().toLowerCase();
  const user = await prisma.user.findUnique({
    where: { email: normalizedEmail },
  });
  if (!user || !verifyPassword(password, user.passwordHash)) {
    throw new Error("Geçersiz e-posta veya şifre");
  }
  return user;
}

export async function createSessionRecord(userId: string, days = 30) {
  const expiresAt = new Date();
  expiresAt.setDate(expiresAt.getDate() + days);
  const session = await prisma.session.create({
    data: { userId, expiresAt },
  });
  await prisma.user.update({
    where: { id: userId },
    data: { status: "ONLINE", lastSeenAt: new Date() },
  });
  return session;
}

export async function deleteSessionRecord(sessionId: string) {
  const session = await prisma.session.findUnique({ where: { id: sessionId } });
  if (session) {
    await prisma.session.delete({ where: { id: sessionId } });
    await prisma.user.update({
      where: { id: session.userId },
      data: { status: "OFFLINE", lastSeenAt: new Date() },
    });
  }
}

export async function getSessionUserFromId(
  sessionId: string,
): Promise<AuthUser | null> {
  const session = await prisma.session.findUnique({
    where: { id: sessionId },
    include: { user: true },
  });
  if (!session || session.expiresAt < new Date()) return null;
  return {
    id: session.user.id,
    email: session.user.email,
    name: session.user.name,
    status: session.user.status,
  };
}

export async function requireUserFromSession(
  sessionId: string | undefined,
): Promise<AuthUser> {
  if (!sessionId) throw new Error("Oturum gerekli");
  const user = await getSessionUserFromId(sessionId);
  if (!user) throw new Error("Oturum gerekli");
  return user;
}
