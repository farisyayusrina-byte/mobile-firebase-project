import 'package:cloud_firestore/cloud_firestore.dart';

import 'firestore_service.dart';

/// Queues FCM messages in `fcm_outbox` for Cloud Functions to deliver.
class PushOutboxService {
  PushOutboxService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static const String outboxCollection = 'fcm_outbox';

  Future<String?> findUserIdByEmail(String email) async {
    final normalized = email.trim().toLowerCase();
    if (normalized.isEmpty) return null;

    final snap = await _firestore
        .collection(FirestoreService.usersCollection)
        .where('email', isEqualTo: normalized)
        .limit(1)
        .get();

    if (snap.docs.isEmpty) return null;
    return snap.docs.first.id;
  }

  /// Send split-request push to members who registered with the given emails.
  Future<int> sendSplitRequests({
    required String fromUserId,
    required String fromDisplayName,
    required String billId,
    required String billTitle,
    required Map<String, String> memberEmails,
    required Map<String, double> memberTotals,
  }) async {
    var sent = 0;
    final sender = fromDisplayName.trim().isEmpty ? 'Someone' : fromDisplayName.trim();

    for (final entry in memberEmails.entries) {
      final name = entry.key;
      if (name.toLowerCase() == 'you') continue;

      final email = entry.value.trim();
      if (email.isEmpty) continue;

      final toUserId = await findUserIdByEmail(email);
      if (toUserId == null || toUserId == fromUserId) continue;

      final owed = memberTotals[name] ?? 0;
      final owedText = owed > 0 ? ' You owe RM ${owed.toStringAsFixed(2)}.' : '';

      await _firestore.collection(outboxCollection).add({
        'fromUserId': fromUserId,
        'toUserId': toUserId,
        'title': 'Split request',
        'body': '$sender invited you to split "$billTitle".$owedText',
        'billId': billId,
        'type': 'split_request',
        'createdAt': FieldValue.serverTimestamp(),
      });
      sent++;
    }

    return sent;
  }
}
