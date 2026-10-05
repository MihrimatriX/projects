import { cookies } from "next/headers";
import {
  createSessionRecord,
  deleteSessionRecord,
  getSessionUserFromId,
  loginUser,
  registerUser,
} from "@/lib/auth-core";
import { SESSION_COOKIE, SESSION_DAYS } from "@/lib/config";
import type { AuthUser } from "@/types";

export {
  getSessionUserFromId,
  loginUser,
  registerUser,
} from "@/lib/auth-core";

export async function createSession(userId: string) {
  const session = await createSessionRecord(userId, SESSION_DAYS);
  const cookieStore = await cookies();
  cookieStore.set(SESSION_COOKIE, session.id, {
    httpOnly: true,
    sameSite: "lax",
    secure: process.env.NODE_ENV === "production",
    path: "/",
    expires: session.expiresAt,
  });
  return session;
}

export async function destroySession() {
  const cookieStore = await cookies();
  const sessionId = cookieStore.get(SESSION_COOKIE)?.value;
  if (sessionId) {
    await deleteSessionRecord(sessionId);
    cookieStore.delete(SESSION_COOKIE);
  }
}

export async function getSessionUser(): Promise<AuthUser | null> {
  const cookieStore = await cookies();
  const sessionId = cookieStore.get(SESSION_COOKIE)?.value;
  if (!sessionId) return null;

  const user = await getSessionUserFromId(sessionId);
  if (!user) {
    await deleteSessionRecord(sessionId);
    return null;
  }
  return user;
}

export async function requireUser(): Promise<AuthUser> {
  const user = await getSessionUser();
  if (!user) throw new Error("Oturum gerekli");
  return user;
}
