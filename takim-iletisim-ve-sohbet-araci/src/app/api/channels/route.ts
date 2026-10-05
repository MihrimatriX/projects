import { NextResponse } from "next/server";
import { requireUser } from "@/lib/auth";
import { getChannelsForUser, getWorkspaceForUser } from "@/lib/channels";
import { prisma } from "@/lib/prisma";
import { joinUsersToChannel } from "@/lib/socket-server";

export async function GET() {
  try {
    const user = await requireUser();
    const channels = await getChannelsForUser(user.id);
    return NextResponse.json({ channels });
  } catch {
    return NextResponse.json({ error: "Oturum gerekli" }, { status: 401 });
  }
}

export async function POST(request: Request) {
  try {
    const user = await requireUser();
    const body = await request.json();
    const name = String(body.name ?? "")
      .trim()
      .toLowerCase()
      .replace(/\s+/g, "-");
    if (!name || name.length < 2) {
      return NextResponse.json({ error: "Geçerli kanal adı gerekli" }, { status: 400 });
    }

    const workspace = await getWorkspaceForUser(user.id);
    if (!workspace) {
      return NextResponse.json({ error: "Workspace bulunamadı" }, { status: 404 });
    }

    const existing = await prisma.channel.findUnique({
      where: { workspaceId_name: { workspaceId: workspace.id, name } },
    });
    if (existing) {
      return NextResponse.json({ error: "Kanal zaten var" }, { status: 409 });
    }

    const wsMembers = await prisma.workspaceMember.findMany({
      where: { workspaceId: workspace.id },
      select: { userId: true },
    });

    const channel = await prisma.channel.create({
      data: {
        workspaceId: workspace.id,
        name,
        type: "PUBLIC",
        members: {
          create: wsMembers.map((m) => ({ userId: m.userId })),
        },
      },
    });

    joinUsersToChannel(wsMembers.map((m) => m.userId), channel.id);

    return NextResponse.json(
      { channel: { id: channel.id, name: channel.name, type: channel.type } },
      { status: 201 },
    );
  } catch {
    return NextResponse.json({ error: "Oturum gerekli" }, { status: 401 });
  }
}
