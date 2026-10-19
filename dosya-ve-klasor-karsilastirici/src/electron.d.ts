import type {
  AppSettings,
  CompareProgress,
  CompareResult,
  ConflictResolution,
  FilePairContent,
  ParsedGitDiff,
  ThreeWayContent,
  MergeDirection,
} from "./types";

export type ElectronAPI = {
  pickFolder: () => Promise<string | null>;
  pickFile: () => Promise<string | null>;
  pickPath: () => Promise<string | null>;
  savePatch: (defaultName: string) => Promise<string | null>;
  saveMerged: (defaultName: string) => Promise<string | null>;
  getPathForFile: (file: File) => Promise<string>;
  showItemInFolder: (filePath: string) => Promise<void>;
  getVersion: () => Promise<string>;
  getSettings: () => Promise<AppSettings>;
  saveSettings: (partial: Partial<AppSettings>) => Promise<AppSettings>;
  clearHashCache: (left?: string, right?: string) => Promise<boolean>;
  comparePaths: (left: string, right: string) => Promise<CompareResult>;
  onCompareProgress: (callback: (progress: CompareProgress) => void) => () => void;
  readFilePair: (left: string, right: string, relativePath?: string) => Promise<FilePairContent>;
  readFileTriple: (
    base: string,
    left: string,
    right: string,
    relativePath?: string
  ) => Promise<ThreeWayContent>;
  mergeFile: (payload: {
    left: string;
    right: string;
    relativePath?: string;
    direction: MergeDirection;
    createBackup?: boolean;
  }) => Promise<{ backupPath: string | null }>;
  mergeThreeWay: (payload: {
    outputPath: string;
    base: string;
    left: string;
    right: string;
    resolutions: Record<number, ConflictResolution>;
    createBackup?: boolean;
  }) => Promise<{ outputPath: string; backupPath: string | null }>;
  exportPatch: (payload: {
    fileName: string;
    left: string;
    right: string;
    savePath: string;
  }) => Promise<string>;
  parseGitDiff: (text: string) => Promise<ParsedGitDiff[]>;
  writeTextFile: (
    filePath: string,
    content: string
  ) => Promise<{ outputPath: string; backupPath: string | null }>;
};

declare global {
  interface Window {
    electronAPI: ElectronAPI;
  }
}

export {};
