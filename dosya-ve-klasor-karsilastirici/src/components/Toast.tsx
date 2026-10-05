import { useEffect } from "react";

type Props = {
  message: string;
  onDone: () => void;
};

export function Toast({ message, onDone }: Props) {
  useEffect(() => {
    const t = setTimeout(onDone, 2200);
    return () => clearTimeout(t);
  }, [message, onDone]);

  return (
    <div className="toast show" role="status">
      {message}
    </div>
  );
}
