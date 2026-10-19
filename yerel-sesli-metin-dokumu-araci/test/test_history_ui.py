from __future__ import annotations

from utils import job_history
from utils.time_fmt import format_duration, format_job_date


def test_job_history_keeps_last_50_and_deletes():
    ids = [job_history.add_job(f"C:/ses/{i}.wav", i) for i in range(55)]
    jobs = job_history.list_jobs(100)
    assert len(jobs) == 50 and jobs[0]["file_name"] == "54.wav"
    assert job_history.delete_job(ids[-1]) and not job_history.delete_job(ids[-1])
    assert job_history.list_jobs()[0]["file_name"] == "53.wav"


def test_time_formatting():
    assert format_duration(65) == "01:05" and format_duration(3725) == "1:02:05" and format_duration(None) == "?:??"
    assert format_job_date("2026-03-04T09:05:00+00:00") == "4 Mar · 09:05"


def test_main_window_transcribe_flow_and_export(wav, fake_model, tmp_path, monkeypatch):
    from PySide6.QtWidgets import QApplication, QFileDialog

    from ui.main_window import MainWindow

    app = QApplication.instance() or QApplication([])
    w = MainWindow()
    ws = w._workspace
    assert ws._model_combo.currentData() == "small"
    ws._model_combo.setCurrentIndex(ws._model_combo.findData("base"))  # kalıcı ayar

    ws.load_file(str(wav))  # gerçek worker thread, taklit motor
    assert ws._worker.wait(20_000)
    app.processEvents()
    assert ws._result and ws._result.model == "base"
    assert len(ws._segment_rows) == 2
    assert ws._wave._heights and ws._export_btns["vtt"].isEnabled()

    out = tmp_path / "cikti.vtt"
    monkeypatch.setattr(QFileDialog, "getSaveFileName", lambda *a, **k: (str(out), ""))
    ws._export("vtt")
    assert out.read_text(encoding="utf-8").startswith("WEBVTT\n\n00:00:00.000 --> 00:00:00.620\nMerhaba dünya.")
    w.close()

    w2 = MainWindow()
    assert w2._workspace._model_combo.currentData() == "base"
    w2.close()
    app.processEvents()
