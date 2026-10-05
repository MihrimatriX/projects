import { NextResponse } from "next/server";
import { requireUser } from "@/lib/auth";
import { loadFile } from "@/lib/storage";
import type { StorageBackend } from "@/lib/storage";
import { prisma } from "@/lib/prisma";

type RouteContext = { params: Promise<{ id: string }> };

export async function GET(_request: Request, context: RouteContext) {
  try {
    const user = await requireUser();
    const { id } = await context.params;

    const attachment = await prisma.attachment.findUnique({
      where: { id },
      include: { message: true },
    });
    if (!attachment) {
      return NextResponse.json({ error: "Dosya bulunamadı" }, { status: 404 });
    }

    const member = await prisma.channelMember.findUnique({
      where: {
        channelId_userId: {
          channelId: attachment.message.channelId,
          userId: user.id,
        },
      },
    });
    if (!member) {
      return NextResponse.json({ error: "Erişim yok" }, { status: 403 });
    }

    const data = await loadFile(
      attachment.filePath,
      attachment.storage as StorageBackend,
    );

    return new NextResponse(new Uint8Array(data), {
      headers: {
        "Content-Type": attachment.mimeType,
        // Yalnızca görseller tarayıcıda açılır (yüklenen HTML/SVG aynı origin'de script çalıştıramaz);
        // dosya adı RFC 5987 ile kodlanır, aksi halde ASCII dışı karakterler başlıkta hata verir
        "Content-Disposition": `${/^image\/(png|jpe?g|gif|webp)$/.test(attachment.mimeType) ? "inline" : "attachment"}; filename*=UTF-8''${encodeURIComponent(attachment.fileName)}`,
        "Content-Length": String(attachment.size),
      },
    });
  } catch {
    return NextResponse.json({ error: "Oturum gerekli" }, { status: 401 });
  }
}
