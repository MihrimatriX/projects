export type ProviderPreset = "custom" | "gmail" | "outlook";

export type Account = {
  id: string;
  server: string;
  email: string;
  displayName: string;
  /** Yalnızca kullanıcı yeni şifre yazdığında dolu; kayıtlı şifre arayüze gelmez. */
  password?: string;
  hasPassword?: boolean;
  imapPort?: number;
  smtpServer?: string;
  smtpPort?: number;
  provider?: ProviderPreset;
  authMode?: "password" | "oauth";
  googleClientId?: string;
};

export type MailAttachment = {
  name: string;
  size: number;
  path?: string;
};

export type MailTracking = {
  waitingReply: boolean;
  startedAt: string;
  reminderDays: number;
  notified?: boolean;
  repliedAt?: string;
};

export type MailMessage = {
  id: string;
  accountId: string;
  folder: "inbox" | "sent" | "drafts" | "trash";
  from: string;
  to: string;
  subject: string;
  body: string;
  bodyHtml?: string;
  read: boolean;
  starred: boolean;
  archived: boolean;
  date: string;
  remote?: boolean;
  snoozedUntil?: string | null;
  tracking?: MailTracking | null;
  inReplyTo?: string;
  attachments?: MailAttachment[];
  readReceiptRequested?: boolean;
};

export type MailFolderView =
  | "inbox"
  | "unified"
  | "sent"
  | "drafts"
  | "archive"
  | "trash"
  | "starred"
  | "tracking"
  | "snoozed";

export type MailTemplate = {
  id: string;
  name: string;
  subject: string;
  body: string;
};

export type AttachmentInput = {
  name: string;
  path: string;
};

export type SendMailInput = {
  to: string;
  subject: string;
  body: string;
  bodyHtml?: string;
  draftId?: string;
  inReplyTo?: string;
  accountId?: string;
  attachments?: AttachmentInput[];
  requestReadReceipt?: boolean;
  startTracking?: boolean;
  trackingDays?: number;
};

export type SearchFilters = {
  query?: string;
  fromDate?: string;
  toDate?: string;
  accountId?: string;
};

export type AppSettings = {
  cacheDays: number;
  syncIntervalMinutes: number;
  backgroundSync: boolean;
  notifyNewMail: boolean;
  notifyTrackingDue: boolean;
  useIdle: boolean;
  minimizeToTray: boolean;
  onboardingDone: boolean;
  theme: "system" | "light" | "dark";
};

export type FolderCounts = Record<MailFolderView, number>;

export type ComposeMode = "new" | "reply" | "forward" | "draft";
