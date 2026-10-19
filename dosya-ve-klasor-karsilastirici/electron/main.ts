import { createRequire } from "node:module";
import { fileURLToPath } from "node:url";
import type { BrowserWindow as BrowserWindowType } from "electron";
import fs from "fs";
import path from "path";

const __dirname = path.dirname(fileURLToPath(import.meta.url));

const require = createRequire(import.meta.url);
const { app, BrowserWindow, dialog, ipcMain, shell } = require("electron") as typeof import("electron");
import {
  compareFolders,
  detectLanguage,
  diffStats,
  mergeCopy,
  readTextFile,
  resolvePaths,
  writeWithBackup,
} from "./compareLogic";
import { readHexFile } from "./hexLogic";
import { createUnifiedPatch, parseGitDiff } from "./patchLogic";
import { clearAllCaches, clearCacheForRoot } from "./hashCache";
import {
  allIgnoreDirs,
  loadSettings,
  pushRecentPair,
  saveSettings,
  type AppSettings,
} from "./settingsStore";
import { enforceSingleInstance } from "./singleInstance";
import { applyConflictResolutions, threeWayMerge } from "./threeWayMerge";

let mainWindow: BrowserWindowType | null = null;

function appVersion(): string {
  try {
    const pkg = JSON.parse(
      fs.readFileSync(path.join(__dirname, "../package.json"), "utf8")
    ) as { version?: string };
    return pkg.version ?? "0.0.0";
  } catch {
    return "0.0.0";
  }
}

function resolveAppIcon(): string | undefined {
  for (const candidate of [
    path.join(__dirname, "../build/icon.png"),
    path.join(process.cwd(), "build/icon.png"),
  ]) {
    if (fs.existsSync(candidate)) return candidate;
  }
  return undefined;
}

function resolvePreload(): string {
  for (const name of ["preload.mjs", "preload.js", "preload.cjs"]) {
    const candidate = path.join(__dirname, name);
    if (fs.existsSync(candidate)) return candidate;
  }
  return path.join(__dirname, "preload.js");
}

function assertPathExists(p: string, label: string): void {
  if (!fs.existsSync(p)) throw new Error(`${label} bulunamadı: ${p}`);
}

function readSide(filePath: string) {
  if (!fs.existsSync(filePath)) {
    return {
      content: "",
      binary: false,
      truncated: false,
      hex: null as string | null,
      size: 0,
      exists: false,
    };
  }
  const text = readTextFile(filePath);
  if (text.binary) {
    const hex = readHexFile(filePath);
    return {
      content: "",
      binary: true,
      truncated: hex.truncated,
      hex: hex.hex,
      size: hex.size,
      exists: true,
    };
  }
  return {
    content: text.content,
    binary: false,
    truncated: text.truncated,
    hex: null as string | null,
    size: fs.statSync(filePath).size,
    exists: true,
  };
}

function createWindow() {
  const icon = resolveAppIcon();
  mainWindow = new BrowserWindow({
    width: 1280,
    height: 840,
    minWidth: 1024,
    minHeight: 600,
    title: "Dosya ve Klasör Karşılaştırıcı",
    ...(icon ? { icon } : {}),
    webPreferences: {
      preload: resolvePreload(),
      contextIsolation: true,
      nodeIntegration: false,
    },
  });

  if (process.env.VITE_DEV_SERVER_URL) {
    mainWindow.loadURL(process.env.VITE_DEV_SERVER_URL);
  } else {
    mainWindow.loadFile(path.join(__dirname, "../dist/index.html"));
  }

  mainWindow.on("closed", () => {
    mainWindow = null;
  });
}

ipcMain.handle("dialog:pickFolder", async () => {
  const result = await dialog.showOpenDialog(mainWindow!, { properties: ["openDirectory"] });
  return result.canceled ? null : (result.filePaths[0] ?? null);
});

ipcMain.handle("dialog:pickFile", async () => {
  const result = await dialog.showOpenDialog(mainWindow!, { properties: ["openFile"] });
  return result.canceled ? null : (result.filePaths[0] ?? null);
});

ipcMain.handle("dialog:pickPath", async () => {
  const result = await dialog.showOpenDialog(mainWindow!, {
    properties: ["openFile", "openDirectory"],
  });
  return result.canceled ? null : (result.filePaths[0] ?? null);
});

ipcMain.handle("dialog:savePatch", async (_event, defaultName: string) => {
  const result = await dialog.showSaveDialog(mainWindow!, {
    defaultPath: defaultName,
    filters: [{ name: "Patch", extensions: ["patch", "diff"] }],
  });
  return result.canceled ? null : (result.filePath ?? null);
});

ipcMain.handle("dialog:saveMerged", async (_event, defaultName: string) => {
  const result = await dialog.showSaveDialog(mainWindow!, {
    defaultPath: defaultName,
    filters: [{ name: "Metin", extensions: ["txt", "*"] }],
  });
  return result.canceled ? null : (result.filePath ?? null);
});

ipcMain.handle("shell:showItem", (_event, filePath: string) => {
  if (fs.existsSync(filePath)) shell.showItemInFolder(filePath);
});

ipcMain.handle("settings:get", () => loadSettings());

ipcMain.handle("settings:save", (_event, partial: Partial<AppSettings>) => saveSettings(partial));

ipcMain.handle("app:version", () => appVersion());

ipcMain.handle("cache:clear", (_event, left?: string, right?: string) => {
  if (!left && !right) clearAllCaches();
  if (left) clearCacheForRoot(left);
  if (right) clearCacheForRoot(right);
  return true;
});

