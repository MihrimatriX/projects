from __future__ import annotations

import tempfile
import unittest
import shutil
from pathlib import Path

from PIL import Image

from utils.audit import AuditEntry, AuditLog, now_iso
from utils.config import AppSettings, SETTINGS_FILE
from utils.exiftool_engine import _verify_checksum
from utils.hash_check import pixel_hash
from utils.metadata import collect_files, is_supported, predict_removed_tag_names, read_metadata_tags, strip_metadata
from utils.models import MetadataTag
from utils.presets import PRESETS, StripMode, resolve_exiftool_args, preset_choices
from utils.restore import has_backup, restore_backup
from utils.tag_labels import risk_level, tag_label


class PresetTests(unittest.TestCase):
    def test_preset_choices_not_empty(self) -> None:
        self.assertGreaterEqual(len(preset_choices()), 3)

    def test_gps_args(self) -> None:
        args = resolve_exiftool_args(StripMode.GPS_ONLY)
        self.assertIn("-GPS:all=", args)

    def test_selected_tags_args(self) -> None:
        args = resolve_exiftool_args(StripMode.SELECTED, custom_tags=["EXIF:Make", "GPS:GPSLatitude"])
        self.assertTrue(any("Make" in a or "GPS" in a for a in args))

    def test_social_media_preset(self) -> None:
        preset = PRESETS["social_media"]
        self.assertIn("-GPS:all=", preset.exiftool_args)


class TagLabelTests(unittest.TestCase):
    def test_gps_high_risk(self) -> None:
        self.assertEqual(risk_level("GPSLatitude"), "high")

    def test_make_low_risk(self) -> None:
        self.assertEqual(risk_level("Make"), "low")

    def test_turkish_label(self) -> None:
        self.assertEqual(tag_label("Make"), "Üretici")


class AuditTests(unittest.TestCase):
    def test_export_csv(self) -> None:
        log = AuditLog()
        log.add(
            AuditEntry(
                timestamp=now_iso(),
                file_path="test.jpg",
                success=True,
                tags_removed=3,
                removed_tags="Make; Model",
                backup_path="test.jpg.bak",
                engine="pillow",
                mode="all",
                hash_changed=False,
            )
        )
        with tempfile.TemporaryDirectory() as tmp:
            dest = Path(tmp) / "audit.csv"
            log.export_csv(dest)
            content = dest.read_text(encoding="utf-8-sig")
            self.assertIn("test.jpg", content)
            self.assertIn("Make; Model", content)


class CollectTests(unittest.TestCase):
    def test_collect_single_file(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "a.png"
            Image.new("RGB", (4, 4)).save(path)
            files = collect_files([path], recursive=True)
            self.assertEqual(len(files), 1)

    def test_is_supported_png(self) -> None:
        self.assertTrue(is_supported("photo.png"))


class ConfigTests(unittest.TestCase):
    def test_settings_roundtrip(self) -> None:
        original = SETTINGS_FILE
        with tempfile.TemporaryDirectory() as tmp:
            import utils.config as config_module

            config_module.SETTINGS_FILE = Path(tmp) / "settings.json"
            settings = AppSettings(backup_enabled=False, last_preset_id="gps_only")
            settings.save()
            loaded = AppSettings.load()
            self.assertFalse(loaded.backup_enabled)
            self.assertEqual(loaded.last_preset_id, "gps_only")
            config_module.SETTINGS_FILE = original


class ChecksumTests(unittest.TestCase):
    def test_missing_checksum_passes(self) -> None:
        with tempfile.NamedTemporaryFile(delete=False) as tmp:
            path = Path(tmp.name)
        try:
            self.assertTrue(_verify_checksum(path))
        finally:
            path.unlink(missing_ok=True)


class PillowStripTests(unittest.TestCase):
    def test_strip_all_removes_exif(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "sample.jpg"
            img = Image.new("RGB", (32, 32), color="red")
            exif = img.getexif()
            exif[0x010F] = "TestMake"
            img.save(path, exif=exif)

            before = read_metadata_tags(path)
            self.assertGreater(len(before), 0)

            result = strip_metadata(path, backup=False, mode=StripMode.ALL)
            after = read_metadata_tags(path)
            self.assertGreaterEqual(result.tags_removed, 1)
            self.assertLess(len(after), len(before))

    def test_gps_only_mode(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "sample.jpg"
            img = Image.new("RGB", (8, 8), color="green")
            exif = img.getexif()
            exif[0x010F] = "TestMake"
            img.save(path, exif=exif)

            strip_metadata(path, backup=False, mode=StripMode.CAMERA_ONLY)
            tags = read_metadata_tags(path)
            names = {t.name.split(":")[-1] for t in tags}
            self.assertNotIn("Make", names)

    def test_pixel_hash_stable_for_same_image(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "sample.png"
            Image.new("RGB", (16, 16), color="blue").save(path)
            self.assertEqual(pixel_hash(path), pixel_hash(path))


class DryRunTests(unittest.TestCase):
    def test_dry_run_does_not_create_backup(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "sample.jpg"
            img = Image.new("RGB", (8, 8), color="red")
            exif = img.getexif()
            exif[0x010F] = "Make"
            img.save(path, exif=exif)

            result = strip_metadata(path, backup=True, mode=StripMode.ALL, dry_run=True)
            self.assertTrue(result.dry_run)
            self.assertFalse(has_backup(path))
            self.assertGreater(result.tags_removed, 0)


class RestoreTests(unittest.TestCase):
    def test_restore_roundtrip(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "sample.jpg"
            Image.new("RGB", (4, 4), color="white").save(path)
            backup = path.with_suffix(path.suffix + ".bak")
            shutil.copy2(path, backup)
            path.write_bytes(b"tampered")
            restore_backup(path)
            self.assertEqual(path.read_bytes(), backup.read_bytes())


class PredictTests(unittest.TestCase):
    def test_predict_gps_only(self) -> None:
        tags = (
            MetadataTag("GPS:GPSLatitude", "GPS enlem", "41N", "high"),
            MetadataTag("EXIF:Make", "Üretici", "Apple", "low"),
        )
        removed = predict_removed_tag_names(tags, StripMode.GPS_ONLY)
        self.assertIn("GPS:GPSLatitude", removed)
        self.assertNotIn("EXIF:Make", removed)


class CustomTagParseTests(unittest.TestCase):
    def test_parse_comma_and_lines(self) -> None:
        from ui.widgets.custom_tags_dialog import parse_tag_input

        tags = parse_tag_input("Make, Model\nGPSLatitude")
        self.assertEqual(tags, ["Make", "Model", "GPSLatitude"])


if __name__ == "__main__":
    unittest.main()
