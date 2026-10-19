import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:markdown_not_defteri/core/utils/format.dart';
import 'package:markdown_not_defteri/features/notes/data/markdown_files.dart';
import 'package:markdown_not_defteri/features/notes/models/note.dart';
import 'package:markdown_not_defteri/features/notes/presentation/editor_screen.dart';
import 'package:markdown_not_defteri/features/notes/presentation/notes_screen.dart';
import 'package:markdown_not_defteri/features/notes/providers/notes_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Note _note(String id, String title, String body, [int day = 1]) =>
    Note(id: id, title: title, body: body, updatedAt: DateTime(2026, 1, day));

Future<List<dynamic>> _storedNotes() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString('notes_v1');
  return raw == null ? [] : jsonDecode(raw) as List<dynamic>;
}

/// Editörü gerçek bir GoRouter yığınında açar (geri tuşu context.pop kullanır).
Future<void> _openEditor(WidgetTester tester, Widget editor) async {
  final router = GoRouter(routes: [
    GoRoute(
      path: '/',
      builder: (_, __) => Scaffold(
        body: Builder(
          builder: (c) => TextButton(
            onPressed: () => c.push('/e'),
            child: const Text('ac'),
          ),
        ),
      ),
    ),
    GoRoute(path: '/e', builder: (_, __) => editor),
  ]);
  tester.view.physicalSize = const Size(1400, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(child: MaterialApp.router(routerConfig: router)),
  );
  await tester.tap(find.text('ac'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('stripFrontMatter', () {
    test('YAML ön bilgisini atar (LF, CRLF, BOM)', () {
      expect(stripFrontMatter('---\ntitle: a\n---\n# Baslik'), '# Baslik');
      expect(stripFrontMatter('---\r\ntitle: a\r\n---\r\n# B'), '# B');
      expect(stripFrontMatter('﻿---\nx: 1\n...\nmetin'), 'metin');
    });

    test('yatay çizgi ve kapanmamış blok içeriği yutmaz', () {
      const hr = '---\nparagraf\n\nbaska';
      expect(stripFrontMatter(hr), hr);
      const dashes = '----\na\n---\nb';
      expect(stripFrontMatter(dashes), dashes);
      const notFirst = 'giris\n---\na\n---\nb';
      expect(stripFrontMatter(notFirst), notFirst);
    });
  });

  test('arama Türkçe büyük/küçük harf duyarsız; başlık ve gövdede arar', () {
    final notes = [
      _note('1', 'İstanbul gezisi', 'Boğaz'),
      _note('2', 'Alışveriş', 'IŞIK ampulü al'),
      _note('3', 'Kod', 'flutter test'),
    ];
    expect(filterNotes(notes, 'istanbul').map((n) => n.id), ['1']);
    expect(filterNotes(notes, 'ışık').map((n) => n.id), ['2']);
    expect(filterNotes(notes, 'FLUTTER').map((n) => n.id), ['3']);
    expect(filterNotes(notes, '  '), notes);
    expect(filterNotes(notes, 'yok'), isEmpty);
  });

  test('UTF-8 olmayan dosya reddedilir (otomatik kayıt bozmasın)', () {
    expect(decodeMarkdown(utf8.encode('# Çağrı')), '# Çağrı');
    expect(() => decodeMarkdown([0x23, 0x20, 0xFE, 0xE7]), throwsFormatException);
  });

  test('HTML dışa aktarma: GFM tablo, başlık kaçışlı, ön bilgi atılır', () {
    final html = markdownToHtmlDocument(
      'a<b>',
      '---\ngizli: 1\n---\n# Baslik\n\n| a | b |\n|---|---|\n| 1 | 2 |\n\n- [x] bitti',
    );
    expect(html, contains('<title>a&lt;b&gt;</title>'));
    expect(html, contains('<h1>Baslik</h1>'));
    expect(html, contains('<table>'));
    expect(html, contains('checkbox'));
    expect(html, isNot(contains('gizli')));
    expect(safeFileName('a:b/c?'), 'abc');
    expect(safeFileName('  '), 'not');
  });

  test('not deposu: ekle / düzenle / sil / geri al kalıcıdır', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final n = container.read(notesProvider.notifier);
    final a = await n.add('  ', 'gövde');
    expect(a.title, 'Başlıksız');
    await n.editNote(a, title: 'Yeni', body: 'değişti');
    expect((await _storedNotes()).single['body'], 'değişti');
    final edited = (await container.read(notesProvider.future)).single;
    await n.remove(a.id);
    expect(await _storedNotes(), isEmpty);
    await n.restore(edited);
    await n.restore(edited); // iki kez geri al çoğaltmaz
    expect((await _storedNotes()).single['title'], 'Yeni');
  });

  testWidgets('hızlı not 2 sn sonra kendiliğinden kaydedilir', (tester) async {
    await _openEditor(tester, const NoteEditorScreen());
    await tester.enterText(find.byType(TextField), '# Otomatik\n\nmetin');
    await tester.pump(const Duration(milliseconds: 500));
    expect(await _storedNotes(), isEmpty);
    await tester.pump(const Duration(seconds: 2));
    final stored = await _storedNotes();
    expect(stored.single['title'], 'Otomatik');
    expect(find.text('Kaydedildi'), findsOneWidget);

    // Sonraki düzenleme aynı notu günceller, yeni not eklemez.
    await tester.enterText(find.byType(TextField), '# Otomatik\n\nikinci');
    await tester.pump(const Duration(seconds: 3));
    final again = await _storedNotes();
    expect(again, hasLength(1));
    expect(again.single['body'], contains('ikinci'));
  });

  testWidgets('geri tuşu bekleyen değişikliği beklemeden kaydeder', (tester) async {
    await _openEditor(tester, const NoteEditorScreen());
    await tester.enterText(find.byType(TextField), '# Kaybolmasin');
    await tester.tap(find.byTooltip('Geri'));
    await tester.pumpAndSettle();
    expect(find.text('ac'), findsOneWidget); // ana ekrana dönüldü
    expect((await _storedNotes()).single['title'], 'Kaybolmasin');
  });

  testWidgets('dosya düzenlemesi geri dönerken diske yazılır', (tester) async {
    final dir = Directory.systemTemp.createTempSync('mdnot');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}${Platform.pathSeparator}a.md')
      ..writeAsStringSync('eski');
    await _openEditor(
      tester,
      NoteEditorScreen(filePath: file.path, initialBody: 'eski'),
    );
    await tester.enterText(find.byType(TextField), 'yeni içerik');
    await tester.tap(find.byTooltip('Geri'));
    // Gerçek dosya G/Ç'si sahte saatte ilerlemez: gerçek bekleme ile pump dönüşümlü.
    for (var i = 0; i < 100 && find.text('ac').evaluate().isEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(file.readAsStringSync(), 'yeni içerik');
    expect(find.text('ac'), findsOneWidget);
  });

  testWidgets('önizleme sıra dışı markdown ile çökmez', (tester) async {
    const tricky = '---\nsecret: x\n---\n'
        '# Başlık\n\n| a | b |\n|---|\n| tek |\n\n- [ ] yap\n- [x] bitti\n'
        '  - iç\n    - daha iç\n\n![kayip](yok/resim.png)\n![](https://)\n'
        '<div>ham html</div>\n\n```\nkod bloğu kapanmadı\n';
    for (final md in [tricky, '', '   \n\n', '[link]()', '> > > alıntı', '***']) {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: MarkdownPreview(markdown: md, dark: false)),
      ));
      await tester.pump();
      expect(tester.takeException(), isNull, reason: md);
    }
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: MarkdownPreview(markdown: tricky, dark: true)),
    ));
    expect(find.textContaining('secret', findRichText: true), findsNothing);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: MarkdownPreview(markdown: '  ', dark: false)),
    ));
    expect(find.text('Önizleme boş', findRichText: true), findsOneWidget);
  });

  testWidgets('not listesi: arama ve silmeyi geri alma', (tester) async {
    SharedPreferences.setMockInitialValues({
      'notes_v1': jsonEncode([
        _note('1', 'Alışveriş', 'süt', 2).toJson(),
        _note('2', 'Toplantı', 'İzmir ofisi', 1).toJson(),
      ]),
    });
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const ProviderScope(
      child: MaterialApp(home: NotesScreen()),
    ));
    await tester.pumpAndSettle();
    expect(find.text('2 not'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'izmir');
    await tester.pump();
    expect(find.text('1/2 not'), findsOneWidget);
    expect(find.text('Alışveriş'), findsNothing);

    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pump();
    expect(find.text('Eşleşen not yok'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '');
    await tester.pump();
    await tester.tap(find.byTooltip('Sil').first);
    await tester.pumpAndSettle();
    expect(await _storedNotes(), hasLength(1));
    await tester.tap(find.text('Geri al'));
    await tester.pumpAndSettle();
    expect(await _storedNotes(), hasLength(2));
  });
}
