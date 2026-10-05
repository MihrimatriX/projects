class Recipe {
  const Recipe({
    required this.id,
    required this.title,
    this.description = '',
    required this.ingredients,
    required this.steps,
    this.prepMinutes = 0,
    this.cookMinutes = 0,
    this.servings = 2,
    this.tags = const [],
  });

  final String id;
  final String title;
  final String description;
  final String ingredients;
  final String steps;
  final int prepMinutes;
  final int cookMinutes;
  final int servings;
  final List<String> tags;

  int get totalMinutes => prepMinutes + cookMinutes;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'ingredients': ingredients,
        'steps': steps,
        'prepMinutes': prepMinutes,
        'cookMinutes': cookMinutes,
        'servings': servings,
        'tags': tags,
      };

  factory Recipe.fromJson(Map<String, dynamic> json) {
    final tagsRaw = json['tags'];
    return Recipe(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String? ?? '',
      ingredients: json['ingredients'] as String? ?? '',
      steps: json['steps'] as String? ?? '',
      prepMinutes: json['prepMinutes'] as int? ?? 0,
      cookMinutes: json['cookMinutes'] as int? ?? 0,
      servings: json['servings'] as int? ?? 2,
      tags: tagsRaw is List
          ? tagsRaw.map((e) => e.toString()).toList()
          : const [],
    );
  }

  Recipe copyWith({
    String? title,
    String? description,
    String? ingredients,
    String? steps,
    int? prepMinutes,
    int? cookMinutes,
    int? servings,
    List<String>? tags,
  }) {
    return Recipe(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      ingredients: ingredients ?? this.ingredients,
      steps: steps ?? this.steps,
      prepMinutes: prepMinutes ?? this.prepMinutes,
      cookMinutes: cookMinutes ?? this.cookMinutes,
      servings: servings ?? this.servings,
      tags: tags ?? this.tags,
    );
  }

  /// [ingredientLines] ve [servingsOverride] verilirse ölçeklenmiş tarif yazılır.
  String toPrintText({List<String>? ingredientLines, int? servingsOverride}) {
    final buffer = StringBuffer()
      ..writeln(title)
      ..writeln('=' * title.length);
    if (description.isNotEmpty) {
      buffer.writeln(description);
      buffer.writeln();
    }
    if (totalMinutes > 0 || servings > 0) {
      buffer.writeln(
        'Hazırlık: $prepMinutes dk · Pişirme: $cookMinutes dk · ${servingsOverride ?? servings} porsiyon',
      );
      buffer.writeln();
    }
    if (tags.isNotEmpty) {
      buffer.writeln('Etiketler: ${tags.join(', ')}');
      buffer.writeln();
    }
    buffer.writeln('Malzemeler');
    buffer.writeln('------------');
    for (final line in ingredientLines ?? ingredients.split('\n')) {
      final t = line.trim();
      if (t.isNotEmpty) buffer.writeln('• $t');
    }
    buffer.writeln();
    buffer.writeln('Adımlar');
    buffer.writeln('-------');
    var step = 1;
    for (final line in steps.split('\n')) {
      final t = line.trim();
      if (t.isEmpty) continue;
      buffer.writeln('$step. $t');
      step++;
    }
    return buffer.toString();
  }
}
