"""Arka planda takılı kalmış uygulama süreçlerini sonlandır."""
from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path

_ROOT = Path(__file__).resolve().parent.parent


def kill_stale_instances(*, except_pid: int | None = None) -> int:
    """Proje main.py süreçlerini kapat. Sonlandırılan süreç sayısı."""
    pid = except_pid if except_pid is not None else os.getpid()
    root = str(_ROOT).replace("'", "''")
    if sys.platform == "win32":
        if getattr(sys, "frozen", False):
            # Paketlenmiş exe: yalnızca aynı exe yolundan başlamış örnekler
            exe = sys.executable.replace("'", "''")
            match = f"$_.ExecutablePath -eq '{exe}'"
        else:
            match = (
                "($_.Name -eq 'python.exe' -or $_.Name -eq 'pythonw.exe') -and "
                "$_.CommandLine -like '*tekrarlanan-dosya-bulucu*main.py*'"
            )
        ps = (
            "Get-CimInstance Win32_Process | "
            f"Where-Object {{ {match} -and "
            f"$_.ProcessId -ne {pid} "
            "} | ForEach-Object { "
            "Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue "
            "}"
        )
        subprocess.run(
            ["powershell", "-NoProfile", "-Command", ps],
            cwd=str(_ROOT),
            check=False,
            creationflags=subprocess.CREATE_NO_WINDOW,  # --windowed exe'de konsol penceresi açılmasın
        )
        return 0  # ponytail: sayım gerekmez
    subprocess.run(["pkill", "-f", f"{_ROOT}/main.py"], check=False)
    return 0
