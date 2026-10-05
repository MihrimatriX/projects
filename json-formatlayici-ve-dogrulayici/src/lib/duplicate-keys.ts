/** Aynı nesne içinde tekrarlanan anahtarları metin taramasıyla bulur (JSON.parse son anahtarı tutar). */
export interface DuplicateKeyHit {
  key: string;
  line: number;
}

export function findDuplicateKeys(json: string): DuplicateKeyHit[] {
  const hits: DuplicateKeyHit[] = [];
  const stack: Map<string, number>[] = [];
  let depth = 0;
  let line = 1;
  let i = 0;
  let inString = false;
  let stringChar = '"';
  let expectingKey = false;
  // Açık kapsayıcılar ("{" / "["): dizi içindeki virgülden sonra gelen string anahtar sanılmasın.
  const containers: string[] = [];

  const pushObject = () => {
    depth++;
    stack.push(new Map());
    containers.push("{");
    expectingKey = true;
  };

  const popObject = () => {
    stack.pop();
    containers.pop();
    depth = Math.max(0, depth - 1);
    expectingKey = false;
  };

  while (i < json.length) {
    const ch = json[i];

    if (ch === "\n") {
      line++;
      i++;
      continue;
    }

    if (inString) {
      if (ch === "\\" && i + 1 < json.length) {
        i += 2;
        continue;
      }
      if (ch === stringChar) inString = false;
      i++;
      continue;
    }

    if (ch === '"' || ch === "'") {
      if (expectingKey && stack.length > 0) {
        const start = i + 1;
        i++;
        while (i < json.length) {
          const c = json[i];
          if (c === "\\") {
            i += 2;
            continue;
          }
          if (c === ch) break;
          i++;
        }
        const key = json.slice(start, i);
        const map = stack[stack.length - 1];
        if (map.has(key)) {
          hits.push({ key, line: map.get(key) ?? line });
          hits.push({ key, line });
        } else {
          map.set(key, line);
        }
        expectingKey = false;
        i++;
        continue;
      }
      inString = true;
      stringChar = ch;
      i++;
      continue;
    }

    if (ch === "{") {
      pushObject();
      i++;
      continue;
    }

    if (ch === "}") {
      popObject();
      i++;
      continue;
    }

    if (ch === "[") containers.push("[");
    if (ch === "]") containers.pop();

    if (ch === "," && containers[containers.length - 1] === "{") {
      expectingKey = true;
    }

    if (ch === ":") {
      expectingKey = false;
    }

    i++;
  }

  const seen = new Set<string>();
  return hits.filter((h) => {
    const id = `${h.key}:${h.line}`;
    if (seen.has(id)) return false;
    seen.add(id);
    return true;
  });
}
