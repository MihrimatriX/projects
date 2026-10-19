"use client";

import dynamic from "next/dynamic";

const RegexEditor = dynamic(() => import("./RegexEditor"), {
  ssr: false,
  loading: () => (
    <div className="flex-1 h-10 bg-[var(--bg-toolbar)] rounded animate-pulse" aria-hidden="true" />
  ),
});

export default RegexEditor;
