import { useCallback, useEffect, useRef, useState } from "react";

export function useToast(durationMs = 2000) {
  const [message, setMessage] = useState("");
  const [visible, setVisible] = useState(false);
  const timer = useRef<ReturnType<typeof setTimeout> | undefined>(undefined);

  const show = useCallback(
    (msg: string) => {
      setMessage(msg);
      setVisible(true);
      clearTimeout(timer.current);
      timer.current = setTimeout(() => setVisible(false), durationMs);
    },
    [durationMs]
  );

  useEffect(() => () => clearTimeout(timer.current), []);

  return { message, visible, show };
}
