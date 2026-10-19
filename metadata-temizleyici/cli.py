from __future__ import annotations

import sys
from pathlib import Path
from typing import Optional

import typer
from rich.console import Console
from rich.table import Table

from utils.audit import AuditEntry, AuditLog, now_iso
from utils.metadata import (
    EXIFTOOL_REQUIRED_MESSAGE,
    collect_files,
    count_needing_exiftool,
    read_metadata_tags,
    strip_metadata,
)
from utils.presets import PRESETS, StripMode, preset_choices
from utils.restore import has_backup, restore_backup

try:  # GUI'deki gibi HEIC/HEIF desteğini Pillow'a kaydet
    import pillow_heif

    pillow_heif.register_heif_opener()
except ImportError:
    pass

app = typer.Typer(help="Metadata Temizleyici — headless CLI")
console = Console()


def _resolve_mode(mode: str, preset: Optional[str]) -> tuple[StripMode, str | None]:
    mapping = {
        "all": StripMode.ALL,
        "gps": StripMode.GPS_ONLY,
        "camera": StripMode.CAMERA_ONLY,
        "preset": StripMode.PRESET,
    }
    strip_mode = mapping.get(mode, StripMode.ALL)
    preset_id = preset or "social_media"
    if strip_mode == StripMode.PRESET and preset_id not in PRESETS:
        raise typer.BadParameter(f"Bilinmeyen preset: {preset_id}")
    return strip_mode, preset_id if strip_mode == StripMode.PRESET else None


@app.command("read")
def read_cmd(path: Path) -> None:
    """Dosya metadata'sını tablo olarak göster."""
    tags = read_metadata_tags(path)
    table = Table(title=str(path.name))
    table.add_column("Tag")
    table.add_column("Değer")
    table.add_column("Risk")
    for tag in tags:
        table.add_row(tag.name, tag.value, tag.risk)
    console.print(table)


@app.command("clean")
def clean_cmd(
    target: Path = typer.Argument(..., help="Dosya veya klasör"),
    recursive: bool = typer.Option(True, "--recursive/--no-recursive", "-r"),
    backup: bool = typer.Option(True, "--backup/--no-backup"),
    mode: str = typer.Option("all", "--mode", "-m", help="all|gps|camera|preset"),
    preset: Optional[str] = typer.Option(None, "--preset", "-p", help="social_media|gps_only|camera_only"),
    dry_run: bool = typer.Option(False, "--dry-run", help="Dosyaya yazmadan simülasyon"),
    tags: Optional[str] = typer.Option(None, "--tags", "-t", help="Özel tag listesi: Make,GPSLatitude"),
    report: Optional[Path] = typer.Option(None, "--report", help="CSV audit raporu yolu"),
    copy: bool = typer.Option(False, "--copy", help="Orijinale dokunma; temiz kopyayı ad_clean.uzantı olarak yaz"),
) -> None:
    """Metadata temizle."""
    strip_mode, preset_id = _resolve_mode(mode, preset)
    custom_tags = [t.strip() for t in tags.split(",") if t.strip()] if tags else None
    if custom_tags:
        strip_mode = StripMode.CUSTOM
        preset_id = None
    files = _collect_or_exit(target, recursive)

    if dry_run:
        console.print("[cyan]Simülasyon modu — dosyalar değiştirilmeyecek[/cyan]")

    audit = AuditLog()
    ok = 0
    for file_path in files:
        try:
            result = strip_metadata(
                file_path,
                backup=backup,
                overwrite=not copy,
                mode=strip_mode,
                preset_id=preset_id,
                custom_tags=custom_tags,
                dry_run=dry_run,
            )
            ok += 1
            if dry_run:
                console.print(f"[cyan]○[/cyan] {file_path.name} — {result.tags_removed} tag silinirdi")
            else:
                suffix = " [yellow](piksel değişti)[/yellow]" if result.hash_changed else ""
                console.print(f"[green]✓[/green] {file_path.name} — {result.tags_removed} tag{suffix}")
            if not dry_run:
                audit.add(
                    AuditEntry(
                        timestamp=now_iso(),
                        file_path=str(file_path),
                        success=True,
                        tags_removed=result.tags_removed,
                        removed_tags="; ".join(result.removed_tag_names),
                        backup_path=str(result.backup or ""),
                        engine=result.engine,
                        mode=strip_mode.value,
                        hash_changed=result.hash_changed,
                    )
                )
        except Exception as exc:
            console.print(f"[red]✗[/red] {file_path.name} — {exc}")
            if not dry_run:
                audit.add(
                    AuditEntry(
                        timestamp=now_iso(),
                        file_path=str(file_path),
                        success=False,
                        tags_removed=0,
                        removed_tags="",
                        backup_path="",
                        engine="",
                        mode=strip_mode.value,
                        hash_changed=False,
                        error=str(exc),
                    )
                )

    console.print(f"\nTamamlandı: {ok}/{len(files)}")
    if report and not dry_run:
        audit.export_csv(report)
        console.print(f"Rapor: {report}")
    if ok < len(files):
        raise typer.Exit(code=1)


