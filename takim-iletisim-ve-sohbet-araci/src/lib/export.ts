import { prisma } from "@/lib/prisma";
import type { MessageItem } from "@/types";

export async function buildMessageItem(
  msg: {
    id: string;
    content: string;
    createdAt: Date;
    authorId: string;
    parentId: string | null;
    author: { id: string; name: string; email: string };
    attachments: {
      id: string;
      fileName: string;
      mimeType: string;
      size: number;
    }[];
    editedAt?: Date | null;
    _count?: { replies: number };
  },
  userId: string,
  otherMembersLastRead: Date[],
): Promise<MessageItem> {
  return {
    id: msg.id,
    content: msg.content,
    createdAt: msg.createdAt.toISOString(),
    editedAt: msg.editedAt ? msg.editedAt.toISOString() : null,
    author: msg.author,
    attachments: msg.attachments,
    parentId: msg.parentId,
    replyCount: msg._count?.replies ?? 0,
    readByOthers:
      msg.authorId === userId
        ? otherMembersLastRead.some((t) => t >= msg.createdAt)
        : true,
  };
}

export async function exportUserData(userId: string) {
  const user = await prisma.user.findUnique({
    where: { id: userId },
    select: { id: true, email: true, name: true, createdAt: true },
  });
  if (!user) throw new Error("Kullanıcı bulunamadı");

  const messages = await prisma.message.findMany({
    where: { authorId: userId },
    orderBy: { createdAt: "asc" },
    include: {
      channel: { select: { name: true, type: true } },
      attachments: {
        select: { fileName: true, mimeType: true, size: true, createdAt: true },
      },
    },
  });

  return {
    exportedAt: new Date().toISOString(),
    format: "kvkk-export-v1",
    user,
    messageCount: messages.length,
    messages: messages.map((m) => ({
      id: m.id,
      channel: m.channel.name,
      channelType: m.channel.type,
      content: m.content,
      createdAt: m.createdAt.toISOString(),
      attachments: m.attachments,
    })),
  };
}

export async function deleteUserAccount(userId: string) {
  await prisma.user.delete({ where: { id: userId } });
}
