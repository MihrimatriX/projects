import { NextResponse } from "next/server";
import { requireUser } from "@/lib/auth";
import { exportUserData } from "@/lib/export";

export async function GET() {
  try {
    const user = await requireUser();
    const data = await exportUserData(user.id);
    const filename = `sohbet-export-${user.email.replace("@", "_")}-${Date.now()}.json`;

    return new NextResponse(JSON.stringify(data, null, 2), {
      headers: {
        "Content-Type": "application/json",
        "Content-Disposition": `attachment; filename="${filename}"`,
      },
    });
  } catch {
    return NextResponse.json({ error: "Export başarısız" }, { status: 401 });
  }
}
