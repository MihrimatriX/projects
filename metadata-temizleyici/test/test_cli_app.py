"""CLI akışları (clean/check/--copy) ve GUI açılış duman testi."""
from __future__ import annotations

from pathlib import Path

from PIL import Image
from typer.testing import CliRunner

from cli import app
from .test_strip_formats import _assert_clean_bytes, _make_jpeg

runner = CliRunner()


def test_cli_check_clean_check(tmp_path: Path) -> None:
    _make_jpeg(tmp_path / "a.jpg")
    Image.new("RGB", (4, 4)).save(tmp_path / "b.png")
    (tmp_path / "klip.mov").write_bytes(b"x")

    res = runner.invoke(app, ["check", str(tmp_path)])
    assert res.exit_code == 1 and "1/2" in res.output and "exiftool" in res.output

    res = runner.invoke(app, ["clean", str(tmp_path), "--no-backup"])
    assert res.exit_code == 0, res.output
    _assert_clean_bytes(tmp_path / "a.jpg")

    res = runner.invoke(app, ["check", str(tmp_path)])
    assert res.exit_code == 0 and "0/2" in res.output


def test_cli_copy_mode_and_failure_exit_code(tmp_path: Path) -> None:
    _make_jpeg(tmp_path / "a.jpg")
    original = (tmp_path / "a.jpg").read_bytes()
    res = runner.invoke(app, ["clean", str(tmp_path / "a.jpg"), "--copy"])
    assert res.exit_code == 0, res.output
    assert (tmp_path / "a.jpg").read_bytes() == original
    _assert_clean_bytes(tmp_path / "a_clean.jpg")
    assert not (tmp_path / "a.jpg.bak").exists()

    (tmp_path / "bozuk.png").write_bytes(b"not a png")
    res = runner.invoke(app, ["clean", str(tmp_path / "bozuk.png"), "--no-backup"])
    assert res.exit_code == 1


def test_main_window_smoke(tmp_path: Path) -> None:
    from PySide6.QtWidgets import QApplication

    from ui.main_window import MainWindow

    app_ = QApplication.instance() or QApplication([])
    _make_jpeg(tmp_path / "a.jpg")
    win = MainWindow()
    win._on_paths_added([str(tmp_path / "a.jpg")])
    assert [p.name for p in win._files] == ["a.jpg"]
    win._force_quit = True
    win.hide()
    win._watcher.stop()
    app_.processEvents()
