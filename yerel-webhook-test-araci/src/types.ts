export type WebhookRequest = {
  id: string;
  method: string;
  url: string;
  headers: Record<string, string>;
  body: string;
  timestamp: string;
  endpointId: string;
};

export type WebhookEndpoint = {
  id: string;
  slug: string;
  createdAt: string;
};

export type ServerStatus = {
  running: boolean;
  port: number;
  error?: string;
};

export type ReplayResult = {
  ok: boolean;
  statusCode?: number;
  body?: string;
  error?: string;
};

export type AppSettings = {
  defaultPort: number;
  maxRequests: number;
  maxBodyBytes: number;
  maskSecrets: boolean;
  /** Uygulama açılınca webhook sunucusu varsayılan portta otomatik başlar */
  autoStart: boolean;
};

export type MockRule = {
  id: string;
  endpointId: string;
  method: string | null;
  pathPattern: string | null;
  statusCode: number;
  body: string;
  contentType: string;
  priority: number;
};

export type SignaturePreset = "stripe" | "github" | "shopify";

export type SignatureVerifyInput = {
  requestId: string;
  preset: SignaturePreset;
  secret: string;
};

export type SignatureVerifyResult = {
  valid: boolean;
  message: string;
};

export type ExportPayload = {
  exportedAt: string;
  warning: string;
  endpoints: WebhookEndpoint[];
  requests: WebhookRequest[];
};

export type ExportResult = { ok: boolean; path?: string };

export type RequestFilters = {
  methods: string[];
  /** Path, gövde veya başlık değerlerinde aranır */
  path: string;
};

export type ElectronAPI = {
  startServer: (port?: number) => Promise<ServerStatus>;
  stopServer: () => Promise<ServerStatus>;
  getServerStatus: () => Promise<ServerStatus>;
  getSettings: () => Promise<AppSettings>;
  saveSettings: (partial: Partial<AppSettings>) => Promise<AppSettings>;
  getEndpoints: () => Promise<WebhookEndpoint[]>;
  createEndpoint: () => Promise<WebhookEndpoint>;
  deleteEndpoint: (id: string) => Promise<boolean>;
  getRequests: () => Promise<WebhookRequest[]>;
  clearRequests: (endpointId?: string) => Promise<boolean>;
  deleteRequest: (id: string) => Promise<boolean>;
  replayRequest: (id: string, targetUrl?: string) => Promise<ReplayResult>;
  exportRequests: () => Promise<ExportResult>;
  listMockRules: (endpointId?: string) => Promise<MockRule[]>;
  saveMockRule: (rule: MockRule) => Promise<MockRule>;
  deleteMockRule: (id: string) => Promise<boolean>;
  verifySignature: (input: SignatureVerifyInput) => Promise<SignatureVerifyResult>;
  onRequest: (callback: (data: WebhookRequest) => void) => () => void;
};

declare global {
  interface Window {
    electronAPI?: ElectronAPI;
  }
}
