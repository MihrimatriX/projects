import { NextResponse } from "next/server";
import { requireUser } from "@/lib/auth";
import { getWorkspaceForUser } from "@/lib/channels";
import { prisma } from "@/lib/prisma";

export async function GET() {
  try {
    const user = await requireUser();
    const workspace = await getWorkspaceForUser(user.id);
    if (!workspace) return NextResponse.json({ members: [] });

    const members = await prisma.workspaceMember.findMany({
      where: { workspaceId: workspace.id, userId: { not: user.id } },
      include: {
        user: { select: { id: true, name: true, email: true, status: true } },
      },
      orderBy: { user: { name: "asc" } },
    });

    return NextResponse.json({
      members: members.map((m) => m.user),
    });
  } catch {
    return NextResponse.json({ error: "Oturum gerekli" }, { status: 401 });
  }
}
