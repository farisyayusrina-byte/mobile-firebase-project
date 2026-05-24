import 'package:cloud_firestore/cloud_firestore.dart';

class BillItem {
  const BillItem({
    required this.name,
    required this.price,
    this.assignedTo = '',
  });

  final String name;
  final double price;
  final String assignedTo;

  Map<String, dynamic> toMap() => {
        'name': name,
        'price': price,
        'assignedTo': assignedTo,
      };

  factory BillItem.fromMap(Map<String, dynamic> map) {
    return BillItem(
      name: map['name'] as String? ?? '',
      price: (map['price'] as num?)?.toDouble() ?? 0,
      assignedTo: map['assignedTo'] as String? ?? '',
    );
  }

  BillItem copyWith({String? assignedTo}) {
    return BillItem(
      name: name,
      price: price,
      assignedTo: assignedTo ?? this.assignedTo,
    );
  }
}

class Bill {
  const Bill({
    required this.id,
    required this.userId,
    required this.title,
    required this.total,
    required this.participants,
    required this.items,
    this.receiptImageUrl,
    this.ocrText,
    this.category,
    this.status,
    this.splitMode,
    this.groupId,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String userId;
  final String title;
  final double total;
  final String? receiptImageUrl;
  final String? ocrText;
  final String? category;
  /// `split`, `pending`, or `personal`
  final String? status;
  /// `byItems` or `equally`
  final String? splitMode;
  final String? groupId;
  final List<String> participants;
  final List<BillItem> items;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory Bill.fromFirestore(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final rawItems = data['items'] as List<dynamic>? ?? [];
    final timestamp = data['createdAt'];

    final updated = data['updatedAt'];

    return Bill(
      id: doc.id,
      userId: data['userId'] as String? ?? '',
      title: data['title'] as String? ?? '',
      total: (data['total'] as num?)?.toDouble() ?? 0,
      receiptImageUrl: data['receiptImageUrl'] as String?,
      ocrText: data['ocrText'] as String?,
      category: data['category'] as String?,
      status: data['status'] as String?,
      splitMode: data['splitMode'] as String?,
      groupId: data['groupId'] as String?,
      participants: List<String>.from(data['participants'] as List? ?? []),
      items: rawItems
          .map((e) => BillItem.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
      createdAt: timestamp is Timestamp ? timestamp.toDate() : null,
      updatedAt: updated is Timestamp ? updated.toDate() : null,
    );
  }
}