ipcMain.handle("compare:paths", (event, left: string, right: string) => {
  if (!left || !right) throw new Error("İki yol gerekli");
  assertPathExists(left, "Sol");
  assertPathExists(right, "Sağ");
  const settings = loadSettings();

  const leftStat = fs.statSync(left);
  const rightStat = fs.statSync(right);

  if (leftStat.isFile() && rightStat.isFile()) {
    pushRecentPair(left, right);
    return { mode: "file" as const, left, right };
  }
  if (!leftStat.isDirectory() || !rightStat.isDirectory()) {
    throw new Error("İki taraf da dosya veya klasör olmalı");
  }
  const result = compareFolders(left, right, allIgnoreDirs(settings), {
    useGitignore: settings.useGitignore,
    onProgress: (p) => event.sender.send("compare:progress", p),
  });
  pushRecentPair(left, right);
  return result;
});

ipcMain.handle(
  "file:readPair",
  (_event, left: string, right: string, relativePath?: string) => {
    assertPathExists(left, "Sol");
    assertPathExists(right, "Sağ");
    const { leftPath, rightPath } = resolvePaths(left, right, relativePath);
    const leftRead = readSide(leftPath);
    const rightRead = readSide(rightPath);
    const missingSide = !leftRead.exists ? "left" : !rightRead.exists ? "right" : null;

    if (leftRead.binary || rightRead.binary) {
      return {
        left: leftRead.content,
        right: rightRead.content,
        binary: true,
        truncated: leftRead.truncated || rightRead.truncated,
        stats: { additions: 0, deletions: 0 },
        leftPath,
        rightPath,
        missingSide,
        leftHex: leftRead.hex ?? "",
        rightHex: rightRead.hex ?? "",
        leftSize: leftRead.size,
        rightSize: rightRead.size,
        language: "plaintext",
      };
    }

    const stats = diffStats(leftRead.content, rightRead.content);
    return {
      left: leftRead.content,
      right: rightRead.content,
      binary: false,
      truncated: leftRead.truncated || rightRead.truncated,
      stats,
      leftPath,
      rightPath,
      missingSide,
      leftHex: null,
      rightHex: null,
      leftSize: leftRead.size,
      rightSize: rightRead.size,
      language: detectLanguage(rightPath),
    };
  }
);

ipcMain.handle(
  "file:readTriple",
  (_event, base: string, left: string, right: string, relativePath?: string) => {
    assertPathExists(base, "Base");
    assertPathExists(left, "Sol");
    assertPathExists(right, "Sağ");

    const baseStat = fs.statSync(base);
    const leftStat = fs.statSync(left);
    const rightStat = fs.statSync(right);

    let basePath = base;
    let leftPath = left;
    let rightPath = right;

    if (baseStat.isDirectory()) {
      if (!relativePath) throw new Error("Klasör modunda dosya yolu gerekli");
      basePath = path.join(base, relativePath);
      leftPath = path.join(left, relativePath);
      rightPath = path.join(right, relativePath);
    }

    const baseRead = readSide(basePath);
    const leftRead = readSide(leftPath);
    const rightRead = readSide(rightPath);

    if (baseRead.binary || leftRead.binary || rightRead.binary) {
      throw new Error("Üç yönlü birleştirme yalnızca metin dosyaları için");
    }

    const merge = threeWayMerge(baseRead.content, leftRead.content, rightRead.content);
    saveSettings({ lastBasePath: base });

    return {
      base: baseRead.content,
      left: leftRead.content,
      right: rightRead.content,
      basePath,
      leftPath,
      rightPath,
      merge,
      language: detectLanguage(rightPath),
    };
  }
);

ipcMain.handle(
  "file:merge",
  (
    _event,
    payload: {
      left: string;
      right: string;
      relativePath?: string;
      direction: "left-to-right" | "right-to-left";
      createBackup?: boolean;
    }
  ) => {
    const settings = loadSettings();
    const { left, right, relativePath, direction, createBackup = settings.createBackupOnMerge } =
      payload;
    const { leftPath, rightPath } = resolvePaths(left, right, relativePath);
    const sourcePath = direction === "left-to-right" ? leftPath : rightPath;
    const targetPath = direction === "left-to-right" ? rightPath : leftPath;
    return mergeCopy(sourcePath, targetPath, createBackup);
  }
);

ipcMain.handle(
  "file:mergeThreeWay",
  (
    _event,
    payload: {
      outputPath: string;
      base: string;
      left: string;
      right: string;
      resolutions: Record<number, "left" | "right" | "base" | "both">;
      createBackup?: boolean;
    }
  ) => {
    const settings = loadSettings();
    const { outputPath, base, left, right, resolutions, createBackup = settings.createBackupOnMerge } =
      payload;
    const merged = applyConflictResolutions(base, left, right, resolutions);
    return writeWithBackup(outputPath, merged, createBackup);
  }
);

ipcMain.handle(
  "patch:export",
  (_event, payload: { fileName: string; left: string; right: string; savePath: string }) => {
    const patch = createUnifiedPatch(payload.fileName, payload.left, payload.right);
    fs.writeFileSync(payload.savePath, patch, "utf8");
    return payload.savePath;
  }
);

ipcMain.handle("patch:parseGit", (_event, text: string) =>
  parseGitDiff(text).map((f) => ({
    ...f,
    stats: diffStats(f.left, f.right),
  }))
);

ipcMain.handle("fs:writeText", (_event, filePath: string, content: string) =>
  writeWithBackup(filePath, content, loadSettings().createBackupOnMerge)
);

if (enforceSingleInstance(() => mainWindow?.focus())) {
  app.whenReady().then(createWindow);

  app.on("window-all-closed", () => {
    if (process.platform !== "darwin") app.quit();
  });

  app.on("activate", () => {
    if (BrowserWindow.getAllWindows().length === 0) createWindow();
  });
}
