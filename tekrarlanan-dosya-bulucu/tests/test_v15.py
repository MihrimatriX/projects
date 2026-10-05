from __future__ import annotations

import sys
from pathlib import Path

import pytest

from utils.cli_args import wants_forward_handoff
from utils.handoff import argv_for_launcher, launcher_candidates


def test_wants_forward_handoff() -> None:
    assert wants_forward_handoff(["--forward-handoff", "--handoff"])
    assert not wants_forward_handoff(["--handoff"])


def test_launcher_candidates_prefers_exe(tmp_path: Path) -> None:
    # Monorepo düzeni: <repo>/tekrarlanan-dosya-bulucu + <repo>/dist/tekrarlanan-dosya-bulucu/
    project = tmp_path / "tekrarlanan-dosya-bulucu"
    project.mkdir()
    (tmp_path / "dist" / project.name).mkdir(parents=True)
    exe = tmp_path / "dist" / project.name / "TekrarlananDosyaBulucu.exe"
    exe.write_text("", encoding="utf-8")
    (project / "main.py").write_text("", encoding="utf-8")
    found = next((c for c in launcher_candidates(project) if c.exists()), None)
    assert found == exe


def test_argv_for_launcher_run_sh(tmp_path: Path) -> None:
    sh = tmp_path / "run.sh"
    sh.write_text("#!/bin/sh\n", encoding="utf-8")
    assert argv_for_launcher(sh, ["--handoff"]) == [str(sh), "--handoff"]


def test_launcher_candidates_run_script(tmp_path: Path) -> None:
    script = "run.ps1" if sys.platform == "win32" else "run.sh"
    (tmp_path / script).write_text("", encoding="utf-8")
    (tmp_path / "main.py").write_text("", encoding="utf-8")
    found = next((c for c in launcher_candidates(tmp_path) if c.exists()), None)
    assert found == tmp_path / script


@pytest.mark.skipif(sys.platform == "win32", reason="QLockFile yolu macOS/Linux")
def test_qlockfile_exclusive(tmp_path: Path) -> None:
    from PySide6.QtCore import QCoreApplication, QLockFile

    app = QCoreApplication.instance() or QCoreApplication([])
    lock1 = QLockFile(str(tmp_path / "instance.lock"))
    lock2 = QLockFile(str(tmp_path / "instance.lock"))
    lock1.setStaleLockTime(0)
    lock2.setStaleLockTime(0)
    assert lock1.tryLock(200)
    assert not lock2.tryLock(200)
    lock1.unlock()
    assert lock2.tryLock(200)
    lock2.unlock()
    _ = app
