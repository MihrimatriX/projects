import { evaluateRegex } from "../lib/regex/evaluate";
import type { EvaluateResult } from "../lib/regex/types";

export type WorkerRequest = {
  id: number;
  pattern: string;
  flags: string;
  testText: string;
  replaceText: string;
};

export type WorkerResponse = {
  id: number;
  result: EvaluateResult;
};

self.onmessage = (event: MessageEvent<WorkerRequest>) => {
  const { id, pattern, flags, testText, replaceText } = event.data;
  const result = evaluateRegex(pattern, flags, testText, replaceText);
  const response: WorkerResponse = { id, result };
  self.postMessage(response);
};
