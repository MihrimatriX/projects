"""Ses -> metin, tamamen yerel: faster-whisper (CTranslate2, CPU int8).

Ses PyAV ile çözülür (kendi FFmpeg kütüphaneleri pakette) — WAV/MP3/M4A/OGG/FLAC için
sistemde ffmpeg gerekmez. Model exe'ye gömülmez; ilk kullanımda
%LOCALAPPDATA%\\YerelSesliMetinDokumu\\models\\<boyut> altına bir kez indirilir.
"""
from __future__ import annotations

import os
from http.client import HTTPException
from collections.abc import Callable, Iterator
from dataclasses import dataclass, field
from functools import lru_cache
from pathlib import Path
from urllib.request import Request, urlopen

from utils.time_fmt import format_duration

SAMPLE_RATE = 16000
MODELS = {"tiny": 75, "base": 145, "small": 484, "medium": 1530}  # model.bin, yaklaşık MB
DEFAULT_MODEL = "small"
MODEL_URL = "https://huggingface.co/Systran/faster-whisper-{size}/resolve/main/{name}"
_MODEL_FILES = ("config.json", "tokenizer.json", "vocabulary.txt", "model.bin")  # büyük dosya en sonda

Segment = tuple[float, float, str]  # (başlangıç sn, bitiş sn, metin)
Progress = Callable[[str, int], None]


class Cancelled(RuntimeError):
    pass


@dataclass
class TranscriptResult:
    text: str
    duration_sec: float
    file_path: str
    segments: list[Segment]
    model: str = DEFAULT_MODEL
    peaks: list[float] = field(default_factory=list)


def app_dir() -> Path:
    return Path(os.environ.get("LOCALAPPDATA") or Path.home() / "AppData" / "Local") / "YerelSesliMetinDokumu"


def model_dir(size: str) -> Path:
    return app_dir() / "models" / size


def is_model_ready(size: str) -> bool:
    return all((model_dir(size) / f).is_file() for f in _MODEL_FILES)


