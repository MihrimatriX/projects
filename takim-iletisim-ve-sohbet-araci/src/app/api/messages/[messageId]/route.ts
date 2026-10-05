import { NextResponse } from "next/server";
import { requireUser } from "@/lib/auth";
import { assertChannelAccess } from "@/lib/channels";
import { prisma } from "@/lib/prisma";
import { editChannelMessage } from "@/lib/messages";
import { getIO } from "@/lib/socket-server";

type RouteContext = { params: Promise<{ messageId: string }> };

export async function DELETE(_request: Request, context: RouteContext) {
  try {
    const user = await requireUser();
    const { messageId } = await context.params;

    const message = await prisma.message.findUnique({ where: { id: messageId } });
    if (!message) {
      return NextResponse.json({ error: "Mesaj bulunamadı" }, { status: 404 });
    }
    if (message.authorId !== user.id) {
      return NextResponse.json({ error: "Sadece kendi mesajınızı silebilirsiniz" }, { status: 403 });
    }

    await assertChannelAccess(message.channelId, user.id);
    await prisma.message.delete({ where: { id: messageId } });

    getIO()?.to(`channel:${message.channelId}`).emit("message:delete", {
      messageId,
      channelId: message.channelId,
      parentId: message.parentId,
    });

    return NextResponse.json({ ok: true });
  } catch (err) {
    const msg = err instanceof Error ? err.message : "Silinemedi";
    return NextResponse.json({ error: msg }, { status: 400 });
  }
}

export async function PATCH(request: Request, context: RouteContext) {
  try {
    const user = await requireUser();
    const { messageId } = await context.params;
    const body = await request.json();
    const message = await editChannelMessage(messageId, user.id, String(body.content ?? ""));
    return NextResponse.json({ message });
  } catch (err) {
    const msg = err instanceof Error ? err.message : "Düzenlenemedi";
    const status = msg.includes("Oturum")
      ? 401
      : msg.includes("bulunamadı")
        ? 404
        : msg.includes("Sadece") || msg === "Erişim yok"
          ? 403
          : 400;
    return NextResponse.json({ error: msg }, { status });
  }
}
