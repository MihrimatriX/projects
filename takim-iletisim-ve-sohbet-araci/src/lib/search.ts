import { prisma } from "@/lib/prisma";

export async function searchMessages(
  channelIds: string[],
  query: string,
  limit = 30,
) {
  const terms = query
    .toLowerCase()
    .split(/\s+/)
    .filter((t) => t.length >= 2);

  if (terms.length === 0) {
    return prisma.message.findMany({
      where: {
        channelId: { in: channelIds },
        content: { contains: query },
      },
      orderBy: { createdAt: "desc" },
      take: limit,
      include: {
        author: { select: { id: true, name: true } },
        channel: { select: { id: true, name: true, type: true } },
      },
    });
  }

  const messages = await prisma.message.findMany({
    where: {
      channelId: { in: channelIds },
      AND: terms.map((term) => ({
        content: { contains: term },
      })),
    },
    orderBy: { createdAt: "desc" },
    take: limit * 2,
    include: {
      author: { select: { id: true, name: true } },
      channel: { select: { id: true, name: true, type: true } },
    },
  });

  return messages
    .map((m) => {
      const lower = m.content.toLowerCase();
      const score = terms.reduce(
        (s, t) => s + (lower.includes(t) ? 1 : 0),
        0,
      );
      return { m, score };
    })
    .sort((a, b) => b.score - a.score || b.m.createdAt.getTime() - a.m.createdAt.getTime())
    .slice(0, limit)
    .map(({ m }) => m);
}
