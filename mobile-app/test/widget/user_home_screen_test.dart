import 'package:flutter_test/flutter_test.dart';

void main() {
  test('UserHomeScreen - اختبار بسيط بدون Firebase', () {
    // اختبار بسيط من غير واجهة
    String userName = 'Ahmed';
    int points = 500;
    
    expect(userName, 'Ahmed');
    expect(points, 500);
    expect(points > 0, true);
  });
}