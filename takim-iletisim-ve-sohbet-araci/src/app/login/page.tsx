"use client";

import { useRouter } from "next/navigation";
import { useState } from "react";

export default function LoginPage() {
  const router = useRouter();
  const [mode, setMode] = useState<"login" | "register">("login");
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);

  // Değerler formdan okunur: sayfa hidrasyonundan önce yazılanlar da kaybolmaz
  async function submit(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault();
    const form = new FormData(e.currentTarget);
    setError("");
    setLoading(true);
    try {
      const res = await fetch("/api/auth/login", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          action: mode,
          email: form.get("email"),
          name: form.get("name") ?? "",
          password: form.get("password"),
        }),
      });
      const data = await res.json().catch(() => ({}));
      if (!res.ok) throw new Error(data.error ?? "İşlem başarısız");
      router.push("/chat");
      router.refresh();
    } catch (err) {
      setError(err instanceof Error && err.message !== "Failed to fetch" ? err.message : "Sunucuya ulaşılamadı");
    } finally {
      setLoading(false);
    }
  }

  return (
    <div
      className="min-h-screen flex items-center justify-center p-6"
      style={{ background: "var(--bg-sidebar)" }}
    >
      <div
        className="w-full max-w-md rounded-xl p-8 shadow-xl"
        style={{ background: "var(--bg-main)" }}
      >
        <h1 className="text-2xl font-semibold mb-2">Takım Sohbet</h1>
        <p className="text-sm mb-6" style={{ color: "var(--text-muted)" }}>
          Self-host takım iletişimi
        </p>

        <div className="flex gap-2 mb-6">
          <button
            type="button"
            onClick={() => setMode("login")}
            aria-pressed={mode === "login"}
            className="flex-1 py-2 rounded-lg text-sm font-medium"
            style={{
              background: mode === "login" ? "var(--accent)" : "var(--bg-hover)",
            }}
          >
            Giriş
          </button>
          <button
            type="button"
            onClick={() => setMode("register")}
            aria-pressed={mode === "register"}
            className="flex-1 py-2 rounded-lg text-sm font-medium"
            style={{
              background:
                mode === "register" ? "var(--accent)" : "var(--bg-hover)",
            }}
          >
            Kayıt
          </button>
        </div>

        <form onSubmit={submit} method="post" className="space-y-4">
          {mode === "register" && (
            <input
              className="w-full rounded-lg px-4 py-3 text-sm outline-none focus:ring-2"
              style={{
                background: "var(--bg-input)",
                color: "var(--text-primary)",
              }}
              placeholder="Adınız"
              aria-label="Adınız"
              autoComplete="name"
              name="name"
              required
            />
          )}
          <input
            type="email"
            className="w-full rounded-lg px-4 py-3 text-sm outline-none"
            style={{
              background: "var(--bg-input)",
              color: "var(--text-primary)",
            }}
            placeholder="E-posta"
            aria-label="E-posta"
            autoComplete="email"
            name="email"
            required
          />
          <input
            type="password"
            className="w-full rounded-lg px-4 py-3 text-sm outline-none"
            style={{
              background: "var(--bg-input)",
              color: "var(--text-primary)",
            }}
            placeholder="Şifre (min 6 karakter)"
            aria-label="Şifre"
            autoComplete={mode === "login" ? "current-password" : "new-password"}
            name="password"
            minLength={6}
            required
          />
          {error && (
            <p role="alert" className="text-sm" style={{ color: "var(--unread)" }}>
              {error}
            </p>
          )}
          <button
            type="submit"
            disabled={loading}
            className="w-full py-3 rounded-lg font-medium text-white disabled:opacity-50"
            style={{ background: "var(--accent)" }}
          >
            {loading ? "..." : mode === "login" ? "Giriş yap" : "Kayıt ol"}
          </button>
        </form>

        <p
          className="text-xs mt-6 text-center"
          style={{ color: "var(--text-muted)" }}
        >
          Demo: mehmet@acme.local / demo1234
        </p>
      </div>
    </div>
  );
}
