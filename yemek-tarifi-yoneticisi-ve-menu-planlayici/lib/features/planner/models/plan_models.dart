enum MealType {
  breakfast('Kahvaltı'),
  lunch('Öğle'),
  dinner('Akşam');

  const MealType(this.labelTr);
  final String labelTr;
}

class MealSlot {
  const MealSlot({
    required this.dayIndex,
    required this.meal,
    this.recipeId,
    this.servingsMultiplier = 1,
  });

  final int dayIndex;
  final MealType meal;
  final String? recipeId;
  /// Meal prep: 2 = çift porsiyon malzeme.
  final int servingsMultiplier;

  String get slotKey => '${dayIndex}_${meal.name}';

  Map<String, dynamic> toJson() => {
        'dayIndex': dayIndex,
        'meal': meal.name,
        'recipeId': recipeId,
        if (servingsMultiplier != 1) 'servingsMultiplier': servingsMultiplier,
      };

  factory MealSlot.fromJson(Map<String, dynamic> json) {
    return MealSlot(
      dayIndex: json['dayIndex'] as int,
      meal: MealType.values.firstWhere(
        (m) => m.name == json['meal'],
        orElse: () => MealType.lunch,
      ),
      recipeId: json['recipeId'] as String?,
      servingsMultiplier: json['servingsMultiplier'] as int? ?? 1,
    );
  }

  MealSlot copyWith({
    String? recipeId,
    int? servingsMultiplier,
    bool clearRecipe = false,
  }) {
    return MealSlot(
      dayIndex: dayIndex,
      meal: meal,
      recipeId: clearRecipe ? null : (recipeId ?? this.recipeId),
      servingsMultiplier: servingsMultiplier ?? this.servingsMultiplier,
    );
  }
}

class WeekPlan {
  const WeekPlan({
    required this.weekStartKey,
    required this.slots,
  });

  final String weekStartKey;
  final List<MealSlot> slots;

  MealSlot? slotAt(int dayIndex, MealType meal) {
    for (final s in slots) {
      if (s.dayIndex == dayIndex && s.meal == meal) return s;
    }
    return null;
  }

  String? recipeIdAt(int dayIndex, MealType meal) => slotAt(dayIndex, meal)?.recipeId;

  WeekPlan withSlot(
    int dayIndex,
    MealType meal,
    String? recipeId, {
    int servingsMultiplier = 1,
  }) {
    final updated = <MealSlot>[];
    var replaced = false;
    for (final s in slots) {
      if (s.dayIndex == dayIndex && s.meal == meal) {
        updated.add(
          s.copyWith(
            recipeId: recipeId,
            clearRecipe: recipeId == null,
            servingsMultiplier: recipeId == null ? 1 : servingsMultiplier,
          ),
        );
        replaced = true;
      } else {
        updated.add(s);
      }
    }
    if (!replaced) {
      updated.add(
        MealSlot(
          dayIndex: dayIndex,
          meal: meal,
          recipeId: recipeId,
          servingsMultiplier: servingsMultiplier,
        ),
      );
    }
    return WeekPlan(weekStartKey: weekStartKey, slots: updated);
  }

  Map<String, dynamic> toJson() => {
        'weekStartKey': weekStartKey,
        'slots': slots.map((s) => s.toJson()).toList(),
      };

  factory WeekPlan.fromJson(Map<String, dynamic> json) {
    final list = json['slots'] as List<dynamic>? ?? [];
    return WeekPlan(
      weekStartKey: json['weekStartKey'] as String,
      slots: list.map((e) => MealSlot.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }

  factory WeekPlan.empty(String weekStartKey) =>
      WeekPlan(weekStartKey: weekStartKey, slots: const []);

  Iterable<PlannedRecipe> get plannedRecipes sync* {
    for (final s in slots) {
      if (s.recipeId != null) {
        yield PlannedRecipe(
          recipeId: s.recipeId!,
          servingsMultiplier: s.servingsMultiplier,
        );
      }
    }
  }

  int get plannedMealCount => plannedRecipes.length;
}

class PlannedRecipe {
  const PlannedRecipe({
    required this.recipeId,
    this.servingsMultiplier = 1,
  });

  final String recipeId;
  final int servingsMultiplier;
}
