import { NextResponse } from "next/server";
import { postWebhookMessage } from "@/lib/messages";

type RouteContext = { params: Promise<{ token: string }> };

export async function POST(request: Request, context: RouteContext) {
  try {
    const { token } = await context.params;
    const body = await request.json();
    const text = String(body.text ?? body.content ?? body.message ?? "").trim();
    const sender = body.sender ? String(body.sender) : undefined;

    if (!text) {
      return NextResponse.json({ error: "text alanı gerekli" }, { status: 400 });
    }

    const message = await postWebhookMessage(token, text, sender);
    return NextResponse.json({ ok: true, messageId: message.id }, { status: 201 });
  } catch (err) {
    const msg = err instanceof Error ? err.message : "Webhook hatası";
    const status = msg.includes("Geçersiz") ? 404 : 400;
    return NextResponse.json({ error: msg }, { status });
  }
}
