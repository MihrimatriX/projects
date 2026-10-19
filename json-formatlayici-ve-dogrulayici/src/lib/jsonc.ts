/** JSONC: satır ve blok yorumlarını kaldırır; string literal'lara dokunmaz. */
export function stripJsonc(text: string): string {
  let out = "";
  let i = 0;
  const len = text.length;

  while (i < len) {
    const ch = text[i];

    if (ch === '"') {
      out += ch;
      i++;
      while (i < len) {
        const c = text[i];
        out += c;
        if (c === "\\" && i + 1 < len) {
          out += text[i + 1];
          i += 2;
          continue;
        }
        if (c === '"') {
          i++;
          break;
        }
        i++;
      }
      continue;
    }

    if (ch === "/" && text[i + 1] === "/") {
      i += 2;
      while (i < len && text[i] !== "\n") i++;
      continue;
    }

    if (ch === "/" && text[i + 1] === "*") {
      i += 2;
      while (i < len && !(text[i] === "*" && text[i + 1] === "/")) i++;
      i += 2;
      continue;
    }

    out += ch;
    i++;
  }

  return out;
}

export function looksLikeJsonc(text: string): boolean {
  return /\/\/|\/\*/.test(text);
}
