export type BoardSummary = {
  id: string;
  name: string;
  updatedAt: string;
  data?: string;
};

type RecordMap = Record<string, { typeName?: string }>;
type Snapshot = {
  document?: { store?: RecordMap };
  store?: RecordMap;
  records?: { typeName?: string }[];
};

export const MAX_NAME_LENGTH = 120;
export const EXPORT_FORMAT = "gorsel-not-pano";

function parseObject(text: string): Record<string, unknown> | null {
  try {
    const v: unknown = JSON.parse(text);
    return v && typeof v === "object" && !Array.isArray(v) ? (v as Record<string, unknown>) : null;
  } catch {
    return null;
  }
}

/** Kayıtlı tldraw snapshot'ında (getSnapshot: { document: { store: {id: kayıt} } }) en az bir şekil var mı? */
export function snapshotHasShapes(data?: string): boolean {
  if (!data || data === "{}") return false;
  const snap = parseObject(data) as Snapshot | null;
  const records = snap?.document?.store ?? snap?.store;
  return !!records && Object.values(records).some((r) => r?.typeName === "shape");
}

export function isBoardEmpty(data?: string): boolean {
  return !snapshotHasShapes(data);
}

/** Pano adı: kırpılır, boşsa null, uzunsa kısaltılır. */
export function cleanName(value: unknown): string | null {
  if (typeof value !== "string") return null;
  const name = value.trim().slice(0, MAX_NAME_LENGTH);
  return name || null;
}

/** Veritabanına yalnızca JSON nesnesi olan tuval verisi yazılır; bozuk veri kaydı ezmesin. */
export function isSnapshotJson(data: unknown): data is string {
  return typeof data === "string" && parseObject(data) !== null;
}

/** Panoyu dışa aktarma dosyası (JSON) içeriği. */
export function buildExport(name: string, data: string): string {
  return JSON.stringify(
    { format: EXPORT_FORMAT, version: 1, name, snapshot: parseObject(data) ?? {} },
    null,
    2
  );
}

/**
 * İçe aktarılan dosyayı { name, data } yapar. Kabul edilenler: bu uygulamanın dışa aktarımı,
 * ham tldraw snapshot'ı ({ document } / { store, schema }) ve tldraw.com .tldr dosyası ({ records }).
 */
export function parseImport(text: string, fallbackName: string): { name: string; data: string } {
  const obj = parseObject(text);
  if (!obj) throw new Error("Dosya geçerli bir JSON değil.");
  const name = cleanName(obj.name) ?? cleanName(fallbackName) ?? "İçe aktarılan pano";

  let snapshot: unknown = obj;
  if (obj.format === EXPORT_FORMAT) snapshot = obj.snapshot;
  else if (Array.isArray(obj.records) && obj.schema) {
    const records = obj.records as { id?: string }[];
    snapshot = { store: Object.fromEntries(records.map((r) => [r.id, r])), schema: obj.schema };
  }

  const snap = snapshot as Snapshot | null;
  if (!snap || typeof snap !== "object" || !(snap.document?.store || snap.store)) {
    throw new Error("Dosyada tldraw pano verisi bulunamadı.");
  }
  return { name, data: JSON.stringify(snapshot) };
}

export function exportFileName(name: string, ext: string): string {
  const base = name.trim().replace(/[\\/:*?"<>|]+/g, "").replace(/\s+/g, "-") || "pano";
  return `${base}.${ext}`;
}
