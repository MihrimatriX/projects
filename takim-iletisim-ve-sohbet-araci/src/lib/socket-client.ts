"use client";

import { io, type Socket } from "socket.io-client";
import type { SocketMessage } from "@/types";

let socket: Socket | null = null;

export function getSocket(): Socket {
  if (!socket) {
    socket = io({
      path: "/api/socket",
      autoConnect: false,
      withCredentials: true,
    });
  }
  return socket;
}

export type MessageUpdate = {
  id: string;
  channelId: string;
  parentId: string | null;
  content: string;
  editedAt: string;
};

export type SocketHandlers = {
  onMessage?: (msg: SocketMessage) => void;
  onDelete?: (data: { messageId: string; channelId: string; parentId?: string | null }) => void;
  onUpdate?: (data: MessageUpdate) => void;
  onRead?: (data: { channelId: string; userId: string }) => void;
  onPresence?: (data: { userId: string; status: string }) => void;
  onTypingStart?: (data: {
    channelId: string;
    userId: string;
    userName: string;
  }) => void;
  onTypingStop?: (data: {
    channelId: string;
    userId: string;
    userName: string;
  }) => void;
};

export function connectSocket(handlers: SocketHandlers) {
  const s = getSocket();
  s.off("message:new");
  s.off("message:delete");
  s.off("message:update");
  s.off("message:read");
  s.off("presence:update");
  s.off("typing:start");
  s.off("typing:stop");

  if (handlers.onMessage) s.on("message:new", handlers.onMessage);
  if (handlers.onDelete) s.on("message:delete", handlers.onDelete);
  if (handlers.onUpdate) s.on("message:update", handlers.onUpdate);
  if (handlers.onRead) s.on("message:read", handlers.onRead);
  if (handlers.onPresence) s.on("presence:update", handlers.onPresence);
  if (handlers.onTypingStart) s.on("typing:start", handlers.onTypingStart);
  if (handlers.onTypingStop) s.on("typing:stop", handlers.onTypingStop);

  if (!s.connected) s.connect();
  return s;
}

export function disconnectSocket() {
  socket?.disconnect();
  socket = null;
}
