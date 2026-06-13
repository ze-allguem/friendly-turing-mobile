import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_reader/main.dart';

void main() {
  testWidgets('Lumina Reader smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const LuminaReaderApp());
    expect(find.text('Lumina Reader'), findsOneWidget);
  });
}
