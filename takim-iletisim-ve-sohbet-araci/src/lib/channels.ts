import { buildMessageItem } from "@/lib/export";
import { prisma } from "@/lib/prisma";
import { joinUsersToChannel } from "@/lib/socket-server";
import type { ChannelSummary, MessageItem } from "@/types";

export async function getWorkspaceForUser(userId: string) {
  const membership = await prisma.workspaceMember.findFirst({
    where: { userId },
    include: { workspace: true },
  });
  return membership?.workspace ?? null;
}

export async function getChannelsForUser(
  userId: string,
): Promise<ChannelSummary[]> {
  const workspace = await getWorkspaceForUser(userId);
  if (!workspace) return [];

  const memberships = await prisma.channelMember.findMany({
    where: { userId, channel: { workspaceId: workspace.id } },
    include: {
      channel: {
        include: {
          members: {
            where: { userId: { not: userId } },
            include: { user: true },
            take: 1,
          },
        },
      },
    },
    orderBy: { channel: { createdAt: "asc" } },
  });

  const result: ChannelSummary[] = [];
  for (const m of memberships) {
    const unreadCount = await prisma.message.count({
      where: {
        channelId: m.channelId,
        createdAt: { gt: m.lastReadAt },
        authorId: { not: userId },
      },
    });

    const partner =
      m.channel.type === "DM" ? m.channel.members[0]?.user : undefined;

    result.push({
      id: m.channel.id,
      name: m.channel.name,
      type: m.channel.type,
      unreadCount,
      dmPartner: partner
        ? {
            id: partner.id,
            name: partner.name,
            status: partner.status,
          }
        : null,
    });
  }

  return result.sort((a, b) => {
    if (a.type !== b.type) return a.type === "PUBLIC" ? -1 : 1;
    return a.name.localeCompare(b.name, "tr");
  });
}

async function getOtherMembersLastRead(channelId: string, userId: string) {
  const otherMembers = await prisma.channelMember.findMany({
    where: { channelId, userId: { not: userId } },
    select: { lastReadAt: true },
  });
  return otherMembers.map((m) => m.lastReadAt);
}

export async function getMessagesForChannel(
  channelId: string,
  userId: string,
  cursor?: string,
  parentId?: string | null,
): Promise<{ messages: MessageItem[]; hasMore: boolean }> {
  const take = 50;
  const where = parentId
    ? { channelId, parentId }
    : { channelId, parentId: null };

  const messages = await prisma.message.findMany({
    where,
    orderBy: { createdAt: "desc" },
    take: take + 1,
    ...(cursor ? { cursor: { id: cursor }, skip: 1 } : {}),
    include: {
      author: { select: { id: true, name: true, email: true } },
      attachments: {
        select: { id: true, fileName: true, mimeType: true, size: true },
      },
      _count: { select: { replies: true } },
    },
  });

  const hasMore = messages.length > take;
  const slice = hasMore ? messages.slice(0, take) : messages;
  slice.reverse();

  const lastReads = await getOtherMembersLastRead(channelId, userId);
  const items = await Promise.all(
    slice.map((msg) => buildMessageItem(msg, userId, lastReads)),
  );

  return { messages: items, hasMore };
}

export async function findOrCreateDmChannel(
  workspaceId: string,
  userId: string,
  targetUserId: string,
) {
  if (userId === targetUserId) throw new Error("Kendinize DM açılamaz");

  const existing = await prisma.channel.findMany({
    where: { workspaceId, type: "DM" },
    include: { members: true },
  });

  for (const ch of existing) {
    const memberIds = ch.members.map((m) => m.userId).sort();
    const pair = [userId, targetUserId].sort();
    if (
      memberIds.length === 2 &&
      memberIds[0] === pair[0] &&
      memberIds[1] === pair[1]
    ) {
      return ch;
    }
  }

  const target = await prisma.user.findUnique({ where: { id: targetUserId } });
  if (!target) throw new Error("Kullanıcı bulunamadı");

  const channel = await prisma.channel.create({
    data: {
      workspaceId,
      name: `dm-${userId}-${targetUserId}`,
      type: "DM",
      members: {
        create: [{ userId }, { userId: targetUserId }],
      },
    },
  });
  joinUsersToChannel([userId, targetUserId], channel.id);

  return channel;
}

export async function markChannelRead(channelId: string, userId: string) {
  await prisma.channelMember.update({
    where: { channelId_userId: { channelId, userId } },
    data: { lastReadAt: new Date() },
  });
}

export async function assertChannelAccess(channelId: string, userId: string) {
  const member = await prisma.channelMember.findUnique({
    where: { channelId_userId: { channelId, userId } },
  });
  if (!member) throw new Error("Erişim yok");
  return member;
}
