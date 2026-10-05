/// Malzeme satırı ayrıştırma ve aynı birimde birleştirme.
class MergedIngredient {
  const MergedIngredient({
    required this.key,
    required this.name,
    required this.amount,
    required this.unit,
  });

  final String key;
  final String name;

  /// Taban birimde miktar (g, ml, adet, yk, sb, çk). 0: miktarsız ("Tuz").
  final double amount;
  final String unit;

  /// "1,5 kg", "750 g", "2 adet"; miktarsızsa boş.
  String get quantityLabel => amount > 0 ? formatQuantity(amount, unit) : '';

  String get displayLabel => '$quantityLabel $name'.trim();
}

/// Miktarı okunur biçimde yazar: 1000 g ve üstü kg'a, 1000 ml ve üstü l'ye çevrilir;
/// en fazla 2 ondalık, Türkçe ondalık virgülü ("1,5 kg", "0,25 çk").
String formatQuantity(double amount, String unit) {
  var a = amount;
  var u = unit;
  if (u == 'g' && a >= 1000) {
    a /= 1000;
    u = 'kg';
  } else if (u == 'ml' && a >= 1000) {
    a /= 1000;
    u = 'l';
  }
  return '${formatAmount(a)} $u';
}

String formatAmount(double v) {
  final r = (v * 100).round() / 100;
  if (r == r.roundToDouble()) return r.toInt().toString();
  return r.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '').replaceAll('.', ',');
}

const _unicodeFractions = {'½': 0.5, '¼': 0.25, '¾': 0.75, '⅓': 1 / 3, '⅔': 2 / 3};

// Satır = [madde işareti] [miktar] [-üst sınır] [birim] ad. Miktar: "2", "1,5", "1/2",
// "1 1/2", "1½", "½". Birim yalnızca bilinen bir kelimeyse ayrılır; eskiden ilk kelime
// harf harf birim sanılıyordu ("3 yumurta" -> "yumurt a").
final _linePattern = RegExp(
  r'^\s*(?:[-•*]\s*)?'
  r'(?:((?:\d+(?:[.,]\d+)?(?:/\d+)?|[½¼¾⅓⅔])(?:\s*(?:\d+/\d+|[½¼¾⅓⅔]))?)'
  r'(?:\s*[-–]\s*(\d+(?:[.,]\d+)?))?\s*)?'
  r'(.+?)\s*$',
);

const _multiWordUnits = {'su bardağı': 'sb', 'yemek kaşığı': 'yk', 'çay kaşığı': 'çk'};

const _knownUnits = {
  'g', 'gr', 'gram', 'kg', 'kilogram', 'ml', 'mililitre', 'l', 'lt', 'litre',
  'adet', 'tane', 'diş', 'yk', 'sb', 'çk',
};

double _parseAmount(String raw) {
  var total = 0.0;
  for (final m in RegExp(r'\d+(?:[.,]\d+)?(?:/\d+)?|[½¼¾⅓⅔]').allMatches(raw)) {
    final t = m.group(0)!;
    final uf = _unicodeFractions[t];
    if (uf != null) {
      total += uf;
      continue;
    }
    final parts = t.replaceAll(',', '.').split('/');
    final a = double.tryParse(parts[0]) ?? 0;
    final b = parts.length == 2 ? double.tryParse(parts[1]) : null;
    total += (b != null && b != 0) ? a / b : a; // "1/2" -> 0.5, "1 1/2" -> 1.5
  }
  return total;
}

String _normalizeName(String name) =>
    name.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

String _normalizeUnit(String? raw) {
  if (raw == null || raw.isEmpty) return 'adet';
  final u = raw.toLowerCase();
  if (u == 'g' || u == 'gr' || u == 'gram') return 'g';
  if (u == 'kg' || u == 'kilogram') return 'kg';
  if (u == 'ml' || u == 'mililitre') return 'ml';
  if (u == 'l' || u == 'lt' || u == 'litre') return 'l';
  if (u == 'adet' || u == 'tane' || u == 'diş') return 'adet';
  if (u == 'yk' || u == 'yemek' || u == 'yemekkaşığı') return 'yk';
  if (u == 'sb' || u == 'su' || u == 'subardağı') return 'sb';
  if (u == 'çk' || u == 'çay' || u == 'çaykaşığı') return 'çk';
  return u;
}

(double amount, String unit) _toBase(double amount, String unit) {
  return switch (unit) {
    'kg' => (amount * 1000, 'g'),
    'l' => (amount * 1000, 'ml'),
    _ => (amount, unit),
  };
}

