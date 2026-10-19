type Props = { method: string; className?: string };

const METHOD_CLASS: Record<string, string> = {
  GET: "method-get",
  POST: "method-post",
  PUT: "method-put",
  PATCH: "method-patch",
  DELETE: "method-delete",
};

export function MethodBadge({ method, className = "" }: Props) {
  const key = method.toUpperCase();
  const variant = METHOD_CLASS[key] ?? "method-other";
  return <span className={`method-badge ${variant} ${className}`.trim()}>{key}</span>;
}
