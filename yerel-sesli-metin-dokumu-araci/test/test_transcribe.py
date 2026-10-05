from __future__ import annotations

import os
import shutil
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

import pytest

from conftest import write_wav
from utils import transcribe as t


def test_wav_loads_without_ffmpeg(wav):
    # Sistemde ffmpeg yok; çözme PyAV ile (kendi FFmpeg kütüphaneleri pakette)
    audio = t.load_audio(wav)
    assert audio.dtype.name == "float32"
    assert abs(len(audio) - int(1.5 * t.SAMPLE_RATE)) < 200  # 44.1 kHz stereo -> 16 kHz mono
    assert 0.2 < float(abs(audio).max()) <= 1.0


def test_low_rate_mono_wav_is_resampled(tmp_path):
    audio = t.load_audio(write_wav(tmp_path / "telefon.wav", 2.0, rate=8000, channels=1))
    assert abs(len(audio) - 2 * t.SAMPLE_RATE) < 200


def test_mp3_loads_without_system_ffmpeg(tmp_path):
    import av
    import numpy as np

    path = tmp_path / "kayit.mp3"
    with av.open(str(path), "w") as out:
        stream = out.add_stream("libmp3lame", rate=44100, layout="mono")
        samples = (np.sin(np.arange(44100 * 2) * 2 * np.pi * 440 / 44100) * 0.5).astype("float32")
        frame = av.AudioFrame.from_ndarray(samples[None, :], format="flt", layout="mono")
        frame.sample_rate = 44100
        for packet in stream.encode(frame):
            out.mux(packet)
        for packet in stream.encode(None):
            out.mux(packet)
    audio = t.load_audio(path)
    assert abs(len(audio) / t.SAMPLE_RATE - 2.0) < 0.15


def test_broken_and_empty_files_give_turkish_errors(tmp_path):
    bad = tmp_path / "bozuk.mp3"
    bad.write_bytes(b"bu bir ses degil")
    with pytest.raises(ValueError, match="okunamadı"):
        t.load_audio(bad)
    with pytest.raises(FileNotFoundError, match="bulunamadı"):
        t.transcribe_file(str(tmp_path / "yok.wav"))


def test_pipeline_with_mocked_engine(wav, fake_model):
    progress: list[tuple[str, int]] = []
    r = t.transcribe_file(str(wav), model="base", on_progress=lambda m, p: progress.append((m, p)))

    call = fake_model[0]
    assert call["model_path"] == t.model_dir("base")
    assert str(t.app_dir()).startswith(os.environ["LOCALAPPDATA"])
    assert abs(call["samples"] - 24000) < 200 and call["language"] == "tr"
    assert r.segments == [(0.0, 0.62, "Merhaba dünya."), (0.9, 1.5, "Nasılsın?")]
    assert r.text == "Merhaba dünya. Nasılsın?"
    assert abs(r.duration_sec - 1.5) < 0.02 and r.model == "base"
    assert len(r.peaks) == 120 and max(r.peaks) == 1.0
    pcts = [p for _, p in progress]
    assert pcts == sorted(pcts) and pcts[-1] == 100
    assert any("Yerel tanıma" in m for m, _ in progress)


def test_pipeline_can_be_cancelled(wav, fake_model):
    with pytest.raises(t.Cancelled):
        t.transcribe_file(str(wav), should_stop=lambda: True)


def test_output_formats_and_timestamps():
    segs = [(0.0, 1.0005, "Merhaba."), (59.9996, 3661.5, "Uzun --> konuşma")]
    assert t.format_txt(segs) == "Merhaba.\nUzun --> konuşma\n"
    assert t.format_srt(segs) == (
        "1\n00:00:00,000 --> 00:00:01,000\nMerhaba.\n\n"
        "2\n00:01:00,000 --> 01:01:01,500\nUzun --> konuşma\n"
    )
    assert t.format_vtt(segs) == (
        "WEBVTT\n\n00:00:00.000 --> 00:00:01.000\nMerhaba.\n\n"
        "00:01:00.000 --> 01:01:01.500\nUzun --> konuşma\n"
    )
    assert t._ts(-0.2) == "00:00:00,000"
    assert t.format_srt([]) == "" and t.format_vtt([]) == "WEBVTT\n\n"


@pytest.fixture
def model_server():
    """Sahte Hugging Face: dosya -> (durum, gövde, ilan edilen uzunluk)."""
    files: dict[str, tuple[int, bytes, int | None]] = {}
    hits: list[str] = []

    class Handler(BaseHTTPRequestHandler):
        def do_GET(self):  # noqa: N802
            name = self.path.rsplit("/", 1)[-1]
            hits.append(name)
            status, body, length = files.get(name, (404, b"", None))
            self.send_response(status)
            self.send_header("Content-Length", str(length if length is not None else len(body)))
            self.end_headers()
            self.wfile.write(body)

        def log_message(self, *a):
            pass

    httpd = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
    threading.Thread(target=httpd.serve_forever, daemon=True).start()
    yield f"http://127.0.0.1:{httpd.server_address[1]}/{{size}}/{{name}}", files, hits
    httpd.shutdown()


def test_model_download_progress_and_cache(monkeypatch, model_server):
    url, files, hits = model_server
    monkeypatch.setattr(t, "MODEL_URL", url)
    for name in t._MODEL_FILES:
        files[name] = (200, name.encode() * 300_000 if name == "model.bin" else b"{}", None)
    assert not t.is_model_ready("tiny")

    progress: list[tuple[str, int]] = []
    path = t.ensure_model("tiny", lambda m, p: progress.append((m, p)))
    assert path == t.model_dir("tiny") and t.is_model_ready("tiny")
    assert (path / "model.bin").stat().st_size == len(b"model.bin") * 300_000
    assert progress and "indiriliyor" in progress[-1][0] and "%100" in progress[-1][0]
    assert not list(path.glob("*.part"))

    hits.clear()
    t.ensure_model("tiny")
    assert hits == []  # önbellekten, yeniden indirme yok


@pytest.mark.parametrize("model_bin", [(404, b"", None), (200, b"yarim", 1_000_000)])
def test_failed_or_truncated_download_leaves_no_model(monkeypatch, model_server, model_bin):
    url, files, _ = model_server
    monkeypatch.setattr(t, "MODEL_URL", url)
    for name in t._MODEL_FILES:
        files[name] = (200, b"{}", None)
    files["model.bin"] = model_bin
    shutil.rmtree(t.model_dir("medium"), ignore_errors=True)
    with pytest.raises(RuntimeError, match="indirilemedi"):
        t.ensure_model("medium")
    assert not t.is_model_ready("medium")
    assert not list(t.model_dir("medium").glob("model.bin*"))


def test_unknown_model_rejected():
    with pytest.raises(ValueError, match="Bilinmeyen model"):
        t.ensure_model("huge")
