import { useCallback, useRef, useState } from "react";

export function useToast() {
  const [message, setMessage] = useState<string | null>(null);
  const [error, setError] = useState(false);
  const timer = useRef<ReturnType<typeof setTimeout>>(undefined);

  const show = useCallback((msg: string, isError = false) => {
    clearTimeout(timer.current);
    setMessage(msg);
    setError(isError);
    timer.current = setTimeout(() => {
      setMessage(null);
      setError(false);
    }, 2400);
  }, []);

  return { message, error, show };
}
