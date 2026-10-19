"use client";

import { useEffect, useState } from "react";
import { formatRelative } from "@/lib/format";

/** Date.now() tabanlı metin — yalnızca mount sonrası render (hydration güvenli) */
export default function RelativeTime({ date }: { date: string | Date }) {
  const [text, setText] = useState("");

  useEffect(() => {
    const tick = () => setText(formatRelative(date));
    tick();
    const id = setInterval(tick, 60_000);
    return () => clearInterval(id);
  }, [date]);

  return <span suppressHydrationWarning>{text}</span>;
}
