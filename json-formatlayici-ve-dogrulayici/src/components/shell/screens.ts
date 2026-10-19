export const APP_SCREENS = [
  { href: "/", label: "Ekranlar" },
  { href: "/lab", label: "Lab" },
  { href: "/jsonpath", label: "JSONPath" },
  { href: "/schema", label: "Şema" },
  { href: "/diff", label: "Diff" },
  { href: "/file", label: "Dosya" },
] as const;

export type AppScreenHref = (typeof APP_SCREENS)[number]["href"];
