import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:markdown_not_defteri/app.dart';

void main() {
  testWidgets('ana sayfa gorunur', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: MyApp()));
    await tester.pumpAndSettle();
    expect(find.text('Hoş geldiniz'), findsOneWidget);
  });
}
