export type FileStatus = "identical" | "different" | "left_only" | "right_only";

export type FileEntry = {
  relativePath: string;
  status: FileStatus;
};

export type FolderCompareResult = {
  mode: "folder";
  entries: FileEntry[];
  leftCount: number;
  rightCount: number;
  leftRoot: string;
  rightRoot: string;
  truncated: boolean;
};

export type FileCompareResult = {
  mode: "file";
  left: string;
  right: string;
};

export type CompareResult = FolderCompareResult | FileCompareResult;

export type DiffStats = {
  additions: number;
  deletions: number;
};

export type FilePairContent = {
  left: string;
  right: string;
  binary: boolean;
  truncated: boolean;
  stats: DiffStats;
  leftPath: string;
  rightPath: string;
  missingSide: "left" | "right" | null;
  leftHex: string | null;
  rightHex: string | null;
  leftSize: number;
  rightSize: number;
  language: string;
};

export type MergeConflict = {
  index: number;
  base: string;
  left: string;
  right: string;
};

export type ThreeWayContent = {
  base: string;
  left: string;
  right: string;
  basePath: string;
  leftPath: string;
  rightPath: string;
  language: string;
  merge: {
    merged: string;
    conflicts: MergeConflict[];
    autoResolved: number;
  };
};

export type MergeDirection = "left-to-right" | "right-to-left";

export type ViewMode = "side-by-side" | "inline" | "three-way" | "hex";

export type ConflictResolution = "left" | "right" | "base" | "both";

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

export type CompareProgress = {
  phase: "hashing";
  current: number;
  total: number;
};

export type ParsedGitDiff = {
  fileName: string;
  left: string;
  right: string;
  stats: DiffStats;
};

export type GitDiffSession = {
  source: "git";
  files: ParsedGitDiff[];
  activeIndex: number;
};
