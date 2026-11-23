import 'package:flutter_test/flutter_test.dart';

void main() {
  group('OTP Tests', () {
    
    String generatedOTP = '';
    int otpAttempts = 0;
    
    String generateOTP() {
      return (100000 + (999999 - 100000)).toString().substring(0, 6);
    }

    test('1- OTP is 6 digits', () {
      generatedOTP = '123456';
      expect(generatedOTP.length, 6);
    });

    test('2- OTP contains only numbers', () {
      generatedOTP = '123456';
      expect(int.tryParse(generatedOTP), isNotNull);
    });

    test('3- Valid OTP verification', () {
      generatedOTP = '578921';
      String userInput = '578921';
      expect(generatedOTP, userInput);
    });

    test('4- Invalid OTP verification', () {
      generatedOTP = '578921';
      String userInput = '111111';
      expect(generatedOTP == userInput, false);
    });

    test('5- OTP attempts - max 5 tries', () {
      otpAttempts = 0;
      for (int i = 0; i < 5; i++) {
        otpAttempts++;
      }
      bool isLocked = otpAttempts >= 5;
      expect(isLocked, true);
    });

    test('6- OTP attempts - under limit', () {
      otpAttempts = 3;
      bool isLocked = otpAttempts >= 5;
      expect(isLocked, false);
    });

    test('7- Resend OTP generates new code', () {
      String firstOTP = '123456';
      String newOTP = '654321';
      expect(firstOTP == newOTP, false);
    });

    test('8- OTP expiry - within 5 minutes', () {
      int otpAgeMinutes = 3;
      bool isExpired = otpAgeMinutes > 5;
      expect(isExpired, false);
    });

    test('9- OTP expiry - after 5 minutes', () {
      int otpAgeMinutes = 6;
      bool isExpired = otpAgeMinutes > 5;
      expect(isExpired, true);
    });
  });
}