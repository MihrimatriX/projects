class TagItem {
  const TagItem({
    required this.id,
    required this.name,
    this.colorIndex = 0,
  });

  final String id;
  final String name;
  final int colorIndex;

  /// Görüntüleme: #urgent veya @ev
  String get display {
    if (name.startsWith('@')) return name;
    return name.startsWith('#') ? name : '#$name';
  }
}
