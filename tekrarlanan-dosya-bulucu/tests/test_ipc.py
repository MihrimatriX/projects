from __future__ import annotations

from utils.ipc import HandoffServer, send_handoff_to_running


def test_ipc_handoff_roundtrip() -> None:
    from PySide6.QtCore import QCoreApplication

    app = QCoreApplication.instance() or QCoreApplication([])
    received: list[dict] = []

    server = HandoffServer()
    assert server.start()
    server.received.connect(received.append)

    payload = {"roots": [r"C:\scan\a", r"D:\photos"], "auto_scan": True}
    assert send_handoff_to_running(payload)

    import time

    for _ in range(50):
        app.processEvents()
        if received:
            break
        time.sleep(0.01)

    server.stop()
    assert len(received) == 1
    assert r"C:\scan\a" in received[0]["roots"]
    assert received[0]["auto_scan"] is True


def test_ipc_forward_fails_without_server() -> None:
    from PySide6.QtCore import QCoreApplication
    from utils.ipc import SERVER_NAME
    from PySide6.QtNetwork import QLocalServer

    QLocalServer.removeServer(SERVER_NAME)
    app = QCoreApplication.instance() or QCoreApplication([])
    _ = app
    assert not send_handoff_to_running({"roots": ["/tmp/x"], "auto_scan": False})
