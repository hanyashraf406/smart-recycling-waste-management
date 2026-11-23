import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trash_to_cash/main.dart';

void main() {
  testWidgets('OnboardingScreen تظهر فيها العناصر الأساسية', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: OnboardingScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Skip'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);
    expect(find.byType(TrashLogo), findsOneWidget);
  });
}