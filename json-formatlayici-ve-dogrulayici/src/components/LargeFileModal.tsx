"use client";

import { useJsonStore } from "@/lib/store";

export default function LargeFileModal() {
  const { showLargeFileModal, confirmLargeFileLoad, cancelLargeFileLoad } = useJsonStore();

  if (!showLargeFileModal) return null;

  return (
    <div className="modal-overlay open" role="dialog" aria-modal="true" aria-labelledby="large-file-title">
      <div className="modal">
        <div className="modal-header">
          <h2 className="modal-title" id="large-file-title">
            Büyük dosya uyarısı
          </h2>
        </div>
        <div className="modal-body">
          <p>
            Yüklemeye çalıştığınız JSON dosyası 5 MB&apos;tan büyük. Tarayıcıda işlemek geçici performans
            düşüşüne yol açabilir; tüm işlem yerelde yapılır.
          </p>
          <div className="query-row" style={{ marginTop: 16, justifyContent: "flex-end" }}>
            <button type="button" className="btn-ghost" onClick={cancelLargeFileLoad}>
              İptal
            </button>
            <button type="button" className="btn-primary" onClick={confirmLargeFileLoad}>
              Yine de yükle
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}
