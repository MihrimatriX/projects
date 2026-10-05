import { create } from "zustand";
import type { AuthUser, ChannelSummary, MemberItem, MessageItem } from "@/types";

type ChatState = {
  user: AuthUser | null;
  workspaceName: string;
  channels: ChannelSummary[];
  activeChannelId: string | null;
  messages: MessageItem[];
  members: MemberItem[];
  typingUsers: Record<string, string[]>;
  searchOpen: boolean;
  setUser: (user: AuthUser | null) => void;
  setWorkspaceName: (name: string) => void;
  setChannels: (channels: ChannelSummary[]) => void;
  setActiveChannelId: (id: string | null) => void;
  setMessages: (messages: MessageItem[]) => void;
  prependMessages: (messages: MessageItem[]) => void;
  addMessage: (message: MessageItem) => void;
  removeMessage: (messageId: string) => void;
  updateMessage: (messageId: string, patch: Partial<MessageItem>) => void;
  bumpReplyCount: (messageId: string, delta?: number) => void;
  setMembers: (members: MemberItem[]) => void;
  updateMemberStatus: (userId: string, status: MemberItem["status"]) => void;
  setTyping: (channelId: string, userName: string, active: boolean) => void;
  setSearchOpen: (open: boolean) => void;
  bumpUnread: (channelId: string) => void;
  clearUnread: (channelId: string) => void;
};

export const useChatStore = create<ChatState>((set) => ({
  user: null,
  workspaceName: "Takım",
  channels: [],
  activeChannelId: null,
  messages: [],
  members: [],
  typingUsers: {},
  searchOpen: false,
  setUser: (user) => set({ user }),
  setWorkspaceName: (workspaceName) => set({ workspaceName }),
  setChannels: (channels) => set({ channels }),
  setActiveChannelId: (activeChannelId) => set({ activeChannelId }),
  setMessages: (messages) => set({ messages }),
  prependMessages: (older) =>
    set((s) => ({ messages: [...older, ...s.messages] })),
  addMessage: (message) =>
    set((s) => {
      if (s.messages.some((m) => m.id === message.id)) return s;
      return { messages: [...s.messages, message] };
    }),
  removeMessage: (messageId) =>
    set((s) => ({
      messages: s.messages.filter((m) => m.id !== messageId),
    })),
  updateMessage: (messageId, patch) =>
    set((s) => ({
      messages: s.messages.map((m) => (m.id === messageId ? { ...m, ...patch } : m)),
    })),
  bumpReplyCount: (messageId, delta = 1) =>
    set((s) => ({
      messages: s.messages.map((m) =>
        m.id === messageId ? { ...m, replyCount: Math.max(0, m.replyCount + delta) } : m,
      ),
    })),
  setMembers: (members) => set({ members }),
  updateMemberStatus: (userId, status) =>
    set((s) => ({
      members: s.members.map((m) =>
        m.id === userId ? { ...m, status } : m,
      ),
      channels: s.channels.map((c) =>
        c.dmPartner?.id === userId
          ? { ...c, dmPartner: { ...c.dmPartner, status } }
          : c,
      ),
    })),
  setTyping: (channelId, userName, active) =>
    set((s) => {
      const current = s.typingUsers[channelId] ?? [];
      const next = active
        ? [...new Set([...current, userName])]
        : current.filter((n) => n !== userName);
      return { typingUsers: { ...s.typingUsers, [channelId]: next } };
    }),
  setSearchOpen: (searchOpen) => set({ searchOpen }),
  bumpUnread: (channelId) =>
    set((s) => ({
      channels: s.channels.map((c) =>
        c.id === channelId ? { ...c, unreadCount: c.unreadCount + 1 } : c,
      ),
    })),
  clearUnread: (channelId) =>
    set((s) => ({
      channels: s.channels.map((c) =>
        c.id === channelId ? { ...c, unreadCount: 0 } : c,
      ),
    })),
}));
