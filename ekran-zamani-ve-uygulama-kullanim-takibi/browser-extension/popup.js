const portInput = document.getElementById("port");
const status = document.getElementById("status");

chrome.storage.local.get(["bridgePort"], (data) => {
  if (data.bridgePort) portInput.value = data.bridgePort;
});

document.getElementById("save").addEventListener("click", async () => {
  const port = parseInt(portInput.value, 10) || 47123;
  await chrome.storage.local.set({ bridgePort: port });
  status.textContent = `Port ${port} kaydedildi.`;
  try {
    const res = await fetch(`http://127.0.0.1:${port}/api/health`);
    status.textContent += res.ok ? " Köprü bağlı." : " Köprü yanıt vermedi.";
  } catch {
    status.textContent += " Uygulama çalışmıyor olabilir.";
  }
});