ParsedLine? parseIngredientLine(String line) {
  final trimmed = line.trim();
  if (trimmed.isEmpty) return null;

  final match = _linePattern.firstMatch(trimmed);
  if (match == null) {
    return ParsedLine(name: _normalizeName(trimmed), amount: 1, unit: 'adet', rawName: trimmed);
  }

  final amountRaw = match.group(1);
  // Aralıkta ("2-3 adet") alışverişte eksik kalmamak için üst sınır alınır.
  final upperRaw = match.group(2);
  var nameRaw = match.group(3)?.trim() ?? trimmed;

  // Miktarsız satır ("Tuz") 0 kalır: ölçeklenmez, listede yalnızca adı görünür.
  var amount = upperRaw != null
      ? _parseAmount(upperRaw)
      : amountRaw != null
          ? _parseAmount(amountRaw)
          : 0.0;
  if (amountRaw == null && RegExp(r'^yarım\s', caseSensitive: false).hasMatch(nameRaw)) {
    amount = 0.5;
    nameRaw = nameRaw.substring(5).trim();
  }

  var unit = 'adet';
  var explicitUnit = false;
  var name = nameRaw;
  final lower = nameRaw.toLowerCase();
  final multi = _multiWordUnits.keys.where((u) => lower.startsWith('$u ')).firstOrNull;
  if (multi != null) {
    unit = _multiWordUnits[multi]!;
    name = nameRaw.substring(multi.length).trim();
    explicitUnit = true;
  } else {
    final parts = nameRaw.split(RegExp(r'\s+'));
    if (parts.length > 1 && _knownUnits.contains(parts.first.toLowerCase())) {
      unit = _normalizeUnit(parts.first);
      name = parts.sublist(1).join(' ');
      explicitUnit = true;
    }
  }

  if (name.isEmpty) name = trimmed;
  final (baseAmount, baseUnit) = _toBase(amount, unit);
  return ParsedLine(
    name: _normalizeName(name),
    amount: baseAmount,
    unit: baseUnit,
    rawName: name.trim(),
    explicitUnit: explicitUnit,
  );
}

class ParsedLine {
  const ParsedLine({
    required this.name,
    required this.amount,
    required this.unit,
    String? rawName,
    this.explicitUnit = true,
  }) : rawName = rawName ?? name;

  /// Birleştirme anahtarı için küçük harfe çevrilmiş ad.
  final String name;
  final double amount;
  final String unit;

  /// Kullanıcının yazdığı haliyle ad (ölçeklenmiş satırda korunur).
  final String rawName;

  /// Satırda birim yazılı mıydı ("3 yumurta" -> false; ölçeklerken "adet" eklenmez).
  final bool explicitUnit;
}

List<MergedIngredient> mergeIngredientLines(Iterable<String> lines) {
  final map = <String, MergedIngredient>{};

  for (final line in lines) {
    final parsed = parseIngredientLine(line);
    if (parsed == null) continue;
    final key = '${parsed.name}|${parsed.unit}';
    final existing = map[key];
    map[key] = MergedIngredient(
      key: key,
      name: parsed.name,
      amount: (existing?.amount ?? 0) + parsed.amount,
      unit: parsed.unit,
    );
  }

  final list = map.values.toList()
    ..sort((a, b) => a.name.compareTo(b.name));
  return list;
}

List<String> collectIngredientLines(String ingredientsText) {
  return ingredientsText
      .split('\n')
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .toList();
}

/// Meal prep: malzeme miktarlarını çarpan ile ölçekler.
/// Çarpan kesirli olabilir (porsiyon küçültme: 0.5 gibi).
List<String> scaleIngredientLines(String ingredientsText, num multiplier) {
  if (multiplier == 1 || multiplier <= 0) return collectIngredientLines(ingredientsText);
  final lines = <String>[];
  for (final line in collectIngredientLines(ingredientsText)) {
    final parsed = parseIngredientLine(line);
    if (parsed == null || parsed.amount <= 0) {
      lines.add(line);
      continue;
    }
    final scaled = parsed.amount * multiplier;
    final qty = parsed.explicitUnit ? formatQuantity(scaled, parsed.unit) : formatAmount(scaled);
    lines.add('$qty ${parsed.rawName}');
  }
  return lines;
}

String scaleRecipeIngredientsDisplay(String ingredients, int multiplier) {
  return scaleIngredientLines(ingredients, multiplier).join('\n');
}
