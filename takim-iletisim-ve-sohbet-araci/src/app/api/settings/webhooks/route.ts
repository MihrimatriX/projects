import { NextResponse } from "next/server";
import { requireUser } from "@/lib/auth";
import { getWorkspaceForUser } from "@/lib/channels";
import { generateWebhookToken } from "@/lib/messages";
import { prisma } from "@/lib/prisma";

export async function GET() {
  try {
    const user = await requireUser();
    const workspace = await getWorkspaceForUser(user.id);
    if (!workspace) return NextResponse.json({ webhooks: [] });

    const webhooks = await prisma.webhook.findMany({
      where: { workspaceId: workspace.id },
      include: { channel: { select: { name: true } } },
      orderBy: { createdAt: "desc" },
    });

    const baseUrl = process.env.NEXT_PUBLIC_APP_URL || "http://localhost:3106";
    return NextResponse.json({
      webhooks: webhooks.map((w) => ({
        id: w.id,
        name: w.name,
        channelId: w.channelId,
        channelName: w.channel.name,
        token: w.token,
        url: `${baseUrl}/api/webhooks/${w.token}`,
        createdAt: w.createdAt.toISOString(),
      })),
    });
  } catch {
    return NextResponse.json({ error: "Oturum gerekli" }, { status: 401 });
  }
}

export async function POST(request: Request) {
  try {
    const user = await requireUser();
    const workspace = await getWorkspaceForUser(user.id);
    if (!workspace) {
      return NextResponse.json({ error: "Workspace yok" }, { status: 404 });
    }

    const body = await request.json();
    const name = String(body.name ?? "").trim();
    const channelId = String(body.channelId ?? "");
    if (!name || !channelId) {
      return NextResponse.json(
        { error: "name ve channelId gerekli" },
        { status: 400 },
      );
    }

    const member = await prisma.channelMember.findUnique({
      where: { channelId_userId: { channelId, userId: user.id } },
    });
    if (!member) {
      return NextResponse.json({ error: "Kanal erişimi yok" }, { status: 403 });
    }

    const webhook = await prisma.webhook.create({
      data: {
        workspaceId: workspace.id,
        channelId,
        createdById: user.id,
        name,
        token: generateWebhookToken(),
      },
      include: { channel: { select: { name: true } } },
    });

    const baseUrl = process.env.NEXT_PUBLIC_APP_URL || "http://localhost:3106";
    return NextResponse.json(
      {
        webhook: {
          id: webhook.id,
          name: webhook.name,
          channelId: webhook.channelId,
          channelName: webhook.channel.name,
          token: webhook.token,
          url: `${baseUrl}/api/webhooks/${webhook.token}`,
          createdAt: webhook.createdAt.toISOString(),
        },
      },
      { status: 201 },
    );
  } catch {
    return NextResponse.json({ error: "Oluşturulamadı" }, { status: 401 });
  }
}

export async function DELETE(request: Request) {
  try {
    const user = await requireUser();
    const { searchParams } = new URL(request.url);
    const id = searchParams.get("id");
    if (!id) {
      return NextResponse.json({ error: "id gerekli" }, { status: 400 });
    }

    const webhook = await prisma.webhook.findUnique({ where: { id } });
    if (!webhook || webhook.createdById !== user.id) {
      return NextResponse.json({ error: "Bulunamadı" }, { status: 404 });
    }

    await prisma.webhook.delete({ where: { id } });
    return NextResponse.json({ ok: true });
  } catch {
    return NextResponse.json({ error: "Silinemedi" }, { status: 401 });
  }
}
