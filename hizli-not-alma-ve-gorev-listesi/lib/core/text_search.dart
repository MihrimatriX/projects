/// Türkçe duyarlı arama anahtarı: büyük/küçük harf ve i/ı/İ/I farkı yok sayılır.
///
/// Dart'ın `toLowerCase()`'i dil bağımsızdır: "İ" → "i̇" (i + birleşik nokta)
/// olur ve "ı" ile "i" ayrı kalır; bu yüzden "istanbul" araması "İSTANBUL"u
/// bulamıyordu.
String searchKey(String s) => s
    .replaceAll('İ', 'i')
    .replaceAll('I', 'i')
    .toLowerCase()
    .replaceAll('ı', 'i')
    .replaceAll('̇', '');

/// [text] içinde [query] geçiyor mu (boş sorgu her şeyle eşleşir).
bool matchesSearch(String text, String query) {
  final q = searchKey(query.trim());
  return q.isEmpty || searchKey(text).contains(q);
}
