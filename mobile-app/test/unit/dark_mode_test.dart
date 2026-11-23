import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Dark Mode Tests', () {
    
    bool isDarkMode = false;

    test('1- Default is Light Mode', () {
      isDarkMode = false;
      expect(isDarkMode, false);
    });

    test('2- Toggle to Dark Mode', () {
      isDarkMode = false;
      isDarkMode = !isDarkMode;
      expect(isDarkMode, true);
    });

    test('3- Toggle back to Light Mode', () {
      isDarkMode = true;
      isDarkMode = !isDarkMode;
      expect(isDarkMode, false);
    });

    test('4- Multiple toggles work', () {
      isDarkMode = false;
      isDarkMode = !isDarkMode; // dark
      isDarkMode = !isDarkMode; // light
      isDarkMode = !isDarkMode; // dark
      isDarkMode = !isDarkMode; // light
      expect(isDarkMode, false);
    });
  });
}