import { NextResponse } from "next/server";
import type { NextRequest } from "next/server";
import { SESSION_COOKIE } from "@/lib/config";

const PUBLIC_PATHS = ["/login", "/api/auth/login", "/api/webhooks", "/api/health"];

export function proxy(request: NextRequest) {
  const { pathname } = request.nextUrl;
  const response = NextResponse.next();

  response.headers.set("X-Frame-Options", "DENY");
  response.headers.set("X-Content-Type-Options", "nosniff");
  response.headers.set("Referrer-Policy", "strict-origin-when-cross-origin");
  response.headers.set(
    "Content-Security-Policy",
    "default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; style-src 'self' 'unsafe-inline'; font-src 'self'; img-src 'self' data: blob:; connect-src 'self' ws: wss:; frame-ancestors 'none'",
  );

  if (PUBLIC_PATHS.some((p) => pathname.startsWith(p))) {
    return response;
  }

  if (
    pathname.startsWith("/chat") ||
    pathname.startsWith("/settings") ||
    (pathname.startsWith("/api/") &&
      !pathname.startsWith("/api/auth/login") &&
      !pathname.startsWith("/api/webhooks/"))
  ) {
    const session = request.cookies.get(SESSION_COOKIE)?.value;
    if (!session) {
      if (pathname.startsWith("/api/")) {
        return NextResponse.json({ error: "Oturum gerekli" }, { status: 401 });
      }
      return NextResponse.redirect(new URL("/login", request.url));
    }
  }

  if (pathname === "/login") {
    const session = request.cookies.get(SESSION_COOKIE)?.value;
    if (session) {
      return NextResponse.redirect(new URL("/chat", request.url));
    }
  }

  return response;
}

export const config = {
  matcher: ["/((?!_next/static|_next/image|favicon.ico).*)"],
};
