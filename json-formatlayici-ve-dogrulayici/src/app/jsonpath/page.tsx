"use client";

import { useState } from "react";
import BrandIcon from "@/components/shell/BrandIcon";
import StatusBar from "@/components/shell/StatusBar";
import ToolbarNav from "@/components/shell/ToolbarNav";
import { useJsonStore } from "@/lib/store";

const DEFAULT_SRC = `{
  "store": {
    "book": [
      { "category": "referans", "title": "Sayısal Analiz", "price": 42.5, "stok": true },
      { "category": "roman", "title": "Gece Vardiyası", "price": 18.0, "stok": false }
    ],
    "bisiklet": { "renk": "kırmızı", "fiyat": 299 }
  }
}`;

export default function JsonPathPage() {
  const {
    rawJson,
    setRawJson,
    runJqLiteQuery,
    applyJqResultToEditor,
    jqResult,
    jqError,
    jsonPathQuery,
    setQueryExpression,
    runJsonPathQuery,
    jsonPathError,
  } = useJsonStore();

  const [srcText, setSrcText] = useState(rawJson.trim() || DEFAULT_SRC);

  const syncSource = (text: string) => {
    setSrcText(text);
    setRawJson(text);
  };

  const runQuery = () => {
    try {
      const parsed = JSON.parse(srcText);
      useJsonStore.setState({ rawJson: srcText, parsedJson: parsed, isValid: true, jqError: null });
      runJsonPathQuery();
      runJqLiteQuery();
    } catch {
      useJsonStore.setState({
        rawJson: srcText,
        parsedJson: null,
        isValid: false,
        jqError: "Geçersiz JSON",
        jqResult: null,
      });
    }
  };

  const results: string[] = [];
  if (jqResult !== null && !jqError) {
    if (Array.isArray(jqResult)) jqResult.forEach((v) => results.push(JSON.stringify(v)));
    else results.push(JSON.stringify(jqResult, null, 2));
  }

  return (
    <div className="app-shell">
      <header className="toolbar">
        <div className="toolbar-brand">
          <BrandIcon />
          JSONPath
        </div>
        <div className="toolbar-spacer" />
        <span className="valid-badge valid badge-inline" role="status">
          <span className="dot" aria-hidden />
          jq-lite · eval yok
        </span>
        <ToolbarNav active="/jsonpath" />
      </header>

      <main className="secondary-main" id="jsonpath-main">
        <div className="split-2" id="jsonpath-split">
          <div className="input-panel">
            <label htmlFor="json-src">Kaynak JSON</label>
            <textarea
              id="json-src"
              spellCheck={false}
              value={srcText}
              onChange={(e) => syncSource(e.target.value)}
            />
            <p className="query-hint">Kaynak veri yalnızca bu oturumda kalır.</p>
          </div>

          <div className="split-col-secondary">
            <div className="input-panel query-panel-compact">
              <label htmlFor="json-path">JSONPath sorgusu</label>
              <div className="query-row">
                <input
                  id="json-path"
                  type="text"
                  value={jsonPathQuery}
                  onChange={(e) => setQueryExpression(e.target.value)}
                  onKeyDown={(e) => e.key === "Enter" && runQuery()}
                  spellCheck={false}
                  placeholder="$.store.book[*].title"
                />
                <button type="button" className="btn-primary" onClick={runQuery} disabled={!srcText.trim()}>
                  Sorgula
                </button>
              </div>
              <p className="query-hint">
                <code>$</code> ile başlayan ifade JSONPath, <code>.</code> ile başlayan jq-lite pipeline (ör. <code>.store.book | .[] | .title</code>). <code>eval()</code> çağrılmaz.
              </p>
            </div>
            <div className="result-panel">
              <div className="panel-header">
                <span>Sonuç</span>
              </div>
              {(jqError || jsonPathError) && (
                <p className="query-hint" style={{ color: "var(--error)" }}>
                  {jqError || jsonPathError}
                </p>
              )}
              <ul className="result-list" aria-live="polite">
                {results.length === 0 ? (
                  <li className="empty">{jqResult !== null && !jqError ? "Eşleşme yok" : "Sorgu çalıştırın"}</li>
                ) : (
                  results.map((r, i) => (
                    <li key={i} className="pass">
                      {r}
                    </li>
                  ))
                )}
              </ul>
              {jqResult !== null && !jqError && (
                <button type="button" className="btn-ghost" style={{ margin: 12 }} onClick={applyJqResultToEditor}>
                  Sonucu editöre yaz
                </button>
              )}
            </div>
          </div>
        </div>
      </main>

      <StatusBar
        left={<span className="statusbar-item mono">{jqResult !== null && !jqError ? `${results.length} sonuç` : "- sonuç"}</span>}
        right={<span className="statusbar-item">JSONPath</span>}
      />
    </div>
  );
}
