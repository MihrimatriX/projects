import { NextResponse } from "next/server";
import { requireUser } from "@/lib/auth";
import {
  getMessagesForChannel,
  markChannelRead,
} from "@/lib/channels";
import { createChannelMessage } from "@/lib/messages";
import { prisma } from "@/lib/prisma";
import { emitReadReceipt } from "@/lib/socket-server";

type RouteContext = { params: Promise<{ channelId: string }> };

export async function GET(request: Request, context: RouteContext) {
  try {
    const user = await requireUser();
    const { channelId } = await context.params;
    const { searchParams } = new URL(request.url);
    const cursor = searchParams.get("cursor") ?? undefined;
    const parentId = searchParams.get("parentId");

    const member = await prisma.channelMember.findUnique({
      where: { channelId_userId: { channelId, userId: user.id } },
    });
    if (!member) {
      return NextResponse.json({ error: "Erişim yok" }, { status: 403 });
    }

    const result = await getMessagesForChannel(
      channelId,
      user.id,
      cursor,
      parentId === "null" || !parentId ? null : parentId,
    );
    return NextResponse.json(result);
  } catch {
    return NextResponse.json({ error: "Oturum gerekli" }, { status: 401 });
  }
}

export async function POST(request: Request, context: RouteContext) {
  try {
    const user = await requireUser();
    const { channelId } = await context.params;
    const body = await request.json();
    const content = String(body.content ?? "").trim();
    const parentId = body.parentId ? String(body.parentId) : null;

    const message = await createChannelMessage(
      channelId,
      user.id,
      content,
      parentId,
    );

    return NextResponse.json({ message }, { status: 201 });
  } catch (err) {
    const message = err instanceof Error ? err.message : "Mesaj gönderilemedi";
    const status = message === "Erişim yok" ? 403 : message.includes("Oturum") ? 401 : 400;
    return NextResponse.json({ error: message }, { status });
  }
}

export async function PATCH(_request: Request, context: RouteContext) {
  try {
    const user = await requireUser();
    const { channelId } = await context.params;
    await markChannelRead(channelId, user.id);
    emitReadReceipt(channelId, user.id);
    return NextResponse.json({ ok: true });
  } catch {
    return NextResponse.json({ error: "Oturum gerekli" }, { status: 401 });
  }
}
