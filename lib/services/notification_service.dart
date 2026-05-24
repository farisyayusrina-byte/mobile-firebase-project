import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_notification.dart';
import 'messaging_service.dart';

/// In-app notification history (Firestore) + local device alerts.
class NotificationService {
  NotificationService({
    FirebaseFirestore? firestore,
    MessagingService? messaging,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _messaging = messaging ?? MessagingService();

  final FirebaseFirestore _firestore;
  final MessagingService _messaging;

  CollectionReference<Map<String, dynamic>> _collection(String userId) =>
      _firestore
          .collection('users')
          .doc(userId)
          .collection('notifications');

  Stream<List<AppNotification>> watchNotifications(String userId) {
    return _collection(userId).limit(50).snapshots().map((snap) {
      final list = snap.docs.map(AppNotification.fromFirestore).toList();
      list.sort((a, b) {
        final ad = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bd = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bd.compareTo(ad);
      });
      return list;
    });
  }

  Stream<int> watchUnreadCount(String userId) {
    return watchNotifications(userId).map(
      (list) => list.where((n) => !n.read).length,
    );
  }

  Future<String> createNotification({
    required String userId,
    required String title,
    required String body,
    String type = 'system',
    String? billId,
    bool showLocalAlert = true,
  }) async {
    final doc = await _collection(userId).add({
      'title': title,
      'body': body,
      'type': type,
      'billId': billId,
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
    });

    if (showLocalAlert) {
      await _messaging.showLocal(
        id: doc.id.hashCode,
        title: title,
        body: body,
      );
    }

    return doc.id;
  }

  Future<void> notifyBillSaved({
    required String userId,
    required String billTitle,
    required String billId,
    required List<String> members,
  }) async {
    final others = members.where((m) => m.toLowerCase() != 'you').toList();
    final memberText = others.isEmpty
        ? 'saved to your account'
        : 'split requests sent to ${others.join(', ')}';

    await createNotification(
      userId: userId,
      title: 'Bill saved',
      body: '$billTitle — $memberText',
      type: 'bill_saved',
      billId: billId,
    );
  }

  Future<void> notifySplitReminder({
    required String userId,
    required String billTitle,
    required double amount,
  }) async {
    await createNotification(
      userId: userId,
      title: 'Payment reminder',
      body: 'You owe RM ${amount.toStringAsFixed(2)} for $billTitle',
      type: 'reminder',
    );
  }

  Future<void> sendTestNotification(String userId) async {
    await createNotification(
      userId: userId,
      title: 'Test notification',
      body: 'Push and in-app notifications are working.',
      type: 'system',
    );
  }

  Future<void> markAsRead(String userId, String notificationId) async {
    await _collection(userId).doc(notificationId).update({'read': true});
  }

  Future<void> markAllAsRead(String userId) async {
    final snap = await _collection(userId)
        .where('read', isEqualTo: false)
        .get();
    final batch = _firestore.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {'read': true});
    }
    await batch.commit();
  }
}
