import { NextResponse } from "next/server";
import { prisma } from "@/lib/prisma";

export async function GET() {
  const [all, unread, starred] = await Promise.all([
    prisma.clip.count(),
    prisma.clip.count({ where: { isRead: false } }),
    prisma.clip.count({ where: { isStarred: true } }),
  ]);
  return NextResponse.json({ all, unread, starred });
}
