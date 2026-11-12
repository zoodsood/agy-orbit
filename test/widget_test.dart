import 'package:flutter_test/flutter_test.dart';
import 'package:antigravity_flutter/main.dart';

void main() {
  testWidgets('AntigravityFlutterApp smoke test renders Manager Surface', (WidgetTester tester) async {
    await tester.pumpWidget(const AntigravityFlutterApp());
    await tester.pump();

    expect(find.text('Antigravity Orbit'), findsOneWidget);
    expect(find.text('Run Agent'), findsOneWidget);
  });
}
