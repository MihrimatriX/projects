import { NextResponse } from "next/server";
import { requireUser } from "@/lib/auth";
import { findOrCreateDmChannel, getWorkspaceForUser } from "@/lib/channels";

export async function POST(request: Request) {
  try {
    const user = await requireUser();
    const body = await request.json();
    const targetUserId = String(body.userId ?? "");
    if (!targetUserId) {
      return NextResponse.json({ error: "userId gerekli" }, { status: 400 });
    }

    const workspace = await getWorkspaceForUser(user.id);
    if (!workspace) {
      return NextResponse.json({ error: "Workspace bulunamadı" }, { status: 404 });
    }

    const channel = await findOrCreateDmChannel(
      workspace.id,
      user.id,
      targetUserId,
    );

    return NextResponse.json({
      channel: { id: channel.id, name: channel.name, type: "DM" },
    });
  } catch (err) {
    const message = err instanceof Error ? err.message : "DM oluşturulamadı";
    return NextResponse.json({ error: message }, { status: 400 });
  }
}
