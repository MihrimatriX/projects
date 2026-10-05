import regexpTree from "regexp-tree";
import type { AstTreeNode, ExplanationBlock } from "./types";

let blockCounter = 0;

function resetCounter() {
  blockCounter = 0;
}

function makeBlock(
  title: string,
  desc: string,
  snippet: string,
  type: ExplanationBlock["type"]
): ExplanationBlock {
  return {
    id: `step-${blockCounter++}`,
    title,
    description: desc,
    snippet,
    type,
  };
}

// eslint-disable-next-line @typescript-eslint/no-explicit-any
export function walkAst(node: any, list: ExplanationBlock[] = []): ExplanationBlock[] {
  if (!node) return list;

  switch (node.type) {
    case "Alternative":
      node.expressions.forEach((expr: unknown) => walkAst(expr, list));
      break;

    case "Assertion":
      if (node.kind === "^") {
        list.push(
          makeBlock(
            "Satır Başlangıcı Assertion (^)",
            "Bir satırın veya metnin başlangıç noktasını eşleştirir. Herhangi bir karakter tüketmez.",
            "^",
            "anchor"
          )
        );
      } else if (node.kind === "$") {
        list.push(
          makeBlock(
            "Satır Bitişi Assertion ($)",
            "Bir satırın veya metnin son noktasını eşleştirir. Herhangi bir karakter tüketmez.",
            "$",
            "anchor"
          )
        );
      } else if (node.kind === "\\b") {
        list.push(
          makeBlock(
            "Kelime Sınırı Assertion (\\b)",
            "Kelime karakteri ile kelime olmayan karakter arasındaki geçiş sınırını eşleştirir.",
            "\\b",
            "anchor"
          )
        );
      } else if (node.kind === "\\B") {
        list.push(
          makeBlock(
            "Kelime Olmayan Sınır Assertion (\\B)",
            "İki kelime karakteri veya iki kelime olmayan karakter arasındaki sınırı eşleştirir.",
            "\\B",
            "anchor"
          )
        );
      } else if (node.kind === "Lookahead") {
        const op = node.negative ? "Negatif İleriye Bakış (!=)" : "Pozitif İleriye Bakış (=)";
        const desc = node.negative
          ? "İlerideki karakterlerin belirtilen kalıba UYMADIĞINI kontrol eder (karakter tüketmez)."
          : "İlerideki karakterlerin belirtilen kalıba UYDUĞUNU doğrular (karakter tüketmez).";
        list.push(makeBlock(op, desc, `${node.negative ? "(?!" : "(?="}... )`, "anchor"));
        walkAst(node.assertion, list);
      }
      break;

    case "Char":
      if (node.kind === "simple") {
        list.push(
          makeBlock(
            `Karakter: '${node.value}'`,
            `Tam olarak '${node.value}' harfini veya rakamını arar.`,
            node.value,
            "char"
          )
        );
      } else if (node.kind === "meta") {
        const metaMap: Record<string, [string, string]> = {
          ".": ["Herhangi Bir Karakter (.)", "Yeni satır hariç herhangi bir tek karakter (s bayrağı ile satır sonu dahil)."],
          "\\d": ["Rakam Karakteri (\\d)", "0-9 arası rakam. [0-9] ile eşdeğer."],
          "\\D": ["Rakam Olmayan Karakter (\\D)", "Rakam olmayan herhangi bir karakter."],
          "\\w": ["Alfanumerik Karakter (\\w)", "Harf, rakam veya alt çizgi. [a-zA-Z0-9_] ile eşdeğer."],
          "\\W": ["Alfanumerik Olmayan Karakter (\\W)", "Harf, rakam ve alt çizgi dışındaki karakterler."],
          "\\s": ["Boşluk Karakteri (\\s)", "Boşluk, tab, yeni satır veya form-feed."],
          "\\S": ["Boşluk Olmayan Karakter (\\S)", "Boşluk dışındaki herhangi bir karakter."],
        };
        const meta = metaMap[node.value];
        if (meta) {
          list.push(makeBlock(meta[0], meta[1], node.value, "meta"));
        } else {
          list.push(
            makeBlock(
              `Kaçış Karakteri (${node.value})`,
              "Özel anlamı olan bir karakteri düz metin olarak eşleştirir.",
              node.value,
              "meta"
            )
          );
        }
      }
      break;

    case "CharacterClass": {
      const sign = node.negative ? "Negatif Karakter Sınıfı ([^...])" : "Karakter Sınıfı ([...])";
      const descClass = node.negative
        ? "Parantez içinde BELİRTİLMEYEN herhangi bir tek karakteri eşleştirir."
        : "Parantez içindeki karakterlerden herhangi bir TEK karakteri eşleştirir.";
      list.push(makeBlock(sign, descClass, node.negative ? "[^...]" : "[...]", "charClass"));
      node.expressions.forEach((expr: unknown) => walkAst(expr, list));
      break;
    }

    case "ClassRange":
      list.push(
        makeBlock(
          `Aralık: '${node.from.value}' ile '${node.to.value}' arası`,
          `Karakter tablosunda '${node.from.value}' ile '${node.to.value}' arasındaki karakterler.`,
          `${node.from.value}-${node.to.value}`,
          "charClass"
        )
      );
      break;

    case "Quantifier":
      appendQuantifierExplanation(node, list);
      walkAst(node.expression, list);
      break;

    case "Repetition":
      appendQuantifierExplanation(node.quantifier, list);
      walkAst(node.expression, list);
      break;

    case "Group": {
      const gTitle = node.capturing
        ? "Yakalama Grubu (Capture Group)"
        : "Yakalanamayan Grup (Non-Capturing Group)";
      const gDesc = node.capturing
        ? `Alt ifadeyi gruplar ve eşleşen veriyi belleğe kaydeder${node.name ? ` ('${node.name}' ismiyle)` : ""}.`
        : "İfadeleri gruplar ancak eşleşen veriyi alt grup olarak saklamaz.";
      list.push(makeBlock(gTitle, gDesc, node.capturing ? "(...)" : "(?:...)", "group"));
      walkAst(node.expression, list);
      break;
    }

    case "Disjunction":
      list.push(
        makeBlock(
          "Alternatif VEYA İşleci (|)",
          "Solundaki ifadeyi VEYA sağındaki ifadeyi eşleştirmeye çalışır.",
          "|",
          "meta"
        )
      );
      walkAst(node.left, list);
      walkAst(node.right, list);
      break;
  }

  return list;
}

