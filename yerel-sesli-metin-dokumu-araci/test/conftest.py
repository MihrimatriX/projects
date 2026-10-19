"""Testler gerçek kullanıcı klasörlerine (~/.yerel-sesli-metin-dokumu, %LOCALAPPDATA%) dokunmasın,
model indirmesin: tanıma motoru sınırda taklit edilir, indirme yerel http.server'dan yapılır."""
from __future__ import annotations

import math
import os
import struct
import sys
import tempfile
import wave
from pathlib import Path

_tmp = tempfile.mkdtemp(prefix="stt-test-")
os.environ["USERPROFILE"] = _tmp
os.environ["HOME"] = _tmp
os.environ["LOCALAPPDATA"] = _tmp
os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

import pytest  # noqa: E402


def write_wav(path: Path, seconds: float, rate: int = 44100, channels: int = 2, freq: float = 440.0) -> Path:
    """Stdlib ile 16-bit PCM sinüs WAV'ı (ffmpeg gerekmez)."""
    n = int(seconds * rate)
    frames = bytearray()
    for i in range(n):
        v = int(12000 * math.sin(2 * math.pi * freq * i / rate))
        frames += struct.pack("<h", v) * channels
    with wave.open(str(path), "wb") as w:
        w.setnchannels(channels)
        w.setsampwidth(2)
        w.setframerate(rate)
        w.writeframes(bytes(frames))
    return path


@pytest.fixture(autouse=True)
def _isolated_appdata(tmp_path, monkeypatch):
    # Her test kendi boş model/ayar klasörüyle başlar
    monkeypatch.setenv("LOCALAPPDATA", str(tmp_path / "appdata"))


@pytest.fixture
def wav(tmp_path) -> Path:
    return write_wav(tmp_path / "ornek ses.wav", 1.5)


@pytest.fixture
def fake_model(monkeypatch):
    """Model hazırmış gibi dosyaları oluşturur ve motoru taklit eder; motorun aldığı girdiyi kaydeder."""
    from utils import transcribe as t

    for size in t.MODELS:
        d = t.model_dir(size)
        d.mkdir(parents=True, exist_ok=True)
        for name in t._MODEL_FILES:
            (d / name).write_bytes(b"x")
    calls: list[dict] = []

    def engine(model_path, audio, language):
        calls.append({"model_path": model_path, "samples": len(audio), "language": language})
        yield 0.0, 0.62, " Merhaba dünya."
        yield 0.62, 0.9, "   "  # boş segment atlanmalı
        yield 0.9, 1.5, " Nasılsın?"

    monkeypatch.setattr(t, "_run_whisper", engine)
    return calls
