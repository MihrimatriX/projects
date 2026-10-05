import { analyzeRedosRisk, MATCH_TIMEOUT_MS } from "../redos";
import { evaluateRegex } from "./evaluate";
import type { EvaluateResult } from "./types";

const WORKER_TEXT_THRESHOLD = 5000;

type Pending = {
  msg: { id: number; pattern: string; flags: string; testText: string; replaceText: string };
  done: (result: EvaluateResult | null) => void;
  timer?: ReturnType<typeof setTimeout>;
};

let worker: Worker | null = null;
let pendingId = 0;
const pending = new Map<number, Pending>();

function getWorker(): Worker {
  if (!worker) {
    worker = new Worker(new URL("../../workers/regex-match.worker.ts", import.meta.url));
    worker.onmessage = (event: MessageEvent<{ id: number; result: EvaluateResult }>) => {
      const { id, result } = event.data;
      const p = pending.get(id);
      if (!p) return;
      clearTimeout(p.timer);
      pending.delete(id);
      p.done(result);
    };
  }
  return worker;
}

function post(id: number) {
  const p = pending.get(id);
  if (!p) return;
  p.timer = setTimeout(() => onTimeout(id), MATCH_TIMEOUT_MS + 1000);
  getWorker().postMessage(p.msg);
}

// Tek bir exec() çağrısı (felaket geri izleme) worker'ı sonsuza dek kilitleyebilir; içerideki
// süre kontrolü buna yetişmez. Süre dolunca worker öldürülür, bekleyen diğer istekler yeni worker'a aktarılır.
function onTimeout(id: number) {
  worker?.terminate();
  worker = null;
  const p = pending.get(id);
  pending.delete(id);
  p?.done(null);
  for (const [otherId, other] of pending) {
    clearTimeout(other.timer);
    post(otherId);
  }
}

export function shouldUseMatchWorker(pattern: string, testText: string): boolean {
  if (typeof window === "undefined") return false;
  const { risk } = analyzeRedosRisk(pattern);
  return testText.length > WORKER_TEXT_THRESHOLD || risk !== "low";
}

export function evaluateInWorker(
  pattern: string,
  flags: string,
  testText: string,
  replaceText: string
): Promise<EvaluateResult> {
  if (typeof window === "undefined") {
    return Promise.resolve(evaluateRegex(pattern, flags, testText, replaceText));
  }

  return new Promise((resolve) => {
    const id = ++pendingId;
    pending.set(id, {
      msg: { id, pattern, flags, testText, replaceText },
      done: (result) =>
        resolve(
          result ?? {
            ...evaluateRegex("", flags, testText, replaceText),
            redosRisk: analyzeRedosRisk(pattern).risk,
            redosReasons: analyzeRedosRisk(pattern).reasons,
            matchTimedOut: true,
          }
        ),
    });
    post(id);
  });
}

export async function runEvaluation(
  pattern: string,
  flags: string,
  testText: string,
  replaceText: string
): Promise<EvaluateResult> {
  if (shouldUseMatchWorker(pattern, testText)) {
    return evaluateInWorker(pattern, flags, testText, replaceText);
  }
  return evaluateRegex(pattern, flags, testText, replaceText);
}
