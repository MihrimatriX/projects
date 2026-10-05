from __future__ import annotations

import csv
import json
import os
import subprocess
import sys
from pathlib import Path

from core.models import PreviewRow, PreviewStatus, UndoRecord, path_key


class RenameError(OSError):
    """Toplu yeniden adlandırma yapılamadı; dosyalar ilk hâline döndürüldü
    (``stuck`` boş değilse bu yollar geri alınamadı)."""

    def __init__(self, message: str, stuck: list[Path] | None = None) -> None:
        super().__init__(message)
        self.stuck = stuck or []


def _check_pairs(pairs: list[tuple[Path, Path]]) -> None:
    """Hiçbir dosyanın üzerine yazılmayacağını doğrular; sorun varsa hiçbir şey
    taşınmadan RenameError fırlatır."""
    moving = {path_key(src) for src, _ in pairs}
    seen: set[str] = set()
    problems: list[str] = []
    for _src, dest in pairs:
        key = path_key(dest)
        if key in seen:
            problems.append(f"{dest.name}: birden fazla dosya aynı ada gidiyor")
        seen.add(key)
        # Hedef, bu işlemde yerinden taşınan bir kaynak değilse (büyük/küçük harf
        # değişimi dahil) dolu bir hedefe asla taşıma yapılmaz.
        if key not in moving and os.path.lexists(dest):
            problems.append(f"{dest.name}: hedefte zaten bir dosya var")
    if problems:
        raise RenameError("Yeniden adlandırma iptal edildi:\n" + "\n".join(problems[:10]))


def _temp_name(path: Path) -> Path:
    temp = path.parent / f".__dyad_{path.name}"
    counter = 0
    while os.path.lexists(temp):
        counter += 1
        temp = path.parent / f".__dyad_{counter}_{path.name}"
    return temp


def _move_all(pairs: list[tuple[Path, Path]]) -> None:
    """Hep-ya-hiç taşıma. os.rename kullanılır: Windows'ta hedef varsa hata verir
    (shutil.move ise kopyalayıp üzerine yazabiliyordu). Herhangi bir adım başarısız
    olursa tamamlanan adımlar ters sırayla geri alınır."""
    _check_pairs(pairs)
    sources = {path_key(src) for src, _ in pairs}
    # Hedef başka bir kaynağın şimdiki adıysa (a→b + b→a, zincir, yalnızca harf
    # değişimi) iki aşama: önce hepsi geçici adlara, sonra hedeflere.
    two_phase = any(path_key(dest) in sources for _, dest in pairs)
    done: list[tuple[Path, Path]] = []
    try:
        if two_phase:
            staged: list[tuple[Path, Path]] = []
            for src, dest in pairs:
                temp = _temp_name(src)
                os.rename(src, temp)
                done.append((src, temp))
                staged.append((temp, dest))
            for temp, dest in staged:
                if os.path.lexists(dest):  # bu arada başka biri oluşturduysa
                    raise FileExistsError(f"Hedef zaten var: {dest}")
                os.rename(temp, dest)
                done.append((temp, dest))
        else:
            for src, dest in pairs:
                # ponytail: lexists+rename arasında yarış penceresi var; POSIX'te os.rename
                # üzerine yazar. Masaüstü tek kullanıcı için yeterli.
                if os.path.lexists(dest):
                    raise FileExistsError(f"Hedef zaten var: {dest}")
                os.rename(src, dest)
                done.append((src, dest))
    except OSError as exc:
        stuck: list[Path] = []
        for before, after in reversed(done):
            try:
                os.rename(after, before)
            except OSError:
                stuck.append(after)
        msg = f"Yeniden adlandırma başarısız, değişiklikler geri alındı:\n{exc}"
        if stuck:
            msg = (
                f"Yeniden adlandırma başarısız:\n{exc}\n\n"
                "Şu dosyalar eski adına döndürülemedi:\n" + "\n".join(str(p) for p in stuck)
            )
        raise RenameError(msg, stuck) from exc


def apply_renames(rows: list[PreviewRow]) -> UndoRecord:
    record = UndoRecord()
    pairs: list[tuple[Path, Path]] = []
    for row in rows:
        if row.status != PreviewStatus.OK:
            continue
        src = row.path
        # Path karşılaştırması Windows'ta büyük/küçük harf duyarsızdır; "a.txt" →
        # "A.txt" atlanmasın diye adları karşılaştır.
        if row.new_name == src.name:
            continue
        pairs.append((src, src.parent / row.new_name))

    if not pairs:
        return record
    _move_all(pairs)
    record.moves = [(dest, src) for src, dest in pairs]
    return record


def undo_rename(record: UndoRecord) -> int:
    """Kaydı geri alır. Sonradan silinen/taşınan dosyalar atlanır. Eski ad bu arada
    başka bir dosyaca alınmışsa hiçbir şey taşınmaz, RenameError fırlatılır ve kayıt
    korunur (yeniden denenebilir)."""
    pairs = [(new, old) for new, old in reversed(record.moves) if os.path.lexists(new)]
    if pairs:
        _move_all(pairs)
    record.moves.clear()
    return len(pairs)


def export_preview_csv(rows: list[PreviewRow], path: Path) -> None:
    with path.open("w", newline="", encoding="utf-8-sig") as fh:
        writer = csv.writer(fh)
        writer.writerow(["Klasör", "Eski ad", "Yeni ad", "Durum", "Mesaj"])
        for row in rows:
            writer.writerow(
                [
                    str(row.path.parent),
                    row.original_name,
                    row.new_name,
                    row.status.value,
                    row.message,
                ]
            )


def export_preview_json(rows: list[PreviewRow], path: Path) -> None:
    payload = [
        {
            "folder": str(row.path.parent),
            "old_name": row.original_name,
            "new_name": row.new_name,
            "status": row.status.value,
            "message": row.message,
        }
        for row in rows
    ]
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")


def collect_from_folder(
    folder: Path,
    *,
    recursive: bool,
    include_hidden: bool = False,
) -> list[Path]:
    if not folder.is_dir():
        return []

    def accept(p: Path) -> bool:
        if not p.is_file():
            return False
        if include_hidden:
            return True
        # Yalnızca seçilen klasörün altındaki parçalara bak; üst yoldaki ".config" gibi
        # klasörler tüm dosyaları gizli saydırmasın.
        return not any(part.startswith(".") for part in p.relative_to(folder).parts)

    if recursive:
        return sorted(p for p in folder.rglob("*") if accept(p))
    return sorted(p for p in folder.iterdir() if accept(p))


def reveal_in_explorer(path: Path) -> None:
    target = path if path.exists() else path.parent
    if sys.platform == "win32":
        subprocess.run(["explorer", "/select,", str(target)], check=False)
    elif sys.platform == "darwin":
        subprocess.run(["open", "-R", str(target)], check=False)
    else:
        subprocess.run(["xdg-open", str(target.parent)], check=False)
