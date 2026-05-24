import 'package:cloud_firestore/cloud_firestore.dart';

import '../data/demo_bills.dart';
import 'firestore_service.dart';

/// Inserts sample bills into Firestore for the logged-in user.
class DemoDataService {
  DemoDataService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static const _seedFlagField = 'demoDataSeeded';

  Future<bool> hasDemoData(String userId) async {
    final doc = await _firestore
        .collection(FirestoreService.usersCollection)
        .doc(userId)
        .get();
    return doc.data()?[_seedFlagField] == true;
  }

  /// Adds ~14 sample bills. Safe to call once; skips if already seeded.
  Future<int> seedDemoBills(
    String userId, {
    bool force = false,
    String? creatorEmail,
    String? creatorName,
  }) async {
    if (!force && await hasDemoData(userId)) {
      return 0;
    }

    final seeds = DemoBillSeed.samples();
    final batch = _firestore.batch();
    final billsRef = _firestore.collection(FirestoreService.billsCollection);
    final groupsRef = _firestore.collection('groups');

    final creator = creatorName ?? 'You';
    final email = creatorEmail ?? '';

    final roommatesRef = groupsRef.doc();
    batch.set(roommatesRef, {
      'name': 'Roommates',
      'createdBy': userId,
      'memberIds': [userId],
      'members': [
        {'name': creator, 'email': email, 'userId': userId},
        {'name': 'Ahmad', 'email': null, 'userId': null},
        {'name': 'Sarah', 'email': null, 'userId': null},
      ],
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    final officeRef = groupsRef.doc();
    batch.set(officeRef, {
      'name': 'Office Lunch',
      'createdBy': userId,
      'memberIds': [userId],
      'members': [
        {'name': creator, 'email': email, 'userId': userId},
        {'name': 'Mei Ling', 'email': null, 'userId': null},
      ],
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    for (var i = 0; i < seeds.length; i++) {
      final seed = seeds[i];
      final doc = billsRef.doc();
      String? groupId;
      if (i < 5) groupId = roommatesRef.id;
      if (i >= 5 && i < 8) groupId = officeRef.id;

      batch.set(doc, {
        'userId': userId,
        'title': seed.title,
        'total': seed.total,
        'participants': seed.participants,
        'items': seed.items.map((e) => e.toMap()).toList(),
        'category': seed.category,
        'status': seed.status,
        'splitMode': seed.splitMode,
        'receiptImageUrl': null,
        'ocrText': null,
        if (groupId != null) 'groupId': groupId,
        'createdAt': Timestamp.fromDate(seed.createdAt),
        'updatedAt': Timestamp.fromDate(seed.createdAt),
      });
    }

    batch.set(
      _firestore.collection(FirestoreService.usersCollection).doc(userId),
      {_seedFlagField: true, 'updatedAt': FieldValue.serverTimestamp()},
      SetOptions(merge: true),
    );

    await batch.commit();
    return seeds.length;
  }

  /// Removes all bills for user and clears seed flag (for re-seeding).
  Future<void> clearUserBills(String userId) async {
    final snap = await _firestore
        .collection(FirestoreService.billsCollection)
        .where('userId', isEqualTo: userId)
        .get();

    final groupsSnap = await _firestore
        .collection('groups')
        .where('createdBy', isEqualTo: userId)
        .get();

    final batch = _firestore.batch();
    for (final doc in snap.docs) {
      batch.delete(doc.reference);
    }
    for (final doc in groupsSnap.docs) {
      batch.delete(doc.reference);
    }
    batch.set(
      _firestore.collection(FirestoreService.usersCollection).doc(userId),
      {_seedFlagField: false},
      SetOptions(merge: true),
    );
    await batch.commit();
  }

  Future<int> reseedDemoBills(String userId) async {
    await clearUserBills(userId);
    return seedDemoBills(userId, force: true);
  }
}
