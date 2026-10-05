import { contextBridge, ipcRenderer } from "electron";

contextBridge.exposeInMainWorld("electronAPI", {
  getSnippets: () => ipcRenderer.invoke("snippets:getAll"),
  getRecentSnippets: (limit?: number) => ipcRenderer.invoke("snippets:getRecent", limit),
  getSnippet: (id: string) => ipcRenderer.invoke("snippets:get", id),
  createSnippet: (snippet: unknown) => ipcRenderer.invoke("snippets:create", snippet),
  updateSnippet: (id: string, snippet: unknown) => ipcRenderer.invoke("snippets:update", id, snippet),
  deleteSnippet: (id: string) => ipcRenderer.invoke("snippets:delete", id),
  searchSnippets: (query: string) => ipcRenderer.invoke("snippets:search", query),
  copySnippet: (id: string) => ipcRenderer.invoke("snippets:copy", id),
  exportSnippets: () => ipcRenderer.invoke("snippets:export"),
  importSnippets: () => ipcRenderer.invoke("snippets:import"),
  importSnippetsFromText: (raw: string) => ipcRenderer.invoke("snippets:importText", raw),
  showPalette: () => ipcRenderer.invoke("app:showPalette"),
  hotkeyOk: () => ipcRenderer.invoke("app:hotkeyOk"),
  hidePalette: () => ipcRenderer.invoke("app:hidePalette"),
  editSnippet: (id: string) => ipcRenderer.invoke("app:editSnippet", id),
  onPaletteFocus: (cb: () => void) => {
    ipcRenderer.on("palette:focus", cb);
    return () => ipcRenderer.removeListener("palette:focus", cb);
  },
  onSelectSnippet: (cb: (id: string) => void) => {
    const handler = (_: unknown, id: string) => cb(id);
    ipcRenderer.on("main:select-snippet", handler);
    return () => ipcRenderer.removeListener("main:select-snippet", handler);
  },
});
