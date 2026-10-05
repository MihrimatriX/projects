"use client";

import { useJsonStore } from "./store";
import { isTauriRuntime, tauriSaveFile } from "./tauri-bridge";

/** Kaydetme/indirme icin dosya adi: acik dosyanin adi, yoksa moda gore varsayilan. */
export function downloadName(fileName: string | null, mode: "json" | "ndjson"): string {
  const base = fileName?.split(/[/\\]/).pop()?.trim();
  return base || (mode === "ndjson" ? "veri.ndjson" : "veri.json");
}

/** Tarayici/Electron: File nesnesini editore yukler (surukle-birak ve dosya secici ortak yolu). */
export function loadFile(file: File) {
  const reader = new FileReader();
  reader.onload = () => {
    const store = useJsonStore.getState();
    store.loadJsonContent(String(reader.result ?? ""));
    store.setFileName(file.name);
  };
  reader.readAsText(file);
}

/** Ctrl+O: Tauri'de yerel dialog + izleme, digerlerinde tarayici dosya secici. */
export function openJsonFile() {
  if (isTauriRuntime()) {
    window.dispatchEvent(new Event("tauri-open-file"));
    return;
  }
  const input = document.createElement("input");
  input.type = "file";
  input.accept = ".json,.jsonc,.ndjson,.txt,application/json";
  input.onchange = () => {
    const file = input.files?.[0];
    if (file) loadFile(file);
  };
  input.click();
}

/** Ctrl+S: Tauri'de acik dosyanin uzerine yazar, digerlerinde indirir. */
export async function saveJson(): Promise<boolean> {
  const { rawJson, watchedFilePath, fileName, inputMode } = useJsonStore.getState();
  if (!rawJson) return false;
  if (isTauriRuntime() && watchedFilePath) return tauriSaveFile(watchedFilePath, rawJson);

  const type = inputMode === "ndjson" ? "application/x-ndjson" : "application/json";
  const url = URL.createObjectURL(new Blob([rawJson], { type }));
  const a = document.createElement("a");
  a.href = url;
  a.download = downloadName(watchedFilePath ?? fileName, inputMode);
  a.click();
  setTimeout(() => URL.revokeObjectURL(url), 1000);
  return true;
}
