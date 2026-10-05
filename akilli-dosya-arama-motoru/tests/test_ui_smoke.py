import pytest
from PySide6.QtWidgets import QApplication

from utils import search_history
from utils.file_search import SearchResult
from utils.settings import save_settings


@pytest.fixture(scope="module")
def app():
    return QApplication.instance() or QApplication([])


def _fail_open(_path):
    raise FileNotFoundError(2, "yok")


def test_spotlight_opens_and_shortcuts(app, tree, monkeypatch):
    from ui import spotlight_window
    from ui.spotlight_window import SpotlightWindow

    save_settings({"search_roots": [str(tree)], "tantivy_primary": False})
    search_history.record_search("rapor", 1, 1)
    w = SpotlightWindow()
    try:
        # Boş kutuda yukarı ok son aramayı getirir
        w._nav_up()
        assert w.panel.search_input.text() == "rapor"

        target = tree / "rapor_2024.txt"
        w._results = [SearchResult(path=target, name=target.name)]
        w._selected = 0
        w._copy_selected_path()
        assert QApplication.clipboard().text() == str(target)

        # Açılamayan dosya: yakalanmayan istisna yerine uyarı
        warned = []
        monkeypatch.setattr(spotlight_window, "open_file", _fail_open)
        monkeypatch.setattr(spotlight_window.QMessageBox, "warning", lambda *a, **k: warned.append(a))
        w._activate_selection()
        assert warned
    finally:
        w.shutdown()
        w.deleteLater()


def test_settings_dialog_opens(app, tree):
    from ui.settings_dialog import SettingsDialog

    save_settings({"search_roots": [str(tree)], "tantivy_primary": False})
    dlg = SettingsDialog()
    dlg.deleteLater()
