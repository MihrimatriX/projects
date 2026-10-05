class NoteItem {
  const NoteItem({
    required this.id,
    required this.text,
    required this.updatedAt,
  });

  final String id;
  final String text;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory NoteItem.fromJson(Map<String, dynamic> json) {
    return NoteItem(
      id: json['id'] as String,
      text: json['text'] as String,
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}
