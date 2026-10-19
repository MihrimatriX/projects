type Props = { message: string | null; error?: boolean };

export function Toast({ message, error }: Props) {
  return (
    <div className={`toast ${message ? "show" : ""} ${error ? "error" : ""}`} role="status" aria-live="polite">
      {message ?? ""}
    </div>
  );
}
