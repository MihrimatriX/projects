class SubtaskItem {
  const SubtaskItem({
    required this.id,
    required this.taskId,
    required this.title,
    this.done = false,
    this.sortOrder = 0,
  });

  final String id;
  final String taskId;
  final String title;
  final bool done;
  final int sortOrder;

  SubtaskItem copyWith({String? title, bool? done, int? sortOrder}) =>
      SubtaskItem(
        id: id,
        taskId: taskId,
        title: title ?? this.title,
        done: done ?? this.done,
        sortOrder: sortOrder ?? this.sortOrder,
      );
}
