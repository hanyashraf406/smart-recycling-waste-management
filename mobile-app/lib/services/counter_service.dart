import 'package:cloud_firestore/cloud_firestore.dart';

class CounterService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Future<String> getNextId(String type) async {
    final counterRef = _firestore.collection('counters').doc('counters');

    return await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(counterRef);

      Map<String, dynamic> data;
      if (!snapshot.exists) {
        data = {
          'lastUserId': 0,
          'lastEmployeeId': 0,
          'lastProcessId': 0,
          'lastMaterialId': 3,
          'lastWarehouseId': 7,
          'lastStoreTransactionId': 0,
        };
        transaction.set(counterRef, data);
      } else {
        data = snapshot.data() as Map<String, dynamic>;
        if (!data.containsKey('lastStoreTransactionId')) {
          data['lastStoreTransactionId'] = 0;
        }
      }

      int nextNumber = 0;
      String prefix = '';

      switch (type) {
        case 'user':
          nextNumber = (data['lastUserId'] ?? 0) + 1;
          data['lastUserId'] = nextNumber;
          prefix = 'U';
          break;
        case 'employee':
          nextNumber = (data['lastEmployeeId'] ?? 0) + 1;
          data['lastEmployeeId'] = nextNumber;
          prefix = 'E';
          break;
        case 'process':
          nextNumber = (data['lastProcessId'] ?? 0) + 1;
          data['lastProcessId'] = nextNumber;
          prefix = 'RP';
          break;
        case 'material':
          nextNumber = (data['lastMaterialId'] ?? 3) + 1;
          data['lastMaterialId'] = nextNumber;
          prefix = 'M';
          break;
        case 'warehouse':
          nextNumber = (data['lastWarehouseId'] ?? 7) + 1;
          data['lastWarehouseId'] = nextNumber;
          prefix = 'WH';
          break;
        case 'store_transaction':
          nextNumber = (data['lastStoreTransactionId'] ?? 0) + 1;
          data['lastStoreTransactionId'] = nextNumber;
          prefix = 'ST';
          break;
      }

      transaction.update(counterRef, data);
      return '$prefix-${nextNumber.toString().padLeft(3, '0')}';
    });
  }
}