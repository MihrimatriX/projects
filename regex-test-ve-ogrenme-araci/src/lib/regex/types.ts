export interface MatchGroup {
  index: number;
  value: string;
  name?: string;
  /** Present when `d` (hasIndices) flag is enabled. */
  start?: number;
  end?: number;
}

export interface RegexMatch {
  index: number;
  length: number;
  value: string;
  line: number;
  column: number;
  groups: MatchGroup[];
}

export type ExplanationType =
  | "meta"
  | "quantifier"
  | "group"
  | "charClass"
  | "anchor"
  | "char";

export interface ExplanationBlock {
  id: string;
  title: string;
  description: string;
  snippet: string;
  type: ExplanationType;
  /** Test metninden ilgili bağlam parçası (debugger). */
  contextSnippet?: string;
}

export interface AstTreeNode {
  id: string;
  label: string;
  type: string;
  snippet?: string;
  children: AstTreeNode[];
}

export interface RegexPreset {
  id: string;
  name: string;
  pattern: string;
  flags: string;
  testText: string;
  description: string;
}

export interface EvaluateResult {
  isValid: boolean;
  error: string | null;
  matches: RegexMatch[];
  explanation: ExplanationBlock[];
  astTree: AstTreeNode[];
  replacedText: string;
  redosRisk: import("../redos").RedosRisk;
  redosReasons: string[];
  matchTimedOut: boolean;
  flavorWarnings: import("./flavor").FlavorWarning[];
  globalMatchHint: number | null;
}
