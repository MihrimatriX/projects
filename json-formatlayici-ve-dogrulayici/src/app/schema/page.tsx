"use client";

import BrandIcon from "@/components/shell/BrandIcon";
import StatusBar from "@/components/shell/StatusBar";
import ToolbarNav from "@/components/shell/ToolbarNav";
import ValidBadge from "@/components/shell/ValidBadge";
import { useJsonStore } from "@/lib/store";

export default function SchemaPage() {
  const {
    rawJson,
    setRawJson,
    schemaText,
    setSchemaText,
    validateSchema,
    schemaValid,
    schemaErrors,
    isValid,
    loadSampleSchema,
  } = useJsonStore();

  return (
    <div className="app-shell">
      <header className="toolbar">
        <div className="toolbar-brand">
          <BrandIcon />
          Şema Doğrulama
        </div>
        <div className="toolbar-actions">
          <button type="button" className="btn-primary" onClick={validateSchema} disabled={!rawJson.trim() || !schemaText.trim()} title={schemaText.trim() ? "Ctrl+Enter" : "Önce şema girin"}>
            Doğrula
          </button>
          <button type="button" className="btn-ghost" onClick={loadSampleSchema}>
            Örnek şema
          </button>
        </div>
        <div className="toolbar-spacer" />
        <ValidBadge />
        <ToolbarNav active="/schema" />
      </header>

      <main className="secondary-main" id="schema-root" onKeyDown={(e) => { if (e.ctrlKey && e.key === "Enter") { e.preventDefault(); validateSchema(); } }}>
        <div className="split-2">
          <div className="input-panel">
            <label htmlFor="schema-json">JSON verisi</label>
            <textarea
              id="schema-json"
              spellCheck={false}
              value={rawJson}
              onChange={(e) => setRawJson(e.target.value)}
            />
          </div>
          <div className="input-panel">
            <label htmlFor="schema-text">JSON Schema (Draft-07)</label>
            <textarea
              id="schema-text"
              spellCheck={false}
              value={schemaText}
              onChange={(e) => setSchemaText(e.target.value)}
              placeholder='{ "type": "object" }'
            />
          </div>
        </div>
        <div className={`error-panel validation-panel${schemaErrors.length ? " has-errors expanded" : ""}`}>
          <div className="error-panel-handle" role="status" aria-live="polite">
            <span>
              {schemaValid === true && "Şema geçerli"}
              {schemaValid === false && `${schemaErrors.length} şema hatası`}
              {schemaValid === null && "Doğrulama sonuçları"}
            </span>
          </div>
          <div className="error-panel-body">
            {schemaErrors.length === 0 ? (
              <p className="query-hint">{!rawJson.trim() ? "JSON verisi girin." : !isValid ? "Önce geçerli JSON girin." : !schemaText.trim() ? "Şema girin ya da Örnek şema ile başlayın." : "Doğrula butonuna basın (Ctrl+Enter)."}</p>
            ) : (
              <ul className="result-list">
                {schemaErrors.map((e, i) => (
                  <li key={i} className="fail">
                    {e}
                  </li>
                ))}
              </ul>
            )}
          </div>
        </div>
      </main>

      <StatusBar
        left={
          <span className="statusbar-item mono">
            {schemaValid === true ? "OK" : schemaValid === false ? "FAIL" : "-"}
          </span>
        }
        right={<span className="statusbar-item">Schema</span>}
      />
    </div>
  );
}
