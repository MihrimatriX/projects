import { NextResponse } from "next/server";
import { prisma } from "@/lib/prisma";

export async function GET() {
  return NextResponse.json({
    appUrl: process.env.NEXT_PUBLIC_APP_URL ?? "http://localhost:3107",
  });
}

export async function DELETE() {
  await prisma.highlight.deleteMany();
  await prisma.clipTag.deleteMany();
  await prisma.clip.deleteMany();
  await prisma.tag.deleteMany();
  await prisma.feed.deleteMany();
  return NextResponse.json({ ok: true });
}
