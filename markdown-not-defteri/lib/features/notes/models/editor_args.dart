import 'note.dart';

class EditorArgs {
  const EditorArgs({
    this.note,
    this.filePath,
    this.initialBody,
    this.initialTitle,
  });

  final Note? note;
  final String? filePath;
  final String? initialBody;
  final String? initialTitle;
}
