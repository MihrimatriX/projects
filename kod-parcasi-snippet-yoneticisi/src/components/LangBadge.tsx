import { langBadgeClass, langBadgeLabel } from "../lib/format";

export function LangBadge({ language }: { language: string }) {
  return (
    <span className={`lang-badge ${langBadgeClass(language)}`} aria-label={`Dil: ${language}`}>
      {langBadgeLabel(language)}
    </span>
  );
}
