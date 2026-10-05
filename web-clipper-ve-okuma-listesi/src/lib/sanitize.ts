import createDOMPurify from "dompurify";
import { JSDOM } from "jsdom";

// Sunucu tarafı: DOMPurify, Readability'nin de kullandığı tek jsdom kopyası üzerinde çalışır
// (isomorphic-dompurify ikinci bir jsdom sürümü getiriyor, masaüstü paketinde çakışıyordu).
const DOMPurify = createDOMPurify(new JSDOM("").window);

export const PURIFY_CONFIG = {
  ALLOWED_TAGS: [
    "p", "br", "strong", "em", "b", "i", "u", "a", "ul", "ol", "li",
    "h1", "h2", "h3", "h4", "h5", "h6", "blockquote", "pre", "code",
    "img", "figure", "figcaption", "span", "div", "sub", "sup", "hr", "mark",
  ],
  ALLOWED_ATTR: ["href", "src", "alt", "title", "class", "id", "data-highlight-id"],
};

export function sanitizeHtml(html: string): string {
  return DOMPurify.sanitize(html, PURIFY_CONFIG);
}

export function stripDangerous(html: string): string {
  const sanitized = sanitizeHtml(html);
  return sanitized.toLowerCase().includes("<script") ? "" : sanitized;
}
