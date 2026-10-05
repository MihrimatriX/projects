import { contextBridge, ipcRenderer, webUtils } from "electron";
import type { AppSettings } from "./settingsStore";
import type { CompareProgress } from "./compareLogic";

contextBridge.exposeInMainWorld("electronAPI", {
  pickFolder: () => ipcRenderer.invoke("dialog:pickFolder"),
  pickFile: () => ipcRenderer.invoke("dialog:pickFile"),
  pickPath: () => ipcRenderer.invoke("dialog:pickPath"),
  savePatch: (defaultName: string) => ipcRenderer.invoke("dialog:savePatch", defaultName),
  saveMerged: (defaultName: string) => ipcRenderer.invoke("dialog:saveMerged", defaultName),
  // webUtils yalnızca renderer/preload tarafında çalışır; File nesnesi IPC ile main'e taşınamaz.
  getPathForFile: (file: File) => Promise.resolve(webUtils.getPathForFile(file)),
  showItemInFolder: (filePath: string) => ipcRenderer.invoke("shell:showItem", filePath),
  getVersion: () => ipcRenderer.invoke("app:version") as Promise<string>,
  getSettings: () => ipcRenderer.invoke("settings:get") as Promise<AppSettings>,
  saveSettings: (partial: Partial<AppSettings>) =>
    ipcRenderer.invoke("settings:save", partial) as Promise<AppSettings>,
  clearHashCache: (left?: string, right?: string) =>
    ipcRenderer.invoke("cache:clear", left, right) as Promise<boolean>,
  comparePaths: (left: string, right: string) => ipcRenderer.invoke("compare:paths", left, right),
  onCompareProgress: (callback: (progress: CompareProgress) => void) => {
    const handler = (_: unknown, progress: CompareProgress) => callback(progress);
    ipcRenderer.on("compare:progress", handler);
    return () => ipcRenderer.removeListener("compare:progress", handler);
  },
  readFilePair: (left: string, right: string, relativePath?: string) =>
    ipcRenderer.invoke("file:readPair", left, right, relativePath),
  readFileTriple: (base: string, left: string, right: string, relativePath?: string) =>
    ipcRenderer.invoke("file:readTriple", base, left, right, relativePath),
  mergeFile: (payload: {
    left: string;
    right: string;
    relativePath?: string;
    direction: "left-to-right" | "right-to-left";
    createBackup?: boolean;
  }) => ipcRenderer.invoke("file:merge", payload),
  mergeThreeWay: (payload: {
    outputPath: string;
    base: string;
    left: string;
    right: string;
    resolutions: Record<number, "left" | "right" | "base" | "both">;
    createBackup?: boolean;
  }) => ipcRenderer.invoke("file:mergeThreeWay", payload),
  exportPatch: (payload: { fileName: string; left: string; right: string; savePath: string }) =>
    ipcRenderer.invoke("patch:export", payload),
  parseGitDiff: (text: string) => ipcRenderer.invoke("patch:parseGit", text),
  writeTextFile: (filePath: string, content: string) =>
    ipcRenderer.invoke("fs:writeText", filePath, content),
});
