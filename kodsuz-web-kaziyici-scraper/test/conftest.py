"""Testler gerçek kullanıcı klasörüne (~/.kodsuz-web-kaziyici) dokunmasın ve internete çıkmasın:
sayfalar yerel bir http.server'dan sunulur."""
from __future__ import annotations

import os
import sys
import tempfile
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

_tmp = tempfile.mkdtemp(prefix="scraper-test-")
os.environ["USERPROFILE"] = _tmp
os.environ["HOME"] = _tmp
os.environ["LOCALAPPDATA"] = _tmp
os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

import pytest  # noqa: E402

FIXTURES = Path(__file__).resolve().parent / "fixtures"


class _Site:
    """path -> (status, body). Her istek `log`a (path, zaman) olarak yazılır."""

    def __init__(self) -> None:
        self.routes: dict[str, tuple[int, str]] = {}
        self.log: list[tuple[str, float]] = []
        self.base = ""

    def reset(self) -> None:
        self.routes = {f"/{p.name}":(200, p.read_text(encoding="utf-8")) for p in FIXTURES.glob("*.html")}
        self.log = []

    def requested(self, path: str) -> int:
        return sum(1 for p, _ in self.log if p == path)


@pytest.fixture(scope="session")
def _server():
    import time

    site = _Site()

    class Handler(BaseHTTPRequestHandler):
        def do_GET(self):  # noqa: N802
            site.log.append((self.path, time.monotonic()))
            status, body = site.routes.get(self.path, (404, "yok"))
            data = body.encode("utf-8")
            self.send_response(status)
            self.send_header("Content-Type", "text/plain" if self.path == "/robots.txt" else "text/html; charset=utf-8")
            self.send_header("Content-Length", str(len(data)))
            self.end_headers()
            self.wfile.write(data)

        def log_message(self, *args):
            pass

    httpd = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
    site.base = f"http://127.0.0.1:{httpd.server_address[1]}"
    threading.Thread(target=httpd.serve_forever, daemon=True).start()
    yield site
    httpd.shutdown()


@pytest.fixture
def site(_server):
    _server.reset()
    return _server
