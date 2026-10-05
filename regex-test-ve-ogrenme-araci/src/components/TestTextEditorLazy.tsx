"use client";

import dynamic from "next/dynamic";

const TestTextEditor = dynamic(() => import("./TestTextEditor"), {
  ssr: false,
  loading: () => (
    <div className="absolute inset-0 bg-[var(--bg-editor)] animate-pulse" aria-hidden="true" />
  ),
});

export default TestTextEditor;
