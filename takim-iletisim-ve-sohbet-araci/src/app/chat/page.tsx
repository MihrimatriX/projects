import { redirect } from "next/navigation";
import { ChatApp } from "@/components/ChatApp";
import { getSessionUser } from "@/lib/auth";

export default async function ChatPage() {
  const user = await getSessionUser();
  if (!user) redirect("/login");
  return <ChatApp />;
}
