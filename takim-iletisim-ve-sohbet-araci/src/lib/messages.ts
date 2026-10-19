import { stripDangerousContent } from "@/lib/markdown";
import { randomBytes } from "crypto";
import { prisma } from "@/lib/prisma";
import { buildMessageItem } from "@/lib/export";
import { assertChannelAccess } from "@/lib/channels";
import { emitNewMessage, getIO } from "@/lib/socket-server";
import type { MessageItem } from "@/types";

export async function createChannelMessage(
  channelId: string,
  authorId: string,
  rawContent: string,
  parentId?: string | null,
): Promise<MessageItem & { channelId: string }> {
  await assertChannelAccess(channelId, authorId);
  const content = stripDangerousContent(rawContent);
  if (!content) throw new Error("Mesaj boş olamaz");

  if (parentId) {
    const parent = await prisma.message.findUnique({ where: { id: parentId } });
    if (!parent || parent.channelId !== channelId) {
      throw new Error("Geçersiz konu başlığı");
    }
  }

  const message = await prisma.message.create({
    data: {
      channelId,
      authorId,
      content,
      parentId: parentId ?? null,
    },
    include: {
      author: { select: { id: true, name: true, email: true } },
      attachments: {
        select: { id: true, fileName: true, mimeType: true, size: true },
      },
      _count: { select: { replies: true } },
    },
  });

  const otherMembers = await prisma.channelMember.findMany({
    where: { channelId, userId: { not: authorId } },
    select: { lastReadAt: true },
  });

  const item = await buildMessageItem(
    message,
    authorId,
    otherMembers.map((m) => m.lastReadAt),
  );

  const payload = { ...item, channelId };
  emitNewMessage(payload);
  return payload;
}

export async function editChannelMessage(
  messageId: string,
  userId: string,
  rawContent: string,
) {
  const message = await prisma.message.findUnique({ where: { id: messageId } });
  if (!message) throw new Error("Mesaj bulunamadı");
  if (message.authorId !== userId) {
    throw new Error("Sadece kendi mesajınızı düzenleyebilirsiniz");
  }
  await assertChannelAccess(message.channelId, userId);
  const content = stripDangerousContent(rawContent);
  if (!content) throw new Error("Mesaj boş olamaz");

  const updated = await prisma.message.update({
    where: { id: messageId },
    data: { content, editedAt: new Date() },
  });
  const payload = {
    id: updated.id,
    channelId: updated.channelId,
    parentId: updated.parentId,
    content: updated.content,
    editedAt: updated.editedAt!.toISOString(),
  };
  getIO()?.to(`channel:${updated.channelId}`).emit("message:update", payload);
  return payload;
}

export function generateWebhookToken(): string {
  return randomBytes(24).toString("hex");
}

export async function postWebhookMessage(
  token: string,
  text: string,
  senderName?: string,
) {
  const webhook = await prisma.webhook.findUnique({
    where: { token },
    include: { channel: true },
  });
  if (!webhook) throw new Error("Geçersiz webhook");

  const content = stripDangerousContent(text);
  if (!content) throw new Error("Mesaj boş olamaz");

  const label = senderName?.trim() || webhook.name;
  const formatted = `**[${label}]** ${content}`;

  let systemUser = await prisma.user.findFirst({
    where: { email: "system@webhook.local" },
  });
  if (!systemUser) {
    systemUser = await prisma.user.create({
      data: {
        email: "system@webhook.local",
        name: "Sistem",
        passwordHash: "!",
      },
    });
    await prisma.workspaceMember.create({
      data: { workspaceId: webhook.workspaceId, userId: systemUser.id },
    });
  }
  // Her webhook farklı bir kanala bağlı olabilir; sistem kullanıcısı o kanala da üye olmalı
  await prisma.channelMember.upsert({
    where: { channelId_userId: { channelId: webhook.channelId, userId: systemUser.id } },
    update: {},
    create: { channelId: webhook.channelId, userId: systemUser.id },
  });

  return createChannelMessage(webhook.channelId, systemUser.id, formatted);
}
