from __future__ import annotations

import json
import os

from PySide6.QtCore import QObject, Signal
from PySide6.QtNetwork import QLocalServer, QLocalSocket

# ponytail: Windows pipe adı — kısa ASCII (uzun/karışık adlar Invalid name verebiliyor)
# Testler çalışan gerçek uygulamanın kanalına dokunmasın diye TEKRARLANAN_IPC_NAME ile değişir.
SERVER_NAME = os.environ.get("TEKRARLANAN_IPC_NAME") or "tekdosya_bulucu_ipc"


class HandoffServer(QObject):
    """Çalışan örnek: ikinci süreçten handoff alır."""

    received = Signal(dict)

    def __init__(self, parent=None) -> None:
        super().__init__(parent)
        self._server = QLocalServer(self)
        self._server.newConnection.connect(self._on_connection)

    def start(self) -> bool:
        QLocalServer.removeServer(SERVER_NAME)
        return self._server.listen(SERVER_NAME)

    def stop(self) -> None:
        self._server.close()
        QLocalServer.removeServer(SERVER_NAME)

    def _on_connection(self) -> None:
        socket = self._server.nextPendingConnection()
        if not socket:
            return
        socket.readyRead.connect(lambda s=socket: self._read(s))
        if socket.bytesAvailable():
            self._read(socket)

    def _read(self, socket: QLocalSocket) -> None:
        raw = bytes(socket.readAll()).decode("utf-8", errors="replace").strip()
        if not raw:
            return
        try:
            payload = json.loads(raw)
            if isinstance(payload, dict):
                self.received.emit(payload)
            socket.write(b"ok")
            socket.flush()
        except json.JSONDecodeError:
            socket.write(b"err")
        socket.disconnectFromServer()


def wake_running_instance(*, timeout_ms: int = 3000) -> bool:
    """Çalışan örneğin penceresini öne getir."""
    return send_handoff_to_running({"action": "show"}, timeout_ms=timeout_ms)


def send_handoff_to_running(payload: dict, *, timeout_ms: int = 3000) -> bool:
    """İkinci örnek: çalışan uygulamaya handoff gönderir."""
    socket = QLocalSocket()
    socket.connectToServer(SERVER_NAME)
    if not socket.waitForConnected(timeout_ms):
        return False
    written = socket.write(json.dumps(payload, ensure_ascii=False).encode("utf-8"))
    if written <= 0:
        return False
    socket.flush()
    # ponytail: aynı süreçte waitForBytesWritten event loop'u bloklayıp False döner; yazma poll'da tamamlanır
    if socket.bytesToWrite() > 0:
        socket.waitForBytesWritten(50)
    # ponytail: sunucu readyRead gecikmesi — kısa poll
    import time

    from PySide6.QtWidgets import QApplication

    app = QApplication.instance()
    deadline = time.monotonic() + timeout_ms / 1000.0
    while time.monotonic() < deadline:
        if app:
            app.processEvents()
        if socket.bytesAvailable():
            if bytes(socket.readAll()) == b"ok":
                return True
        if socket.waitForReadyRead(50):
            if bytes(socket.readAll()) == b"ok":
                return True
        time.sleep(0.03)
    return False
