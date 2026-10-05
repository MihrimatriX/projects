from __future__ import annotations

import json
from pathlib import Path

from core.models import UndoRecord
from core.rename_ops import undo_rename


class UndoStack:
    """Çok adımlı geri alma. ``path`` verilirse geçmiş JSON olarak saklanır; uygulama
    kapatılıp açıldıktan sonra da Ctrl+Z çalışır."""

    def __init__(self, max_size: int = 20, path: Path | None = None) -> None:
        self._max_size = max(1, max_size)
        self._path = path
        self._records: list[UndoRecord] = self._load()
        # Yinele yalnızca oturum içinde tutulur; kalıcı dosya biçimi (geri alma listesi) değişmez.
        self._redo: list[UndoRecord] = []
        self.last_moves: list[tuple[Path, Path]] = []  # son undo/redo'da (önceki yol, yeni yol)

    def _load(self) -> list[UndoRecord]:
        if not self._path or not self._path.is_file():
            return []
        try:
            data = json.loads(self._path.read_text(encoding="utf-8"))
            return [
                UndoRecord(moves=[(Path(new), Path(old)) for new, old in rec])
                for rec in data
                if rec
            ][-self._max_size :]
        except (OSError, ValueError, TypeError):
            return []  # bozuk geçmiş dosyası açılışı engellemesin

    def _save(self) -> None:
        if not self._path:
            return
        data = [[[str(new), str(old)] for new, old in r.moves] for r in self._records]
        try:
            self._path.parent.mkdir(parents=True, exist_ok=True)
            self._path.write_text(json.dumps(data, ensure_ascii=False), encoding="utf-8")
        except OSError:
            pass  # geçmiş yazılamazsa oturum içi geri alma yine çalışır

    def push(self, record: UndoRecord) -> None:
        if not record.moves:
            return
        self._redo.clear()  # yeni işlem yinelenebilecek adımları geçersiz kılar
        self._append(record)

    def _append(self, record: UndoRecord) -> None:
        self._records.append(record)
        if len(self._records) > self._max_size:
            self._records.pop(0)
        self._save()

    def undo(self) -> tuple[int, list]:
        """Son kaydı geri alır. RenameError'da hiçbir dosya değişmez ve kayıt yığında kalır."""
        if not self._records:
            return 0, []
        record = self._records[-1]
        moves = list(record.moves)
        restored = [old for _, old in moves]
        count = undo_rename(record)  # record.moves'u boşaltır
        self._records.pop()
        self._save()
        self._redo.append(UndoRecord(moves=moves))
        self.last_moves = [(new, old) for new, old in moves]
        return count, restored

    def redo(self) -> tuple[int, list]:
        """Son geri alınan adımı yeniden uygular (aynı hep-ya-hiç güvenlik kontrolleriyle)."""
        if not self._redo:
            return 0, []
        moves = list(self._redo[-1].moves)
        # undo_rename (new, old) çiftlerini new→old taşır; ters çiftlerle ileri taşıma olur.
        count = undo_rename(UndoRecord(moves=[(old, new) for new, old in reversed(moves)]))
        self._redo.pop()
        self._append(UndoRecord(moves=moves))
        self.last_moves = [(old, new) for new, old in moves]
        return count, [new for new, _ in moves]

    def can_redo(self) -> bool:
        return bool(self._redo)

    def can_undo(self) -> bool:
        return bool(self._records)

    def depth(self) -> int:
        return len(self._records)

    def clear(self) -> None:
        self._records.clear()
        self._redo.clear()
        self._save()
