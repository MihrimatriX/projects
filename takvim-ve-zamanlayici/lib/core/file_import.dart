import 'dart:convert';

import 'package:file_picker/file_picker.dart';

Future<String?> pickTextFileContent({List<String>? extensions}) async {
  final result = await FilePicker.platform.pickFiles(
    type: extensions != null ? FileType.custom : FileType.any,
    allowedExtensions: extensions,
    withData: true,
  );
  if (result == null || result.files.isEmpty) return null;
  final file = result.files.first;
  if (file.bytes != null) {
    return utf8.decode(file.bytes!, allowMalformed: true); // Türkçe karakterler için UTF-8
  }
  return null;
}
