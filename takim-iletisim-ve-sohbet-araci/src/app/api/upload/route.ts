import { randomUUID } from "crypto";
import { NextResponse } from "next/server";
import { requireUser } from "@/lib/auth";
import { assertChannelAccess } from "@/lib/channels";
import { buildMessageItem } from "@/lib/export";
import { isAllowedMime, stripDangerousContent } from "@/lib/markdown";
import { MAX_UPLOAD_BYTES } from "@/lib/config";
import { emitNewMessage } from "@/lib/socket-server";
import { defaultStorageBackend, saveFile } from "@/lib/storage";
import { prisma } from "@/lib/prisma";

export async function POST(request: Request) {
  try {
    const user = await requireUser();
    const form = await request.formData();
    const channelId = String(form.get("channelId") ?? "");
    const content = stripDangerousContent(String(form.get("content") ?? ""));
    const file = form.get("file") as File | null;

    if (!channelId) {
      return NextResponse.json({ error: "channelId gerekli" }, { status: 400 });
    }
    if (!file?.size) {
      return NextResponse.json({ error: "Dosya gerekli" }, { status: 400 });
    }

    await assertChannelAccess(channelId, user.id);

    if (file.size > MAX_UPLOAD_BYTES) {
      return NextResponse.json(
        { error: `Dosya en fazla ${MAX_UPLOAD_BYTES / 1024 / 1024} MB olabilir` },
        { status: 413 },
      );
    }
    if (!isAllowedMime(file.type)) {
      return NextResponse.json({ error: "Dosya türü desteklenmiyor" }, { status: 415 });
    }

    const ext = file.name.includes(".") ? file.name.slice(file.name.lastIndexOf(".")) : "";
    const key = `${randomUUID()}${ext}`;
    const buffer = Buffer.from(await file.arrayBuffer());
    const backend = defaultStorageBackend();
    const stored = await saveFile(buffer, key, file.type || "application/octet-stream", backend);

    const text = content || `📎 ${file.name}`;
    const message = await prisma.message.create({
      data: {
        channelId,
        authorId: user.id,
        content: text,
        attachments: {
          create: {
            fileName: file.name,
            filePath: stored.key,
            storage: stored.backend,
            mimeType: file.type || "application/octet-stream",
            size: file.size,
          },
        },
      },
      include: {
        author: { select: { id: true, name: true, email: true } },
        attachments: {
          select: { id: true, fileName: true, mimeType: true, size: true },
        },
        _count: { select: { replies: true } },
      },
    });

    const lastReads = await prisma.channelMember.findMany({
      where: { channelId, userId: { not: user.id } },
      select: { lastReadAt: true },
    });
    const item = await buildMessageItem(
      message,
      user.id,
      lastReads.map((m) => m.lastReadAt),
    );
    emitNewMessage({ ...item, channelId });

    return NextResponse.json({ message: item }, { status: 201 });
  } catch (err) {
    const msg = err instanceof Error ? err.message : "Yükleme başarısız";
    return NextResponse.json({ error: msg }, { status: 401 });
  }
}
