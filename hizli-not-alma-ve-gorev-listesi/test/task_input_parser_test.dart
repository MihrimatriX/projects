import 'package:flutter_test/flutter_test.dart';
import 'package:hizli_not_alma_ve_gorev_listesi/core/task_input_parser.dart';

void main() {
  test('çıkarır #etiket ve @bağlam', () {
    final p = parseTaskInput('#urgent @ev Market al');
    expect(p.title, 'Market al');
    expect(p.hashTags, ['urgent']);
    expect(p.contexts, ['ev']);
    expect(p.allTagNames, contains('#urgent'));
    expect(p.allTagNames, contains('@ev'));
  });

  test('boş başlık etiketlerden sonra', () {
    final p = parseTaskInput('#only');
    expect(p.title, isEmpty);
  });
}
