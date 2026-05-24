import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/bill.dart';
import '../utils/category_utils.dart';

class FirestoreService {
  FirestoreService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static const String billsCollection = 'bills';
  static const String usersCollection = 'users';

  /// Save or update user profile in `users/{uid}`.
  Future<void> saveUserProfile({
    required String userId,
    required String email,
    required String displayName,
  }) async {
    final ref = _firestore.collection(usersCollection).doc(userId);
    final exists = (await ref.get()).exists;

    final data = <String, dynamic>{
      'email': email.trim().toLowerCase(),
      'displayName': displayName.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (!exists) {
      data['createdAt'] = FieldValue.serverTimestamp();
    }

    await ref.set(data, SetOptions(merge: true));
  }

  Future<void> saveFcmToken(String userId, String token) async {
    await _firestore.collection(usersCollection).doc(userId).set(
      {'fcmToken': token, 'updatedAt': FieldValue.serverTimestamp()},
      SetOptions(merge: true),
    );
  }

  Future<String> createBill({
    required String userId,
    required String title,
    required double total,
    required List<String> participants,
    List<String>? participantEmails,
    required List<BillItem> items,
    String? receiptImageUrl,
    String? ocrText,
    String? category,
    String? status,
    String? splitMode,
    String? groupId,
  }) async {
    final trimmedTitle = title.trim();
    final resolvedCategory =
        category ?? inferCategoryFromTitle(trimmedTitle);
    final resolvedStatus = status ?? computeBillStatus(items);

    final doc = await _firestore.collection(billsCollection).add({
      'userId': userId,
      'title': trimmedTitle,
      'total': total,
      'participants': participants,
      if (participantEmails != null && participantEmails.isNotEmpty)
        'participantEmails': participantEmails,
      'items': items.map((e) => e.toMap()).toList(),
      'receiptImageUrl': receiptImageUrl,
      'ocrText': ocrText,
      'category': resolvedCategory,
      'status': resolvedStatus,
      'splitMode': splitMode,
      if (groupId != null && groupId.isNotEmpty) 'groupId': groupId,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return doc.id;
  }

  Stream<List<Bill>> watchBills(String userId) {
    return _firestore
        .collection(billsCollection)
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
          final bills = snapshot.docs.map(Bill.fromFirestore).toList();
          bills.sort((a, b) {
            final aDate = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            final bDate = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            return bDate.compareTo(aDate);
          });
          return bills;
        });
  }

  Future<void> updateBillItems(String billId, List<BillItem> items) async {
    await _firestore.collection(billsCollection).doc(billId).update({
      'items': items.map((e) => e.toMap()).toList(),
      'status': computeBillStatus(items),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteBill(String billId) async {
    await _firestore.collection(billsCollection).doc(billId).delete();
  }

  Future<void> markBillSettled(String billId) async {
    await _firestore.collection(billsCollection).doc(billId).update({
      'status': 'settled',
      'settledAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> markBillsSettled(Iterable<String> billIds) async {
    final batch = _firestore.batch();
    for (final id in billIds) {
      batch.update(_firestore.collection(billsCollection).doc(id), {
        'status': 'settled',
        'settledAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  Stream<List<Bill>> watchBillsForGroup(String groupId) {
    return _firestore
        .collection(billsCollection)
        .where('groupId', isEqualTo: groupId)
        .snapshots()
        .map((snapshot) {
          final bills = snapshot.docs.map(Bill.fromFirestore).toList();
          bills.sort((a, b) {
            final aDate = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            final bDate = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            return bDate.compareTo(aDate);
          });
          return bills;
        });
  }
}