// eslint-disable-next-line @typescript-eslint/no-explicit-any
function appendQuantifierExplanation(quantifier: any, list: ExplanationBlock[]) {
  if (!quantifier) return;

  let qName = "Nicelendirici (Quantifier)";
  let qDesc = "";
  let snippet = quantifier.kind;

  if (quantifier.kind === "+") {
    qName = "1 veya Daha Fazla Kez (+)";
    qDesc = "Öncesindeki ifadenin en az 1 kez, olabildiğince çok tekrarlanmasını ister.";
  } else if (quantifier.kind === "*") {
    qName = "0 veya Daha Fazla Kez (*)";
    qDesc = "Öncesindeki ifadenin hiç olmamasını veya olabildiğince çok tekrarlanmasını ister.";
  } else if (quantifier.kind === "?") {
    qName = "0 veya 1 Kez (Opsiyonel) (?)";
    qDesc = "Öncesindeki ifadenin isteğe bağlı olduğunu belirtir.";
  } else if (quantifier.kind === "Range") {
    snippet = `{${quantifier.from}${quantifier.to !== undefined ? `,${quantifier.to}` : ","}}`;
    if (quantifier.from === quantifier.to) {
      qName = `Tam ${quantifier.from} Kez ({${quantifier.from}})`;
      qDesc = `Öncesindeki ifadenin tam olarak ${quantifier.from} kez tekrarlanmasını şart koşar.`;
    } else if (quantifier.to === undefined) {
      qName = `En Az ${quantifier.from} Kez ({${quantifier.from},})`;
      qDesc = `Öncesindeki ifadenin en az ${quantifier.from} kez tekrarlanmasını ister.`;
    } else {
      qName = `${quantifier.from} ile ${quantifier.to} Kez Arası ({${quantifier.from},${quantifier.to}})`;
      qDesc = `Öncesindeki ifadenin en az ${quantifier.from}, en çok ${quantifier.to} kez tekrarlanmasını şart koşar.`;
    }
  }

  list.push(makeBlock(qName, qDesc, snippet, "quantifier"));
}

// eslint-disable-next-line @typescript-eslint/no-explicit-any
function quantifierTreeLabel(quantifier: any): { label: string; snippet: string } {
  const qLabels: Record<string, string> = {
    "+": "1+ kez (+)",
    "*": "0+ kez (*)",
    "?": "0-1 kez (?)",
  };

  if (quantifier?.kind === "Range") {
    return {
      label: `Tekrar {${quantifier.from}${quantifier.to !== undefined ? `,${quantifier.to}` : ","}}`,
      snippet: `{${quantifier.from}${quantifier.to !== undefined ? `,${quantifier.to}` : ","}}`,
    };
  }

  return {
    label: qLabels[quantifier?.kind] || "Quantifier",
    snippet: quantifier?.kind || "?",
  };
}