def ensure_model(size: str, on_progress: Progress | None = None, should_stop: Callable[[], bool] | None = None) -> Path:
    """Modeli gerekiyorsa indirir. Yarım indirme `.part` olarak kalır, asla model sanılmaz."""
    if size not in MODELS:
        raise ValueError(f"Bilinmeyen model: {size}")
    target = model_dir(size)
    target.mkdir(parents=True, exist_ok=True)
    for name in _MODEL_FILES:
        dest = target / name
        if dest.is_file():
            continue
        part = dest.with_name(name + ".part")
        req = Request(MODEL_URL.format(size=size, name=name), headers={"User-Agent": "YerelSesliMetinDokumu"})
        try:
            with urlopen(req, timeout=30) as resp, open(part, "wb") as f:
                total = int(resp.headers.get("Content-Length") or 0)
                done = 0
                while chunk := resp.read(1 << 20):
                    if should_stop and should_stop():
                        raise Cancelled("İptal edildi")
                    f.write(chunk)
                    done += len(chunk)
                    if on_progress and total and name == "model.bin":
                        pct = done * 100 // total
                        on_progress(f"'{size}' modeli indiriliyor (ilk kullanım, ~{MODELS[size]} MB): %{pct}", 5 + pct * 40 // 100)
            if total and part.stat().st_size != total:
                raise OSError(f"eksik indirme ({part.stat().st_size}/{total} bayt)")
        except Cancelled:
            part.unlink(missing_ok=True)
            raise
        except (OSError, HTTPException) as exc:  # HTTPException: bağlantı yarıda koptu
            part.unlink(missing_ok=True)
            raise RuntimeError(
                f"'{size}' modeli indirilemedi — ilk kullanımda bir kez internet bağlantısı gerekir.\nAyrıntı: {exc}"
            ) from exc
        os.replace(part, dest)
    return target


def load_audio(path: str | Path):
    """16 kHz mono float32 numpy dizisi. faster_whisper.audio.decode_audio yerine doğrudan PyAV:
    onun `metadata_errors` argümanı PyAV 15+ ile kırık."""
    import av
    import numpy as np

    resampler = av.AudioResampler(format="s16", layout="mono", rate=SAMPLE_RATE)
    chunks = []
    try:
        with av.open(str(path)) as container:
            for frame in container.decode(audio=0):
                chunks += [f.to_ndarray() for f in resampler.resample(frame)]
        chunks += [f.to_ndarray() for f in resampler.resample(None)]
    except Exception as exc:  # PyAV: bozuk/desteklenmeyen dosya, ses akışı yok
        raise ValueError(f"Ses dosyası okunamadı ({Path(path).name}): {exc}") from exc
    if not chunks:
        raise ValueError(f"Ses dosyasında ses verisi yok: {Path(path).name}")
    return np.concatenate(chunks, axis=1).reshape(-1).astype(np.float32) / 32768.0


def waveform_peaks(audio, bars: int = 120) -> list[float]:
    import numpy as np

    chunks = np.array_split(np.abs(audio), min(bars, len(audio)))
    peaks = np.array([c.max() for c in chunks])
    top = float(peaks.max()) or 1.0
    return [float(p) / top for p in peaks]


@lru_cache(maxsize=1)
def _load_model(path: str):
    from faster_whisper import WhisperModel

    return WhisperModel(path, device="cpu", compute_type="int8")


def _run_whisper(model_path: Path, audio, language: str) -> Iterator[Segment]:
    """Motor sınırı (testlerde taklit edilir). Segmentleri tanındıkça üretir."""
    segments, _info = _load_model(str(model_path)).transcribe(audio, language=language, vad_filter=True)
    for s in segments:
        yield s.start, s.end, s.text


def transcribe_file(
    path: str,
    *,
    model: str = DEFAULT_MODEL,
    language: str = "tr",
    on_progress: Progress | None = None,
    should_stop: Callable[[], bool] | None = None,
) -> TranscriptResult:
    progress = on_progress or (lambda _m, _p: None)
    src = Path(path)
    if not src.is_file():
        raise FileNotFoundError(f"Dosya bulunamadı: {path}")

    progress("Ses okunuyor…", 2)
    audio = load_audio(src)
    duration = len(audio) / SAMPLE_RATE

    mdir = ensure_model(model, progress, should_stop)
    progress(f"'{model}' modeli yükleniyor…", 47)

    segments: list[Segment] = []
    for start, end, text in _run_whisper(mdir, audio, language):
        if should_stop and should_stop():
            raise Cancelled("İptal edildi")
        if text.strip():
            segments.append((float(start), float(end), text.strip()))
        ratio = min(1.0, end / duration) if duration else 1.0
        progress(f"Yerel tanıma: {format_duration(end)} / {format_duration(duration)}", 50 + int(ratio * 49))

    progress("Tamamlandı", 100)
    return TranscriptResult(
        text=" ".join(t for _, _, t in segments),
        duration_sec=duration,
        file_path=str(src.resolve()),
        segments=segments,
        model=model,
        peaks=waveform_peaks(audio),
    )


def _ts(seconds: float, sep: str = ",") -> str:
    ms = max(0, round(seconds * 1000))
    h, ms = divmod(ms, 3_600_000)
    m, ms = divmod(ms, 60_000)
    s, ms = divmod(ms, 1000)
    return f"{h:02d}:{m:02d}:{s:02d}{sep}{ms:03d}"


def format_txt(segments: list[Segment]) -> str:
    return "".join(f"{t}\n" for _, _, t in segments)


def format_srt(segments: list[Segment]) -> str:
    return "\n".join(f"{i}\n{_ts(a)} --> {_ts(b)}\n{t}\n" for i, (a, b, t) in enumerate(segments, 1))


def format_vtt(segments: list[Segment]) -> str:
    return "WEBVTT\n\n" + "\n".join(f"{_ts(a, '.')} --> {_ts(b, '.')}\n{t}\n" for a, b, t in segments)


EXPORTERS = {"txt": format_txt, "srt": format_srt, "vtt": format_vtt}
