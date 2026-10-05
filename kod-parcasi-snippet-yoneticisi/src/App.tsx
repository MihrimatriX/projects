import { useEffect, useState } from "react";
import { ImportExportModal } from "./components/ImportExportModal";
import { MainWindow } from "./components/MainWindow";
import { PaletteView } from "./components/PaletteView";

function App() {
  // Aynı React paketi iki pencerede çalışır; #palette hash'i küçük arama paletini seçer
  const isPalette = window.location.hash === "#palette";
  const [importExportOpen, setImportExportOpen] = useState(false);
  const [refreshToken, setRefreshToken] = useState(0);

  useEffect(() => {
    document.body.classList.toggle("view-palette", isPalette);
    document.body.classList.toggle("view-main", !isPalette);
    return () => {
      document.body.classList.remove("view-palette", "view-main");
    };
  }, [isPalette]);

  if (isPalette) {
    return <PaletteView />;
  }

  return (
    <>
      <MainWindow
        refreshToken={refreshToken}
        onOpenImportExport={() => setImportExportOpen(true)}
      />
      <ImportExportModal
        open={importExportOpen}
        onClose={() => setImportExportOpen(false)}
        // Modal açık kalır: içindeki bildirim (kaç snippet eklendi) görünsün.
        onImported={() => setRefreshToken((t) => t + 1)}
      />
    </>
  );
}

export default App;
