import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:markdown/markdown.dart' as md;

import '../../../core/utils/format.dart';

/// Tek başına açılabilen HTML belgesi (GitHub tarzı markdown: tablo, görev listesi).
String markdownToHtmlDocument(String title, String markdown) {
  final body = md.markdownToHtml(
    stripFrontMatter(markdown),
    extensionSet: md.ExtensionSet.gitHubFlavored,
  );
  return '<!doctype html>\n<html lang="tr">\n<head>\n<meta charset="utf-8">\n'
      '<title>${const HtmlEscape().convert(title)}</title>\n'
      '<style>body{max-width:720px;margin:40px auto;padding:0 16px;'
      'font-family:Georgia,serif;line-height:1.6}pre,code{font-family:Consolas,monospace;'
      'background:#f4f1ea}pre{padding:12px;overflow:auto}table{border-collapse:collapse}'
      'td,th{border:1px solid #ccc;padding:4px 8px}img{max-width:100%}</style>\n'
      '</head>\n<body>\n$body</body>\n</html>\n';
}

/// Diskten (masaüstü) ya da tarayıcıdan (web, yol yok) okunan markdown belgesi.
class PickedMarkdown {
  const PickedMarkdown({required this.name, required this.body, this.path});

  final String name;
  final String body;

  /// Web'de null: içerik yalnızca hızlı not olarak içe aktarılabilir.
  final String? path;

  String get title => name.replaceAll(RegExp(r'\.(md|markdown|txt)$'), '');
}

/// UTF-8 olmayan bir dosyayı sessizce bozuk karakterlerle açıp otomatik
/// kaydetmek dosyayı kalıcı olarak bozar; bu yüzden açmayı reddederiz.
String decodeMarkdown(List<int> bytes) {
  try {
    return utf8.decode(bytes);
  } on FormatException {
    throw const FormatException('Dosya UTF-8 değil; açılmadı (veri bozulmasın diye).');
  }
}

Future<String> readMarkdownFile(String path) async =>
    decodeMarkdown(await File(path).readAsBytes());

Future<PickedMarkdown?> pickMarkdown() async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['md', 'markdown', 'txt'],
    withData: kIsWeb,
  );
  if (result == null || result.files.isEmpty) return null;
  final file = result.files.single;
  if (kIsWeb) {
    final bytes = file.bytes;
    if (bytes == null) return null;
    return PickedMarkdown(name: file.name, body: decodeMarkdown(bytes));
  }
  final path = file.path;
  if (path == null) return null;
  return PickedMarkdown(
    name: file.name,
    body: await readMarkdownFile(path),
    path: path,
  );
}

/// Kaydetme penceresi açar ve içeriği yazar. Kaydedilen yolu ya da iptalde null döner.
/// Web'de dosya kaydı yoktur; çağıran panoya kopyalamalı.
Future<String?> exportText({
  required String fileName,
  required String content,
  required String extension,
}) async {
  var path = await FilePicker.platform.saveFile(
    dialogTitle: 'Dışa aktar',
    fileName: fileName,
    type: FileType.custom,
    allowedExtensions: [extension],
  );
  if (path == null) return null;
  if (!path.toLowerCase().endsWith('.$extension')) path = '$path.$extension';
  await File(path).writeAsString(content);
  return path;
}
