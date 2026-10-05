"use client";

export function isTauriRuntime(): boolean {
  return typeof window !== "undefined" && "__TAURI_INTERNALS__" in window;
}

export async function tauriPickAndReadFile(): Promise<{
  path: string;
  content: string;
} | null> {
  if (!isTauriRuntime()) return null;

  try {
    const { open } = await import("@tauri-apps/plugin-dialog");
    const { readTextFile } = await import("@tauri-apps/plugin-fs");

    const selected = await open({
      multiple: false,
      filters: [{ name: "JSON", extensions: ["json", "ndjson", "jsonc", "txt"] }],
    });

    if (!selected || typeof selected !== "string") return null;

    const content = await readTextFile(selected);
    return { path: selected, content };
  } catch {
    return null;
  }
}

export async function tauriReadFile(path: string): Promise<string | null> {
  if (!isTauriRuntime()) return null;
  try {
    const { invoke } = await import("@tauri-apps/api/core");
    return await invoke<string>("read_text_file", { path });
  } catch {
    return null;
  }
}

export async function tauriSaveFile(path: string, content: string): Promise<boolean> {
  if (!isTauriRuntime()) return false;
  try {
    const { writeTextFile } = await import("@tauri-apps/plugin-fs");
    await writeTextFile(path, content);
    return true;
  } catch {
    return false;
  }
}

export async function tauriStartFileWatch(
  path: string,
  onUpdate: (payload: { path: string; content: string }) => void
): Promise<(() => void) | null> {
  if (!isTauriRuntime()) return null;

  try {
    const { invoke } = await import("@tauri-apps/api/core");
    const { listen } = await import("@tauri-apps/api/event");

    await invoke("start_file_watch", { path });

    // Rust tarafındaki izleyiciler durdurulmuyor ve hepsi aynı olayı yayıyor; yalnızca bu dosyanın
    // olaylarını işle (yoksa daha önce açılmış bir dosya değişince editöre onun içeriği yüklenirdi).
    const unlisten = await listen<{ path: string; content: string }>("file-updated", (event) => {
      if (event.payload.path === path) onUpdate(event.payload);
    });

    return () => {
      unlisten();
    };
  } catch {
    return null;
  }
}
