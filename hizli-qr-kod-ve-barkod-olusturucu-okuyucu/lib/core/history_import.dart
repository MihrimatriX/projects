import 'dart:convert';

class HistoryImportResult {
  const HistoryImportResult({
    required this.created,
    required this.scanned,
  });

  final List<String> created;
  final List<String> scanned;
}

abstract final class HistoryImport {
  static HistoryImportResult? parseJson(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;

      List<String> readList(dynamic value) {
        if (value is! List) return [];
        return value
            .whereType<String>()
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .take(50)
            .toList();
      }

      return HistoryImportResult(
        created: readList(decoded['created']),
        scanned: readList(decoded['scanned']),
      );
    } catch (_) {
      return null;
    }
  }
}
