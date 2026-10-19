from __future__ import annotations

from utils import config


def test_settings_and_history_persist_atomically():
    assert config.load_config()["settings"]["robots_check"] is True
    config.update_settings({"max_rows": 42})
    assert config.get_settings()["max_rows"] == 42
    for i in range(25):
        config.push_history({"url": f"https://x.test/{i}"})
    hist = config.get_history()
    assert len(hist) == 20 and hist[0]["url"] == "https://x.test/24"
    assert not config._CONFIG_FILE.with_suffix(".tmp").exists()

    config.update_settings({"save_history": False})
    config.push_history({"url": "yok"})
    assert config.get_history()[0]["url"] == "https://x.test/24"


def test_corrupt_config_falls_back_to_defaults():
    config._CONFIG_FILE.write_text("{bozuk", encoding="utf-8")
    assert config.get_settings()["max_rows"] == config.DEFAULT_SETTINGS["max_rows"]
    assert config.resolve_user_agent({"user_agent": "custom", "custom_user_agent": ""}) == config.USER_AGENTS["chrome"]


def test_main_window_smoke_and_export(site, tmp_path, monkeypatch):
    from PySide6.QtWidgets import QApplication, QFileDialog

    from ui.main_window import MainWindow
    from utils.scraper import ScrapeOptions, scrape_with_selector

    app = QApplication.instance() or QApplication([])
    w = MainWindow()
    assert "çalıştırınca" in w._trust_label.text()  # sahte "uyumlu" etiketi yok

    result = scrape_with_selector(f"{site.base}/urunler.html", ".price", "text", options=ScrapeOptions(robots_check=False))
    w._robots_check.setChecked(False)
    w._on_done(result)
    assert w._xlsx_btn.isEnabled() and w._results_count.text() == "3 satır"
    assert w._trust_label.text() == "robots.txt denetimi kapalı"

    out = tmp_path / "ui.xlsx"
    monkeypatch.setattr(QFileDialog, "getSaveFileName", lambda *a, **k: (str(out), ""))
    w._export("xlsx")
    assert out.exists() and "Kaydedildi" in w._status_text.text()

    w._on_failed("robots.txt bu sayfaya erişimi engelliyor: x")
    assert w._trust_label.text() == "robots.txt engeli" and not w._xlsx_btn.isEnabled()
    w.close()
    app.processEvents()
