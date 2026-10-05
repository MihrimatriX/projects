import sys
from pathlib import Path

if getattr(sys, "frozen", False):
    _ROOT = Path(sys.executable).resolve().parent
else:
    _ROOT = Path(__file__).resolve().parent
    sys.path.insert(0, str(_ROOT))

from PySide6.QtWidgets import QApplication, QMessageBox, QSystemTrayIcon

from ui.settings_dialog import SettingsDialog
from ui.spotlight_window import SpotlightWindow
from ui import theme as T
from ui.tray_menu import TrayMenu
from utils.actions import IndexBuildWorker
from utils.hotkey import HotkeyPoller
from utils.index_backend import get_index_stats
from utils.index_watcher import IndexWatcher
from utils.scheduled_reindex import ScheduledReindexService
from utils.settings import get_search_roots
from utils.tray_icon import create_tray_icon


def _is_frozen() -> bool:
    return getattr(sys, "frozen", False)


def _format_index_label(count: int) -> str:
    return f"Güncel · {count:,}".replace(",", ".") + " dosya"


def _tray_index_label() -> str:
    count = get_index_stats().get("count", 0)
    return _format_index_label(count) if count > 0 else "Hazır"


def main() -> None:
    # Uygulama tepside yaşar: pencere kapanınca çıkmaz. Ağır işler (arama, indeks
    # kurma, dosya sayma) QThread'lerde; watcher ve zamanlayıcı ana thread'de çalışır.
    app = QApplication(sys.argv)
    app.setStyle("Fusion")
    app.setStyleSheet(T.GLOBAL_STYLESHEET)
    app.setQuitOnLastWindowClosed(False)
    app.setApplicationName("Akıllı Dosya Arama")

    window = SpotlightWindow()

    watcher = IndexWatcher(app)
    watcher.index_count_changed.connect(window.on_index_count_changed)
    watcher.indexing.connect(window.on_index_sync)
    watcher.start()
    window.set_index_watcher(watcher)

    scheduler = ScheduledReindexService(app)
    scheduler.started.connect(lambda: window.on_index_sync(True))
    scheduler.finished.connect(window.on_index_count_changed)
    scheduler.finished.connect(lambda _c: window.on_index_sync(False))
    scheduler.failed.connect(lambda _m: window.panel.set_index_state(label="İndeks hatası", error=True))
    scheduler.start()

    tray = QSystemTrayIcon(create_tray_icon(), app)
    tray.setToolTip("Akıllı Dosya Arama — Ctrl+Space")
    menu = TrayMenu()
    tray.setContextMenu(menu)

    index_worker: IndexBuildWorker | None = None

    watcher.index_count_changed.connect(
        lambda count: menu.update_index_status(_format_index_label(count))
    )
    scheduler.finished.connect(
        lambda count: menu.update_index_status(_format_index_label(count))
    )

    def _sync_tray_indexing(busy: bool) -> None:
        if busy:
            menu.update_index_status("Taranıyor…", scanning=True)
        else:
            menu.update_index_status(_tray_index_label())

    watcher.indexing.connect(_sync_tray_indexing)
    scheduler.started.connect(lambda: menu.update_index_status("Taranıyor…", scanning=True))
    scheduler.failed.connect(lambda _m: menu.update_index_status("İndeks hatası", error=True))

    menu.open_search_action.triggered.connect(window.toggle)

    def _open_settings() -> None:
        dlg = SettingsDialog(window)
        if dlg.exec():
            window._reload_roots()
            window._refresh_index_badge_from_stats(scanning=True)
            window._start_index_count()
            if window._watcher is not None:
                window._watcher.restart(window._search_roots)
            window._run_search()
            menu._refresh_index_info()

    menu.open_settings_action.triggered.connect(_open_settings)

    def _on_tray_reindex_done(count: int) -> None:
        menu.update_index_status(_format_index_label(count))
        menu.reindex_action.setEnabled(True)
        window.on_index_count_changed(count)
        menu._refresh_index_info()

    def _on_tray_reindex_failed(msg: str) -> None:
        menu.update_index_status("İndeks hatası", error=True)
        menu.reindex_action.setEnabled(True)
        QMessageBox.warning(None, "İndeks hatası", msg)

    def _rebuild_from_tray() -> None:
        nonlocal index_worker
        roots = [Path(p) for p in get_search_roots()]
        if not roots:
            QMessageBox.warning(None, "Uyarı", "Önce ayarlardan en az bir klasör ekleyin.")
            return
        if index_worker and index_worker.isRunning():
            return
        menu.update_index_status("Taranıyor…", scanning=True)
        menu.reindex_action.setEnabled(False)
        index_worker = IndexBuildWorker(roots, app)
        index_worker.finished_count.connect(_on_tray_reindex_done)
        index_worker.failed.connect(_on_tray_reindex_failed)
        index_worker.start()

    menu.reindex_action.triggered.connect(_rebuild_from_tray)
    menu.quit_action.triggered.connect(app.quit)

    def _tray_activated(reason: QSystemTrayIcon.ActivationReason) -> None:
        if reason == QSystemTrayIcon.ActivationReason.DoubleClick:
            window.toggle()

    tray.activated.connect(_tray_activated)
    tray.show()
    menu.update_index_status(_tray_index_label())
    tray.showMessage(
        "Akıllı Dosya Arama",
        "Ctrl+Space ile açın · Esc veya dışarı tıklayınca kapanır",
        QSystemTrayIcon.MessageIcon.Information,
        4000,
    )

    hotkey: HotkeyPoller | None = None
    if HotkeyPoller is not None:
        hotkey = HotkeyPoller(window.toggle, app)
        if not hotkey.register():
            print("Uyarı: Ctrl+Space kısayolu kaydedilemedi.", file=sys.stderr)

    if "--show" in sys.argv or (_is_frozen() and "--background" not in sys.argv):
        window.present()
    elif not _is_frozen():
        print(
            "Arka planda calisiyor. Ctrl+Space ile acin; cikis icin tepsi menusu.",
            flush=True,
        )

    code = app.exec()
    scheduler.stop()
    watcher.stop()
    if hotkey is not None:
        hotkey.unregister()
    if index_worker and index_worker.isRunning():
        index_worker.cancel()
        index_worker.wait(2000)
    window.shutdown()
    sys.exit(code)


if __name__ == "__main__":
    main()
