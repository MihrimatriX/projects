import { contextBridge, ipcRenderer } from "electron";
import type { ElectronAPI, WebhookRequest } from "../src/types";

const electronAPI: ElectronAPI = {
  startServer: (port) => ipcRenderer.invoke("server:start", port),
  stopServer: () => ipcRenderer.invoke("server:stop"),
  getServerStatus: () => ipcRenderer.invoke("server:status"),
  getSettings: () => ipcRenderer.invoke("settings:get"),
  saveSettings: (partial) => ipcRenderer.invoke("settings:set", partial),
  getEndpoints: () => ipcRenderer.invoke("endpoints:getAll"),
  createEndpoint: () => ipcRenderer.invoke("endpoints:create"),
  deleteEndpoint: (id) => ipcRenderer.invoke("endpoints:delete", id),
  getRequests: () => ipcRenderer.invoke("requests:getAll"),
  clearRequests: (endpointId) => ipcRenderer.invoke("requests:clear", endpointId),
  deleteRequest: (id) => ipcRenderer.invoke("requests:delete", id),
  replayRequest: (id, targetUrl) => ipcRenderer.invoke("requests:replay", id, targetUrl),
  exportRequests: () => ipcRenderer.invoke("requests:export"),
  listMockRules: (endpointId) => ipcRenderer.invoke("mockRules:list", endpointId),
  saveMockRule: (rule) => ipcRenderer.invoke("mockRules:save", rule),
  deleteMockRule: (id) => ipcRenderer.invoke("mockRules:delete", id),
  verifySignature: (input) => ipcRenderer.invoke("signature:verify", input),
  onRequest: (callback) => {
    // Aboneliği kaldıran fonksiyonu döndür; yoksa her effect çalışmasında dinleyici birikir ve istekler çift görünür
    const handler = (_event: unknown, data: WebhookRequest) => callback(data);
    ipcRenderer.on("webhook:request", handler);
    return () => ipcRenderer.removeListener("webhook:request", handler);
  },
};

contextBridge.exposeInMainWorld("electronAPI", electronAPI);
