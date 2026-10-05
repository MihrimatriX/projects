import { contextBridge, ipcRenderer } from "electron";
import type {
  Account,
  AppSettings,
  AttachmentInput,
  MailFolderView,
  MailMessage,
  MailTemplate,
  MailTracking,
  SearchFilters,
  SendMailInput,
} from "./types";

contextBridge.exposeInMainWorld("electronAPI", {
  listAccounts: () => ipcRenderer.invoke("account:list") as Promise<(Account & { hasPassword: boolean })[]>,
  getActiveAccountId: () => ipcRenderer.invoke("account:activeId") as Promise<string | null>,
  saveAccounts: (accounts: Account[], activeId?: string) =>
    ipcRenderer.invoke("account:save", accounts, activeId),
  createAccountId: () => ipcRenderer.invoke("account:createId") as Promise<string>,
  getProviderPreset: (provider: string) => ipcRenderer.invoke("account:preset", provider),
  testConnection: (account: Account & { password?: string }) =>
    ipcRenderer.invoke("account:test", account) as Promise<{ ok: boolean; message: string }>,
  connectGoogleOAuth: (accountId: string, clientId: string, email?: string) =>
    ipcRenderer.invoke("oauth:google", accountId, clientId, email),
  revokeOAuth: (accountId: string) => ipcRenderer.invoke("oauth:revoke", accountId),

  getSettings: () => ipcRenderer.invoke("settings:get") as Promise<AppSettings>,
  saveSettings: (patch: Partial<AppSettings>) => ipcRenderer.invoke("settings:save", patch),

  listMail: (folder: MailFolderView, filters?: SearchFilters) =>
    ipcRenderer.invoke("mail:list", folder, filters),
  folderCounts: () => ipcRenderer.invoke("mail:counts"),
  syncImap: () => ipcRenderer.invoke("mail:syncImap") as Promise<{ count: number; errors: string[] }>,
  sendMail: (input: SendMailInput) => ipcRenderer.invoke("mail:send", input),
  saveDraft: (input: SendMailInput & { id?: string }) => ipcRenderer.invoke("mail:saveDraft", input),
  markRead: (id: string, read?: boolean) => ipcRenderer.invoke("mail:markRead", id, read),
  markAllRead: (folder: MailFolderView) => ipcRenderer.invoke("mail:markAllRead", folder),
  emptyTrash: () => ipcRenderer.invoke("mail:emptyTrash") as Promise<number>,
  toggleStar: (id: string) => ipcRenderer.invoke("mail:toggleStar", id),
  archiveMail: (id: string) => ipcRenderer.invoke("mail:archive", id),
  deleteMail: (id: string) => ipcRenderer.invoke("mail:delete", id),
  restoreMail: (items: MailMessage[]) => ipcRenderer.invoke("mail:restore", items) as Promise<number>,
  snoozeMail: (id: string, untilIso: string) => ipcRenderer.invoke("mail:snooze", id, untilIso),
  trackMail: (id: string, tracking: MailTracking | null) =>
    ipcRenderer.invoke("mail:track", id, tracking),
  bulkAction: (ids: string[], action: string, payload?: unknown) =>
    ipcRenderer.invoke("mail:bulk", ids, action, payload),
  trackingList: () => ipcRenderer.invoke("mail:trackingList") as Promise<MailMessage[]>,

  listTemplates: () => ipcRenderer.invoke("templates:list") as Promise<MailTemplate[]>,
  saveTemplate: (template: MailTemplate) => ipcRenderer.invoke("templates:save", template),
  deleteTemplate: (id: string) => ipcRenderer.invoke("templates:delete", id),

  pickAttachments: () => ipcRenderer.invoke("dialog:pickAttachments") as Promise<AttachmentInput[]>,
  exportData: () => ipcRenderer.invoke("data:export") as Promise<boolean>,
  importData: () => ipcRenderer.invoke("data:import") as Promise<number>,
  getAppVersion: () => ipcRenderer.invoke("app:version") as Promise<string>,

  onMailSynced: (callback: (payload: { total: number; errors: string[] }) => void) => {
    const handler = (_: unknown, payload: { total: number; errors: string[] }) => callback(payload);
    ipcRenderer.on("mail:synced", handler);
    return () => ipcRenderer.removeListener("mail:synced", handler);
  },
});
