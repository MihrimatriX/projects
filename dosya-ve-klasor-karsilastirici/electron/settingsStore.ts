import fs from "fs";
import os from "os";
import path from "path";
import { DEFAULT_IGNORE } from "./compareLogic";

export type RecentPair = {
  left: string;
  right: string;
  at: number;
};

export type AppSettings = {
  extraIgnoreDirs: string[];
  createBackupOnMerge: boolean;
  defaultViewMode: "side-by-side" | "inline";
  useGitignore: boolean;
  lastLeftPath: string;
  lastRightPath: string;
  lastBasePath: string;
  recentPairs: RecentPair[];
  theme: "dark" | "light";
};

const DEFAULT_SETTINGS: AppSettings = {
  extraIgnoreDirs: [],
  createBackupOnMerge: true,
  defaultViewMode: "side-by-side",
  useGitignore: true,
  lastLeftPath: "",
  lastRightPath: "",
  lastBasePath: "",
  recentPairs: [],
  theme: "dark",
};

const MAX_RECENT = 8;

export function pushRecentPair(left: string, right: string): AppSettings {
  const s = loadSettings();
  const filtered = s.recentPairs.filter((p) => p.left !== left || p.right !== right);
  const recentPairs: RecentPair[] = [{ left, right, at: Date.now() }, ...filtered].slice(0, MAX_RECENT);
  return saveSettings({ recentPairs, lastLeftPath: left, lastRightPath: right });
}

export function settingsDir(): string {
  const base =
    process.platform === "win32"
      ? path.join(process.env.LOCALAPPDATA ?? os.homedir(), "DosyaKarsilastirici")
      : path.join(os.homedir(), ".config", "dosya-karsilastirici");
  fs.mkdirSync(base, { recursive: true });
  return base;
}

export function settingsPath(): string {
  return path.join(settingsDir(), "settings.json");
}

export function loadSettings(): AppSettings {
  try {
    const raw = fs.readFileSync(settingsPath(), "utf8");
    return { ...DEFAULT_SETTINGS, ...JSON.parse(raw) };
  } catch {
    return { ...DEFAULT_SETTINGS };
  }
}

export function saveSettings(partial: Partial<AppSettings>): AppSettings {
  const next = { ...loadSettings(), ...partial };
  fs.writeFileSync(settingsPath(), JSON.stringify(next, null, 2), "utf8");
  return next;
}

export function allIgnoreDirs(settings: AppSettings): string[] {
  return [...DEFAULT_IGNORE, ...settings.extraIgnoreDirs];
}
