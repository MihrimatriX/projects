class ProjectItem {
  const ProjectItem({
    required this.id,
    required this.name,
    this.colorIndex = 0,
    this.sortOrder = 0,
  });

  final String id;
  final String name;
  final int colorIndex;
  final int sortOrder;

  ProjectItem copyWith({String? name, int? colorIndex, int? sortOrder}) =>
      ProjectItem(
        id: id,
        name: name ?? this.name,
        colorIndex: colorIndex ?? this.colorIndex,
        sortOrder: sortOrder ?? this.sortOrder,
      );
}
