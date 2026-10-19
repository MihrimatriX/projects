# PyInstaller - Akilli Dosya Arama Motoru (Windows, --onedir --windowed)
# Calistir: publish.ps1 -> dist/akilli-dosya-arama-motoru/AkilliDosyaArama.exe

block_cipher = None

hiddenimports = [
    "watchdog.observers",
    "watchdog.observers.polling",
    "watchdog.observers.read_directory_changes",
    "watchdog.observers.winapi",
    "watchdog.events",
    "rapidfuzz",
    "rapidfuzz.fuzz",
    "rapidfuzz.process",
    "sqlite3",
    "PySide6.QtSvg",
]

a = Analysis(
    ["main.py"],
    pathex=[],
    binaries=[],
    datas=[],
    hiddenimports=hiddenimports,
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=[
        "typer",
        "rich",
        "tkinter",
        "matplotlib",
        "numpy",
        "pandas",
        "pytest",
        "IPython",
        "notebook",
    ],
    win_no_prefer_redirects=False,
    win_private_assemblies=False,
    cipher=block_cipher,
    noarchive=False,
)

pyz = PYZ(a.pure, a.zipped_data, cipher=block_cipher)

exe = EXE(
    pyz,
    a.scripts,
    [],
    exclude_binaries=True,
    name="AkilliDosyaArama",
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=False,
    upx_exclude=[],
    runtime_tmpdir=None,
    console=False,
    disable_windowed_traceback=False,
    argv_emulation=False,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
    icon="assets/app.ico" if __import__("pathlib").Path("assets/app.ico").is_file() else None,
)

coll = COLLECT(
    exe,
    a.binaries,
    a.datas,
    strip=False,
    upx=False,
    name="akilli-dosya-arama-motoru",
)
