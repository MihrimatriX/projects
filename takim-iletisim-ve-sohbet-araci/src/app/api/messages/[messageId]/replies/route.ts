import { NextResponse } from "next/server";
import { requireUser } from "@/lib/auth";
import { getMessagesForChannel } from "@/lib/channels";
import { prisma } from "@/lib/prisma";

type RouteContext = { params: Promise<{ messageId: string }> };

export async function GET(_request: Request, context: RouteContext) {
  try {
    const user = await requireUser();
    const { messageId } = await context.params;

    const parentMsg = await prisma.message.findUnique({
      where: { id: messageId },
      include: {
        author: { select: { id: true, name: true, email: true } },
        attachments: {
          select: { id: true, fileName: true, mimeType: true, size: true },
        },
        _count: { select: { replies: true } },
      },
    });
    if (!parentMsg) {
      return NextResponse.json({ error: "Mesaj bulunamadı" }, { status: 404 });
    }

    await prisma.channelMember.findUniqueOrThrow({
      where: {
        channelId_userId: { channelId: parentMsg.channelId, userId: user.id },
      },
    });

    const lastReads = await prisma.channelMember.findMany({
      where: { channelId: parentMsg.channelId, userId: { not: user.id } },
      select: { lastReadAt: true },
    });

    const { buildMessageItem } = await import("@/lib/export");
    const parent = await buildMessageItem(
      parentMsg,
      user.id,
      lastReads.map((m) => m.lastReadAt),
    );

    const result = await getMessagesForChannel(
      parentMsg.channelId,
      user.id,
      undefined,
      messageId,
    );

    return NextResponse.json({ parent, replies: result.messages });
  } catch {
    return NextResponse.json({ error: "Erişim yok" }, { status: 403 });
  }
}
