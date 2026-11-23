import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trash_to_cash/main.dart'; // تأكد أن اسم الحزمة صحيح (زي ما هو في pubspec.yaml)

void main() {
  testWidgets('يتحقق من ظهور شعار TrashLogo', (WidgetTester tester) async {
    // رسم الـ TrashLogo فقط
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: TrashLogo(size: 100),
          ),
        ),
      ),
    );

    // البحث عن الـ TrashLogo
    final logoFinder = find.byType(TrashLogo);

    // التأكد من وجوده مرة واحدة
    expect(logoFinder, findsOneWidget);
  });
}
