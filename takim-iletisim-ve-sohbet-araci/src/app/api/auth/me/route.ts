import { NextResponse } from "next/server";
import { getSessionUser } from "@/lib/auth";
import { getWorkspaceForUser } from "@/lib/channels";
import { prisma } from "@/lib/prisma";

export async function GET() {
  const user = await getSessionUser();
  if (!user) return NextResponse.json({ user: null });
  const workspace = await getWorkspaceForUser(user.id);
  return NextResponse.json({
    user,
    workspace: workspace ? { id: workspace.id, name: workspace.name } : null,
  });
}

// Görünen adı değiştir
export async function PATCH(request: Request) {
  const user = await getSessionUser();
  if (!user) return NextResponse.json({ error: "Oturum gerekli" }, { status: 401 });
  const body = await request.json().catch(() => ({}));
  const name = String(body.name ?? "").trim();
  if (name.length < 2 || name.length > 40) {
    return NextResponse.json({ error: "Ad 2-40 karakter olmalı" }, { status: 400 });
  }
  const updated = await prisma.user.update({ where: { id: user.id }, data: { name } });
  return NextResponse.json({ user: { ...user, name: updated.name } });
}
