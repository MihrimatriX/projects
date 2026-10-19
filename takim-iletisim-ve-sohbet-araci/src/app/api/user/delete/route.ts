import { NextResponse } from "next/server";
import { destroySession, requireUser } from "@/lib/auth";
import { deleteUserAccount } from "@/lib/export";

export async function POST(request: Request) {
  try {
    const user = await requireUser();
    const body = await request.json();
    const confirm = String(body.confirm ?? "");
    if (confirm !== user.email) {
      return NextResponse.json(
        { error: "Onay için e-posta adresinizi yazın" },
        { status: 400 },
      );
    }

    await deleteUserAccount(user.id);
    await destroySession();
    return NextResponse.json({ ok: true });
  } catch {
    return NextResponse.json({ error: "Silme başarısız" }, { status: 401 });
  }
}
