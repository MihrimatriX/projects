function msg(text, ok = true) {
  const el = document.getElementById("msg");
  el.textContent = text;
  el.style.color = ok ? "var(--success)" : "var(--danger)";
}

document.getElementById("export-btn").onclick = async () => {
  const { clips = [] } = await chrome.runtime.sendMessage({ type: "EXPORT_CLIPS" });
  const blob = new Blob([JSON.stringify(clips, null, 2)], { type: "application/json" });
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = `kayitli-okuma-${new Date().toISOString().slice(0, 10)}.json`;
  a.click();
  URL.revokeObjectURL(url);
  msg(`${clips.length} kayıt indirildi.`);
};

document.getElementById("import-file").onchange = async (e) => {
  const file = e.target.files?.[0];
  if (!file) return;
  try {
    const data = JSON.parse(await file.text());
    const payload = Array.isArray(data) ? data : data;
    const { imported } = await chrome.runtime.sendMessage({ type: "IMPORT_CLIPS", data: payload });
    msg(`${imported} yeni kayıt içe aktarıldı.`);
  } catch {
    msg("Geçersiz JSON dosyası.", false);
  }
  e.target.value = "";
};

document.getElementById("delete-all").onclick = async () => {
  if (!confirm("Tüm veriler silinecek. Emin misiniz?")) return;
  await chrome.runtime.sendMessage({ type: "DELETE_ALL" });
  msg("Tüm veriler silindi.");
};
