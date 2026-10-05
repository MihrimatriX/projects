/** Yaygın JSON hatalarını düzeltmeye çalışır (yorum/trailing comma yok). */
export function repairJson(text: string): string {
  let out = text.trim();

  // Tek tırnaklu anahtarları çift tırnağa (basit durumlar)
  out = out.replace(/([{,]\s*)'([^'\\]+)'\s*:/g, '$1"$2":');
  out = out.replace(/:\s*'([^'\\]*)'/g, ': "$1"');

  // Trailing comma: ,} ve ,]
  out = out.replace(/,(\s*[}\]])/g, "$1");

  // BOM
  if (out.charCodeAt(0) === 0xfeff) {
    out = out.slice(1);
  }

  return out;
}
