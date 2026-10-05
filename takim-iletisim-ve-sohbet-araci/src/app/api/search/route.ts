import { NextResponse } from "next/server";
import { requireUser } from "@/lib/auth";
import { getWorkspaceForUser } from "@/lib/channels";
import { searchMessages } from "@/lib/search";
import { prisma } from "@/lib/prisma";

export async function GET(request: Request) {
  try {
    const user = await requireUser();
    const { searchParams } = new URL(request.url);
    const q = String(searchParams.get("q") ?? "").trim();
    if (q.length < 2) {
      return NextResponse.json({ results: [] });
    }

    const workspace = await getWorkspaceForUser(user.id);
    if (!workspace) return NextResponse.json({ results: [] });

    const memberChannelIds = await prisma.channelMember.findMany({
      where: { userId: user.id },
      select: { channelId: true },
    });
    const channelIds = memberChannelIds.map((m) => m.channelId);

    const messages = await searchMessages(channelIds, q);

    return NextResponse.json({
      results: messages.map((m) => ({
        id: m.id,
        content: m.content,
        createdAt: m.createdAt.toISOString(),
        author: m.author,
        channel: m.channel,
      })),
    });
  } catch {
    return NextResponse.json({ error: "Oturum gerekli" }, { status: 401 });
  }
}
