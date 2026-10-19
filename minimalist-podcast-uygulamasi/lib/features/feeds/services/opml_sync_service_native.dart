import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OpmlSyncService {
  static const _folderKey = 'opml_sync_folder_v1';
  static const _mtimeKey = 'opml_sync_mtime_v1';

  Future<String?> getFolderPath() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_folderKey);
  }

  Future<void> setFolderPath(String? path) async {
    final prefs = await SharedPreferences.getInstance();
    if (path == null) {
      await prefs.remove(_folderKey);
      await prefs.remove(_mtimeKey);
    } else {
      await prefs.setString(_folderKey, path);
    }
  }

  Future<String?> pickFolder() =>
      FilePicker.platform.getDirectoryPath(dialogTitle: 'OPML klasörü seç');

  Future<String?> readOpmlFromFolder(String folderPath) async {
    final dir = Directory(folderPath);
    if (!dir.existsSync()) return null;
    final file = await _findOpmlFile(folderPath);
    if (file == null) return null;
    return file.readAsString();
  }

  Future<bool> shouldSync(String folderPath) async {
    final file = await _findOpmlFile(folderPath);
    if (file == null) return false;
    final mtime = await file.lastModified();
    final prefs = await SharedPreferences.getInstance();
    final last = prefs.getInt(_mtimeKey);
    if (last == null) return true;
    return mtime.millisecondsSinceEpoch > last;
  }

  Future<void> markSynced(String folderPath) async {
    final file = await _findOpmlFile(folderPath);
    if (file == null) return;
    final mtime = await file.lastModified();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_mtimeKey, mtime.millisecondsSinceEpoch);
  }

  Future<File?> _findOpmlFile(String folderPath) async {
    final dir = Directory(folderPath);
    if (!dir.existsSync()) return null;
    File? preferred;
    await for (final entity in dir.list()) {
      if (entity is! File) continue;
      final lower = entity.path.toLowerCase();
      if (!lower.endsWith('.opml') && !lower.endsWith('.xml')) continue;
      if (lower.contains('subscription') || lower.contains('podcast')) {
        return entity;
      }
      preferred ??= entity;
    }
    return preferred;
  }
}
