import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class OTPService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const _serviceId = 'service_k3yt6hr';
  static const _templateId = 'template_zp5xiii';
  static const _publicKey = 'agiSTZip5wWyIRDzX';
  static const _privateKey = 'RbmNT8IlUzgFBqCIAe8xz';

  static Future<bool> sendOTP(String email) async {
    try {
      final otp = (Random().nextInt(900000) + 100000).toString();
      await _storeOTP(email, otp);

      final url = Uri.parse('https://api.emailjs.com/api/v1.0/email/send');

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'service_id': _serviceId,
          'template_id': _templateId,
          'user_id': _publicKey,
          'accessToken': _privateKey,
          'template_params': {
            'otp': otp,
            'to_email': email.trim(),
          },
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  static Future<void> _storeOTP(String email, String otp) async {
    final userSnap = await _firestore
        .collection('users')
        .where('email', isEqualTo: email.trim())
        .limit(1)
        .get();

    if (userSnap.docs.isNotEmpty) {
      await _firestore.collection('users').doc(userSnap.docs.first.id).set({
        'otp': otp,
        'otpExpiry': FieldValue.serverTimestamp(),
        'otpAttempts': 0,
      }, SetOptions(merge: true));
      return;
    }

    final empSnap = await _firestore
        .collection('employees')
        .where('email', isEqualTo: email.trim())
        .limit(1)
        .get();

    if (empSnap.docs.isNotEmpty) {
      await _firestore.collection('employees').doc(empSnap.docs.first.id).set({
        'otp': otp,
        'otpExpiry': FieldValue.serverTimestamp(),
        'otpAttempts': 0,
      }, SetOptions(merge: true));
    }
  }

  static Future<bool> verifyOTP(String email, String otp) async {
    final data = await getOTPData(email);
    if (data == null) return false;

    final storedOTP = data['otp'] as String?;
    final attempts = (data['otpAttempts'] as num?)?.toInt() ?? 0;
    final expiry = data['otpExpiry'] as Timestamp?;

    if (attempts >= 5) return false;

    if (expiry != null) {
      final diff = DateTime.now().difference(expiry.toDate());
      if (diff.inMinutes > 5) return false;
    }

    if (storedOTP != otp) {
      await _incrementAttempts(email);
      return false;
    }

    await _clearOTP(email);
    return true;
  }

  static Future<Map<String, dynamic>?> getOTPData(String email) async {
    final userSnap = await _firestore
        .collection('users')
        .where('email', isEqualTo: email.trim())
        .limit(1)
        .get();
    if (userSnap.docs.isNotEmpty) return userSnap.docs.first.data();

    final empSnap = await _firestore
        .collection('employees')
        .where('email', isEqualTo: email.trim())
        .limit(1)
        .get();
    if (empSnap.docs.isNotEmpty) return empSnap.docs.first.data();

    return null;
  }

  static Future<void> _incrementAttempts(String email) async {
    try {
      final userSnap = await _firestore
          .collection('users')
          .where('email', isEqualTo: email).limit(1).get();
      if (userSnap.docs.isNotEmpty) {
        await _firestore.collection('users').doc(userSnap.docs.first.id).set({
          'otpAttempts': FieldValue.increment(1),
        }, SetOptions(merge: true));
      }
    } catch (e) {}
  }

  static Future<void> _clearOTP(String email) async {
    try {
      final userSnap = await _firestore
          .collection('users')
          .where('email', isEqualTo: email).limit(1).get();
      if (userSnap.docs.isNotEmpty) {
        await _firestore.collection('users').doc(userSnap.docs.first.id).set({
          'otp': FieldValue.delete(),
          'otpExpiry': FieldValue.delete(),
          'otpAttempts': FieldValue.delete(),
        }, SetOptions(merge: true));
      }
    } catch (e) {}
  }
}