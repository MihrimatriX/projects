export interface CheatsheetItem {
  code: string;
  title: string;
  desc: string;
  example?: string;
}

export interface CheatsheetCategory {
  id: string;
  title: string;
  icon: string;
  items: CheatsheetItem[];
}

export const CHEATSHEET_CATEGORIES: CheatsheetCategory[] = [
  {
    id: "basics",
    title: "Temel Meta Karakterler",
    icon: "🔤",
    items: [
      {
        code: ".",
        title: "Herhangi bir karakter",
        desc: "Yeni satır hariç tek karakter eşleştirir. `s` bayrağı ile nokta yeni satırı da kapsar.",
        example: "a.c → abc, a9c",
      },
      {
        code: "\\d \\D",
        title: "Rakam / rakam değil",
        desc: "\\d = [0-9], \\D = rakam olmayan her şey.",
        example: "\\d{3} → 123",
      },
      {
        code: "\\w \\W",
        title: "Kelime karakteri",
        desc: "\\w = harf, rakam, alt çizgi. \\W = bunların dışı.",
        example: "\\w+ → Merhaba",
      },
      {
        code: "\\s \\S",
        title: "Boşluk karakterleri",
        desc: "Boşluk, tab, satır sonu vs. \\S bunların tersi.",
        example: "\\s+ → boşluk dizisi",
      },
    ],
  },
  {
    id: "anchors",
    title: "Çapalar & Sınırlar",
    icon: "⚓",
    items: [
      {
        code: "^",
        title: "Satır/metin başı",
        desc: "`m` bayrağı ile her satırın başında, yoksa tüm metnin başında.",
        example: "^Merhaba → satır başında Merhaba",
      },
      {
        code: "$",
        title: "Satır/metin sonu",
        desc: "Satır veya metin sonunu işaretler, karakter tüketmez.",
        example: "dünya$ → ...dünya",
      },
      {
        code: "\\b \\B",
        title: "Kelime sınırı",
        desc: "\\b kelime ile boşluk/noktalama arası geçiş. \\B tersi.",
        example: "\\bcat\\b → 'cat' kelimesi",
      },
    ],
  },
  {
    id: "quantifiers",
    title: "Nicelendiriciler",
    icon: "🔢",
    items: [
      {
        code: "* + ?",
        title: "Greedy tekrar",
        desc: "* = 0+, + = 1+, ? = 0 veya 1. Varsayılan olarak mümkün olduğunca çok eşleşir.",
        example: "a+ → a, aa, aaa",
      },
      {
        code: "*? +? ??",
        title: "Lazy (tembel) tekrar",
        desc: "Mümkün olan en az eşleşmeyi tercih eder.",
        example: "<.+?> → en kısa etiket",
      },
      {
        code: "{n,m}",
        title: "Aralıklı tekrar",
        desc: "Tam n, en az n, veya n ile m arası tekrar.",
        example: "\\d{2,4} → 12, 123, 1234",
      },
    ],
  },
  {
    id: "groups",
    title: "Gruplar & Lookahead",
    icon: "📦",
    items: [
      {
        code: "(...)",
        title: "Yakalama grubu",
        desc: "Eşleşen alt dizeyi $1, $2 ile replace'te kullanın.",
        example: "(\\w+)@(\\w+) → kullanıcı@domain",
      },
      {
        code: "(?:...)",
        title: "Non-capturing",
        desc: "Gruplar ama numaralandırılmaz; sadece birlikte eşleştirmek için.",
        example: "(?:https?://)[^\\s]+",
      },
      {
        code: "(?=...) (?=...)",
        title: "Pozitif lookahead",
        desc: "İlerideki metin kalıba uymalı; karakter tüketmez.",
        example: "\\w+(?=\\.) → noktadan önceki kelime",
      },
      {
        code: "(?!...) (?<=...)",
        title: "Negatif / geri bakış",
        desc: "JS: (?!...) negatif lookahead. (?<=...) pozitif lookbehind (ES2018+).",
        example: "foo(?!bar) → foo ama foobar değil",
      },
      {
        code: "(?<name>...)",
        title: "İsimli grup",
        desc: "Yakalanan değere isim verir; replace'te $<name> kullanılır.",
        example: "(?<user>\\w+)@ → $<user>",
      },
    ],
  },
  {
    id: "charclass",
    title: "Karakter Sınıfları",
    icon: "🎨",
    items: [
      {
        code: "[abc]",
        title: "Basit sınıf",
        desc: "Köşeli parantez içindeki karakterlerden biri.",
        example: "[aeiou] → sesli harf",
      },
      {
        code: "[^abc]",
        title: "Olumsuz sınıf",
        desc: "Listede olmayan bir karakter.",
        example: "[^0-9] → rakam olmayan",
      },
      {
        code: "[a-zA-Z0-9]",
        title: "Aralık",
        desc: "Tire ile karakter aralığı tanımlanır.",
        example: "[A-F0-9] → hex digit",
      },
    ],
  },
  {
    id: "flags",
    title: "Bayraklar (Flags)",
    icon: "🚩",
    items: [
      {
        code: "g",
        title: "Global",
        desc: "Tüm eşleşmeleri bulur; yoksa yalnızca ilk eşleşme.",
        example: "/a/g → tüm 'a' harfleri",
      },
      {
        code: "i",
        title: "Ignore case",
        desc: "Büyük/küçük harf duyarsız eşleşme.",
        example: "/abc/i → ABC, Abc",
      },
      {
        code: "m",
        title: "Multiline",
        desc: "^ ve $ her satır için çalışır.",
        example: "/^\\d+/gm → satır başı rakam",
      },
      {
        code: "s u y d",
        title: "Dotall, Unicode, Sticky, Indices",
        desc: "s: . satır sonu | u: Unicode | y: lastIndex'ten | d: grup indeksleri (indices).",
        example: "/(\\w+)@(\\w+)/d → grup konumları",
      },
    ],
  },
  {
    id: "replace",
    title: "Replace İpuçları",
    icon: "⚡",
    items: [
      {
        code: "$1 $2",
        title: "Grup referansı",
        desc: "Yakalama gruplarını yer değiştirmede kullanın.",
        example: "s/(\\w+)@/[$1]/ → [kullanıcı]@",
      },
      {
        code: "$&",
        title: "Tüm eşleşme",
        desc: "Eşleşen tam metni referans alır.",
        example: "s/\\d+/[$&] → [42]",
      },
      {
        code: "$` $'",
        title: "Öncesi / sonrası",
        desc: "Eşleşmeden önceki ve sonraki metin.",
        example: "Gelişmiş replace senaryoları",
      },
    ],
  },
];
