export type Snippet = {
  id: string;
  title: string;
  description: string;
  language: string;
  tags: string[];
  folder: string;
  code: string;
  createdAt?: string;
  updatedAt?: string;
  lastUsedAt?: string | null;
};

export type ElectronAPI = {
  getSnippets: () => Promise<Snippet[]>;
  getRecentSnippets: (limit?: number) => Promise<Snippet[]>;
  getSnippet: (id: string) => Promise<Snippet | null>;
  createSnippet: (snippet: Partial<Snippet>) => Promise<Snippet>;
  updateSnippet: (id: string, snippet: Partial<Snippet>) => Promise<Snippet | null>;
  deleteSnippet: (id: string) => Promise<boolean>;
  searchSnippets: (query: string) => Promise<Snippet[]>;
  copySnippet: (id: string) => Promise<boolean>;
  exportSnippets: () => Promise<boolean>;
  importSnippets: () => Promise<{ imported: number }>;
  importSnippetsFromText: (raw: string) => Promise<{ imported: number }>;
  showPalette: () => Promise<void>;
  hotkeyOk: () => Promise<boolean>;
  hidePalette: () => Promise<void>;
  editSnippet: (id: string) => Promise<void>;
  onPaletteFocus: (cb: () => void) => () => void;
  onSelectSnippet: (cb: (id: string) => void) => () => void;
};

declare global {
  interface Window {
    electronAPI: ElectronAPI;
  }
}

export {};
