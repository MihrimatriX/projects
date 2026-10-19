import { redirect } from "next/navigation";
import { SettingsPage } from "@/components/SettingsPage";
import { getSessionUser } from "@/lib/auth";

export default async function SettingsRoute() {
  const user = await getSessionUser();
  if (!user) redirect("/login");
  return <SettingsPage />;
}
