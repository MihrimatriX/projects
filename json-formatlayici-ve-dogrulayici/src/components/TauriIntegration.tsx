"use client";

import { useEffect, useRef } from "react";
import { useJsonStore } from "@/lib/store";
import { isTauriRuntime, tauriPickAndReadFile, tauriStartFileWatch } from "@/lib/tauri-bridge";

export default function TauriIntegration() {
  const { loadJsonContent, setWatchedFilePath, addRecentFile, setFileChangedExternally, watchEnabled } =
    useJsonStore();
  const unwatchRef = useRef<(() => void) | null>(null);

  useEffect(() => {
    useJsonStore.setState({ isTauriApp: isTauriRuntime() });
  }, []);

  useEffect(() => () => unwatchRef.current?.(), []);

  useEffect(() => {
    const onOpen = async () => {
      unwatchRef.current?.();
      unwatchRef.current = null;

      const picked = await tauriPickAndReadFile();
      if (!picked) return;

      loadJsonContent(picked.content);
      setWatchedFilePath(picked.path);
      addRecentFile(picked.path);

      if (!watchEnabled) return;

      const stop = await tauriStartFileWatch(picked.path, (payload) => {
        setFileChangedExternally(true);
        loadJsonContent(payload.content, { bypassWarning: true });
      });
      unwatchRef.current = stop ?? null;
    };

    window.addEventListener("tauri-open-file", onOpen);
    return () => window.removeEventListener("tauri-open-file", onOpen);
  }, [loadJsonContent, setWatchedFilePath, addRecentFile, setFileChangedExternally, watchEnabled]);

  return null;
}
