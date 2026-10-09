import 'package:flutter_test/flutter_test.dart';

import 'package:agent_inteligence/main.dart';

void main() {
  testWidgets('Login page renders', (WidgetTester tester) async {
    await tester.pumpWidget(const BusinessIntelligenceApp());

    expect(find.text('Stambuk'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('MASUK'), findsOneWidget);
  });
}
