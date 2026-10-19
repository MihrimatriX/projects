import { NextResponse } from "next/server";
import { createSession, loginUser, registerUser } from "@/lib/auth";
import {
  RATE_LIMIT_LOGIN_MAX,
  RATE_LIMIT_LOGIN_WINDOW_MS,
} from "@/lib/config";
import { checkRateLimit, resetRateLimit } from "@/lib/rate-limit";

function clientKey(request: Request): string {
  const forwarded = request.headers.get("x-forwarded-for");
  return forwarded?.split(",")[0]?.trim() || "local";
}

export async function POST(request: Request) {
  const key = `login:${clientKey(request)}`;
  const limit = checkRateLimit(
    key,
    RATE_LIMIT_LOGIN_MAX,
    RATE_LIMIT_LOGIN_WINDOW_MS,
  );
  if (!limit.allowed) {
    return NextResponse.json(
      { error: `Çok fazla deneme. ${limit.retryAfterSec}s sonra tekrar deneyin.` },
      { status: 429 },
    );
  }

  try {
    const body = await request.json();
    const action = String(body.action ?? "login");

    if (action === "register") {
      const email = String(body.email ?? "");
      const name = String(body.name ?? "");
      const password = String(body.password ?? "");
      if (!email || !name || password.length < 6) {
        return NextResponse.json(
          { error: "Geçerli e-posta, isim ve en az 6 karakter şifre gerekli" },
          { status: 400 },
        );
      }
      const user = await registerUser(email, name, password);
      await createSession(user.id);
      resetRateLimit(key);
      return NextResponse.json({
        user: { id: user.id, email: user.email, name: user.name },
      });
    }

    const email = String(body.email ?? "");
    const password = String(body.password ?? "");
    const user = await loginUser(email, password);
    await createSession(user.id);
    resetRateLimit(key);
    return NextResponse.json({
      user: { id: user.id, email: user.email, name: user.name },
    });
  } catch (err) {
    const message = err instanceof Error ? err.message : "Giriş başarısız";
    return NextResponse.json({ error: message }, { status: 401 });
  }
}
