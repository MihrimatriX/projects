"use client";

import { useEffect, useState } from "react";

type Props = {
  message: string | null;
};

export default function KbdToast({ message }: Props) {
  const [visible, setVisible] = useState(false);

  useEffect(() => {
    if (!message) return;
    setVisible(true);
    const t = setTimeout(() => setVisible(false), 2000);
    return () => clearTimeout(t);
  }, [message]);

  return (
    <div className={`kbd-toast ${visible ? "show" : ""}`} aria-live="polite">
      {message && <span dangerouslySetInnerHTML={{ __html: message }} />}
    </div>
  );
}
