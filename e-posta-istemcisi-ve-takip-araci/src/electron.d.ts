import type {
  Account,
  AppSettings,
  AttachmentInput,
  FolderCounts,
  MailFolderView,
  MailMessage,
  MailTemplate,
  MailTracking,
  SearchFilters,
  SendMailInput,
} from "./types";

declare global {
  interface Window {
    electronAPI: {
      listAccounts: () => Promise<Account[]>;
      getActiveAccountId: () => Promise<string | null>;
      saveAccounts: (accounts: Account[], activeId?: string) => Promise<Account[]>;
      createAccountId: () => Promise<string>;
      getProviderPreset: (provider: string) => Promise<Partial<Account>>;
      testConnection: (account: Account) => Promise<{ ok: boolean; message: string }>;
      connectGoogleOAuth: (accountId: string, clientId: string, email?: string) => Promise<{ email: string }>;
      revokeOAuth: (accountId: string) => Promise<boolean>;

      getSettings: () => Promise<AppSettings>;
      saveSettings: (patch: Partial<AppSettings>) => Promise<AppSettings>;

      listMail: (folder: MailFolderView, filters?: SearchFilters) => Promise<MailMessage[]>;
      folderCounts: () => Promise<FolderCounts>;
      syncImap: () => Promise<{ count: number; errors: string[] }>;
      sendMail: (input: SendMailInput) => Promise<MailMessage>;
      saveDraft: (input: SendMailInput & { id?: string }) => Promise<MailMessage>;
      markRead: (id: string, read?: boolean) => Promise<boolean>;
      markAllRead: (folder: MailFolderView) => Promise<number>;
      emptyTrash: () => Promise<number>;
      toggleStar: (id: string) => Promise<boolean>;
      archiveMail: (id: string) => Promise<boolean>;
      deleteMail: (id: string) => Promise<boolean>;
      restoreMail: (items: MailMessage[]) => Promise<number>;
      snoozeMail: (id: string, untilIso: string) => Promise<boolean>;
      trackMail: (id: string, tracking: MailTracking | null) => Promise<boolean>;
      bulkAction: (ids: string[], action: string, payload?: unknown) => Promise<boolean>;
      trackingList: () => Promise<MailMessage[]>;

      listTemplates: () => Promise<MailTemplate[]>;
      saveTemplate: (template: MailTemplate) => Promise<MailTemplate>;
      deleteTemplate: (id: string) => Promise<boolean>;

      pickAttachments: () => Promise<AttachmentInput[]>;
      exportData: () => Promise<boolean>;
      importData: () => Promise<number>;
      getAppVersion: () => Promise<string>;

      onMailSynced: (callback: (payload: { total: number; errors: string[] }) => void) => () => void;
    };
  }
}

export {};