def _collect_or_exit(target: Path, recursive: bool) -> list[Path]:
    files = collect_files([target], recursive=recursive)
    skipped = count_needing_exiftool([target], recursive=recursive)
    if skipped:
        console.print(f"[yellow]{skipped} video atlandı: {EXIFTOOL_REQUIRED_MESSAGE}[/yellow]")
    if not files:
        console.print("[yellow]Desteklenen dosya bulunamadı[/yellow]")
        raise typer.Exit(code=1)
    return files


@app.command("check")
def check_cmd(
    target: Path = typer.Argument(..., help="Dosya veya klasör"),
    recursive: bool = typer.Option(True, "--recursive/--no-recursive", "-r"),
) -> None:
    """Yüksek riskli metadata (GPS, seri no, sahip, XMP, IPTC...) kalan dosyaları listele.

    Hepsi temizse çıkış kodu 0, değilse 1 (betik/CI kontrolü için)."""
    files = _collect_or_exit(target, recursive)
    dirty = 0
    for file_path in files:
        try:
            risky = [t.name for t in read_metadata_tags(file_path) if t.risk == "high"]
        except Exception as exc:
            dirty += 1
            console.print(f"[red]✗[/red] {file_path.name} — okunamadı: {exc}")
            continue
        if risky:
            dirty += 1
            console.print(f"[yellow]![/yellow] {file_path.name} — {', '.join(risky)}")
        else:
            console.print(f"[green]✓[/green] {file_path.name} — temiz")
    console.print(f"\n{dirty}/{len(files)} dosyada riskli metadata var")
    raise typer.Exit(code=1 if dirty else 0)


@app.command("restore")
def restore_cmd(
    target: Path = typer.Argument(..., help="Geri yüklenecek dosya"),
) -> None:
    """`.bak` yedeğinden orijinal dosyayı geri yükle."""
    if not has_backup(target):
        console.print(f"[red]Yedek yok:[/red] {target.name}.bak")
        raise typer.Exit(code=1)
    restore_backup(target)
    console.print(f"[green]✓[/green] Geri yüklendi: {target.name}")


@app.command("presets")
def presets_cmd() -> None:
    """Kullanılabilir preset listesi."""
    for preset_id, label in preset_choices():
        console.print(f"- {preset_id}: {label}")


def main() -> None:
    # Yonlendirilmis/borulanmis cikti Windows'ta cp1252 olur; ✓ ve Turkce harfler UnicodeEncodeError verir.
    for stream in (sys.stdout, sys.stderr):
        if hasattr(stream, "reconfigure"):
            stream.reconfigure(encoding="utf-8", errors="replace")
    app()


if __name__ == "__main__":
    main()
