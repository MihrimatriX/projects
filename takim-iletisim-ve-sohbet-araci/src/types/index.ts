export type ChannelType = "PUBLIC" | "DM";

export type UserStatus = "ONLINE" | "AWAY" | "OFFLINE";

export type AuthUser = {
  id: string;
  email: string;
  name: string;
  status: UserStatus;
};

export type ChannelSummary = {
  id: string;
  name: string;
  type: ChannelType;
  unreadCount: number;
  dmPartner?: { id: string; name: string; status: UserStatus } | null;
};

export type MessageItem = {
  id: string;
  content: string;
  createdAt: string;
  editedAt?: string | null;
  author: { id: string; name: string; email: string };
  attachments: {
    id: string;
    fileName: string;
    mimeType: string;
    size: number;
  }[];
  readByOthers: boolean;
  replyCount: number;
  parentId?: string | null;
};

export type MemberItem = {
  id: string;
  name: string;
  email: string;
  status: UserStatus;
};

export type WebhookItem = {
  id: string;
  name: string;
  channelId: string;
  channelName: string;
  token: string;
  url: string;
  createdAt: string;
};

export type SocketMessage = MessageItem & { channelId: string };