let treeCounter = 0;

function nextTreeId(prefix: string) {
  return `${prefix}-${treeCounter++}`;
}

// eslint-disable-next-line @typescript-eslint/no-explicit-any
function buildTreeNode(node: any, prefix = "node"): AstTreeNode | null {
  if (!node) return null;
  treeCounter++;

  switch (node.type) {
    case "Alternative":
      return {
        id: nextTreeId(prefix),
        label: "Alternatif",
        type: "Alternative",
        children: node.expressions
          .map((expr: unknown, i: number) => buildTreeNode(expr, `${prefix}-alt-${i}`))
          .filter(Boolean) as AstTreeNode[],
      };

    case "Assertion": {
      const labels: Record<string, string> = {
        "^": "Satır başı (^)",
        $: "Satır sonu ($)",
        "\\b": "Kelime sınırı (\\b)",
        "\\B": "Kelime olmayan sınır (\\B)",
        Lookahead: node.negative ? "Negatif lookahead (?!" : "Pozitif lookahead (?=",
      };
      const child = node.kind === "Lookahead" ? buildTreeNode(node.assertion, `${prefix}-la`) : null;
      return {
        id: nextTreeId(prefix),
        label: labels[node.kind] || `Assertion (${node.kind})`,
        type: "Assertion",
        snippet: node.kind,
        children: child ? [child] : [],
      };
    }

    case "Char":
      return {
        id: nextTreeId(prefix),
        label: node.kind === "simple" ? `Karakter '${node.value}'` : `Meta ${node.value}`,
        type: "Char",
        snippet: node.value,
        children: [],
      };

    case "CharacterClass":
      return {
        id: nextTreeId(prefix),
        label: node.negative ? "Negatif sınıf [^...]" : "Karakter sınıfı [...]",
        type: "CharacterClass",
        children: node.expressions
          .map((expr: unknown, i: number) => buildTreeNode(expr, `${prefix}-cc-${i}`))
          .filter(Boolean) as AstTreeNode[],
      };

    case "ClassRange":
      return {
        id: nextTreeId(prefix),
        label: `Aralık ${node.from.value}-${node.to.value}`,
        type: "ClassRange",
        snippet: `${node.from.value}-${node.to.value}`,
        children: [],
      };

    case "Quantifier": {
      const meta = quantifierTreeLabel(node);
      const child = buildTreeNode(node.expression, `${prefix}-q`);
      return {
        id: nextTreeId(prefix),
        label: meta.label,
        type: "Quantifier",
        snippet: meta.snippet,
        children: child ? [child] : [],
      };
    }

    case "Repetition": {
      const meta = quantifierTreeLabel(node.quantifier);
      const child = buildTreeNode(node.expression, `${prefix}-rep`);
      return {
        id: nextTreeId(prefix),
        label: meta.label,
        type: "Repetition",
        snippet: meta.snippet,
        children: child ? [child] : [],
      };
    }

    case "Group": {
      const child = buildTreeNode(node.expression, `${prefix}-g`);
      return {
        id: nextTreeId(prefix),
        label: node.capturing
          ? node.name
            ? `Yakalama grubu (?<${node.name}>)`
            : "Yakalama grubu (...)"
          : "Non-capturing (?:...)",
        type: "Group",
        children: child ? [child] : [],
      };
    }

    case "Disjunction": {
      return {
        id: nextTreeId(prefix),
        label: "VEYA (|)",
        type: "Disjunction",
        snippet: "|",
        children: [buildTreeNode(node.left, `${prefix}-l`), buildTreeNode(node.right, `${prefix}-r`)].filter(
          Boolean
        ) as AstTreeNode[],
      };
    }

    default:
      return {
        id: nextTreeId(prefix),
        label: node.type || "Düğüm",
        type: node.type || "Unknown",
        children: [],
      };
  }
}

export function parsePatternAst(pattern: string): {
  explanation: ExplanationBlock[];
  astTree: AstTreeNode[];
} {
  resetCounter();
  treeCounter = 0;

  if (!pattern) {
    return { explanation: [], astTree: [] };
  }

  try {
    const ast = regexpTree.parse(`/${pattern}/`);
    const explanation = walkAst(ast.body);
    const root = buildTreeNode(ast.body, "root");
    return {
      explanation,
      astTree: root ? [root] : [],
    };
  } catch {
    return { explanation: [], astTree: [] };
  }
}
