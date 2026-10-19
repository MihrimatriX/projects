type Props = { message: string; visible: boolean };

export function Toast({ message, visible }: Props) {
  if (!message) return null;
  return (
    <div className={`toast${visible ? " show" : ""}`} role="status" aria-live="polite">
      {message}
    </div>
  );
}
