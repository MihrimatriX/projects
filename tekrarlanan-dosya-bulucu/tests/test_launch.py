from __future__ import annotations

from pathlib import Path
from unittest.mock import MagicMock, patch

from utils.handoff import argv_for_launcher, launch_app, try_forward_subprocess


def test_argv_for_launcher_exe(tmp_path: Path) -> None:
    exe = tmp_path / "TekrarlananDosyaBulucu.exe"
    exe.write_text("", encoding="utf-8")
    assert argv_for_launcher(exe, ["--handoff"]) == [str(exe), "--handoff"]


def test_argv_for_launcher_main_py(tmp_path: Path) -> None:
    main_py = tmp_path / "main.py"
    main_py.write_text("", encoding="utf-8")
    argv = argv_for_launcher(main_py, ["--scan"])
    assert argv[-2:] == [str(main_py), "--scan"]
    assert "python" in argv[0].lower() or argv[0].endswith("python.exe")


def test_launch_app_ipc_first(tmp_path: Path, monkeypatch) -> None:
    monkeypatch.setattr("utils.handoff.HANDOFF_PATH", tmp_path / "handoff.json")
    launcher = tmp_path / "main.py"
    launcher.write_text("", encoding="utf-8")
    monkeypatch.setattr("utils.handoff.find_project_launcher", lambda: launcher)

    with patch("utils.handoff.try_forward_subprocess", return_value=True) as fwd:
        with patch("utils.handoff._spawn_launcher") as spawn:
            assert launch_app([r"C:\A"]) is True
            fwd.assert_called_once_with(launcher)
            spawn.assert_not_called()


def test_try_forward_subprocess_return_code(tmp_path: Path) -> None:
    launcher = tmp_path / "main.py"
    launcher.write_text("import sys\nsys.exit(1)\n", encoding="utf-8")
    with patch("utils.handoff.subprocess.run") as run:
        run.return_value = MagicMock(returncode=1)
        assert not try_forward_subprocess(launcher)
        run.return_value = MagicMock(returncode=0)
        assert try_forward_subprocess(launcher)
