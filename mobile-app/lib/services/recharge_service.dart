import 'package:cloud_firestore/cloud_firestore.dart';
import 'counter_service.dart';
import 'notifications_service.dart';

class RechargeService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Future<Map<String, dynamic>> processRecharge({
    required String userId,
    required String serviceType,
    required String companyName,
    required String cardNumber,
    required double amountEgp,
    required int pointsUsed,
  }) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) throw Exception('User not found');

      final userData = userDoc.data()!;
      final int currentPoints = (userData['points'] as num?)?.toInt() ?? 0;

      if (currentPoints < pointsUsed) {
        throw Exception('Insufficient points');
      }

      final transactionId = await CounterService.getNextId('store_transaction');

      await _firestore.collection('users').doc(userId).update({
        'points': FieldValue.increment(-pointsUsed),
      });

      await _firestore.collection('withdrawal_requests').doc(transactionId).set({
        'transactionId': transactionId,
        'userId': userId,
        'serviceType': serviceType,
        'companyName': companyName,
        'cardNumber': cardNumber,
        'amountEgp': amountEgp,
        'pointsUsed': pointsUsed,
        'status': 'pending',
        'referenceNumber': '',
        'notes': '',
        'processedBy': '',
        'processedAt': null,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await NotificationsService.sendInAppNotification(
        userId: userId,
        title: 'طلب شحن جديد',
        body: 'تم إنشاء طلب شحن ${serviceType == 'water' ? 'مياه' : serviceType == 'electricity' ? 'كهرباء' : 'غاز'} بقيمة ${amountEgp.toStringAsFixed(2)} جنيه',
        type: 'withdrawal',
        transactionId: transactionId,
      );

      return {
        'success': true,
        'transactionId': transactionId,
        'pointsUsed': pointsUsed,
        'remainingPoints': currentPoints - pointsUsed,
      };
    } catch (e) {
      rethrow;
    }
  }

  static Future<void> confirmTransfer({
    required String transactionId,
    required String processedBy,
    required String referenceNumber,
  }) async {
    try {
      final requestDoc = await _firestore.collection('withdrawal_requests').doc(transactionId).get();
      if (!requestDoc.exists) throw Exception('Request not found');

      final data = requestDoc.data()!;
      final userId = data['userId'] as String;

      await _firestore.collection('withdrawal_requests').doc(transactionId).update({
        'status': 'completed',
        'referenceNumber': referenceNumber,
        'processedBy': processedBy,
        'processedAt': FieldValue.serverTimestamp(),
      });

      await NotificationsService.sendInAppNotification(
        userId: userId,
        title: 'تم تأكيد الشحن',
        body: 'تم تأكيد عملية الشحن بنجاح. الرقم المرجعي: $referenceNumber',
        type: 'withdrawal',
        transactionId: transactionId,
      );
    } catch (e) {
      rethrow;
    }
  }

  static Future<void> rejectTransfer({
    required String transactionId,
    required String processedBy,
    required String notes,
  }) async {
    try {
      final requestDoc = await _firestore.collection('withdrawal_requests').doc(transactionId).get();
      if (!requestDoc.exists) throw Exception('Request not found');

      final data = requestDoc.data()!;
      final userId = data['userId'] as String;
      final pointsUsed = data['pointsUsed'] as int;

      await _firestore.collection('users').doc(userId).update({
        'points': FieldValue.increment(pointsUsed),
      });

      await _firestore.collection('withdrawal_requests').doc(transactionId).update({
        'status': 'rejected',
        'notes': notes,
        'processedBy': processedBy,
        'processedAt': FieldValue.serverTimestamp(),
      });

      await NotificationsService.sendInAppNotification(
        userId: userId,
        title: 'تم رفض الشحن',
        body: 'تم رفض طلب الشحن. السبب: $notes. تم إرجاع $pointsUsed نقطة',
        type: 'withdrawal',
        transactionId: transactionId,
      );
    } catch (e) {
      rethrow;
    }
  }

  static Future<List<Map<String, dynamic>>> getWithdrawalRequests({
    String? statusFilter,
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async {
    try {
      Query query = _firestore.collection('withdrawal_requests').orderBy('createdAt', descending: true);

      if (statusFilter != null && statusFilter != 'all') {
        query = query.where('status', isEqualTo: statusFilter);
      }

      final snapshot = await query.get();

      List<Map<String, dynamic>> result = [];
      for (var doc in snapshot.docs) {
        var data = <String, dynamic>{};
        data.addAll(doc.data() as Map<String, dynamic>);
        data['id'] = doc.id;
        result.add(data);
      }
      return result;
    } catch (e) {
      return [];
    }
  }

  static Future<Map<String, dynamic>> getWithdrawalStats() async {
    try {
      final today = DateTime.now();
      final startOfDay = Timestamp.fromDate(DateTime(today.year, today.month, today.day));
      final endOfDay = Timestamp.fromDate(DateTime(today.year, today.month, today.day, 23, 59, 59));

      final todayRequests = await _firestore
          .collection('withdrawal_requests')
          .where('createdAt', isGreaterThanOrEqualTo: startOfDay)
          .where('createdAt', isLessThanOrEqualTo: endOfDay)
          .get();

      final pendingRequests = await _firestore
          .collection('withdrawal_requests')
          .where('status', isEqualTo: 'pending')
          .get();

      double totalAmountToday = 0;
      for (var doc in todayRequests.docs) {
        totalAmountToday += (doc.data()['amountEgp'] as num?)?.toDouble() ?? 0;
      }

      return {
        'todayRequests': todayRequests.docs.length,
        'totalAmountToday': totalAmountToday,
        'pendingRequests': pendingRequests.docs.length,
      };
    } catch (e) {
      return {
        'todayRequests': 0,
        'totalAmountToday': 0.0,
        'pendingRequests': 0,
      };
    }
  }
}