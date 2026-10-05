import { redirect } from "next/navigation";
import { ensureSeed } from "@/lib/seed";
import { prisma } from "@/lib/prisma";

export const dynamic = "force-dynamic";

export default async function DersRedirectPage() {
  await ensureSeed();
  const course = await prisma.course.findFirst({ orderBy: { createdAt: "asc" } });
  redirect(course ? `/course/${course.id}` : "/katalog");
}
