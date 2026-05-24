import 'package:cloud_firestore/cloud_firestore.dart';

class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.read,
    this.billId,
    this.createdAt,
  });

  final String id;
  final String title;
  final String body;
  final String type;
  final bool read;
  final String? billId;
  final DateTime? createdAt;

  factory AppNotification.fromFirestore(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final ts = data['createdAt'];
    return AppNotification(
      id: doc.id,
      title: data['title'] as String? ?? '',
      body: data['body'] as String? ?? '',
      type: data['type'] as String? ?? 'system',
      read: data['read'] as bool? ?? false,
      billId: data['billId'] as String?,
      createdAt: ts is Timestamp ? ts.toDate() : null,
    );
  }
}
