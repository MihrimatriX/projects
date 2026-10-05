# -*- mode: python ; coding: utf-8 -*-
# publish.ps1 tarafindan kullanilir (onedir + windowed). PySide6 hook'u yalnizca
# kullanilan Qt modullerini toplar; collect_all('PySide6') paketi gereksiz sisiriyordu.
import os

ROOT = os.path.abspath(SPECPATH)

a = Analysis(
    [os.path.join(ROOT, 'main.py')],
    pathex=[ROOT],
    binaries=[],
    datas=[(os.path.join(ROOT, 'assets'), 'assets')],
    hiddenimports=['PySide6.QtSvg', 'send2trash'],
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=['tkinter', 'pytest'],
    noarchive=False,
    optimize=0,
)
pyz = PYZ(a.pure)

exe = EXE(
    pyz,
    a.scripts,
    [],
    exclude_binaries=True,
    name='DiskAlanGorsellestirici',
    icon=os.path.join(ROOT, 'assets', 'icon.ico'),
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=False,
    console=False,
    disable_windowed_traceback=False,
    argv_emulation=False,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
)
coll = COLLECT(
    exe,
    a.binaries,
    a.datas,
    strip=False,
    upx=False,
    upx_exclude=[],
    name='DiskAlanGorsellestirici',
)
