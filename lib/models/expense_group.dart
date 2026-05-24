import 'package:cloud_firestore/cloud_firestore.dart';

class GroupMember {
  const GroupMember({
    required this.name,
    this.email,
    this.userId,
  });

  final String name;
  final String? email;
  final String? userId;

  Map<String, dynamic> toMap() => {
        'name': name,
        'email': email?.trim().toLowerCase(),
        'userId': userId,
      };

  factory GroupMember.fromMap(Map<String, dynamic> map) {
    return GroupMember(
      name: map['name'] as String? ?? '',
      email: map['email'] as String?,
      userId: map['userId'] as String?,
    );
  }
}

class ExpenseGroup {
  const ExpenseGroup({
    required this.id,
    required this.name,
    required this.createdBy,
    required this.memberIds,
    required this.members,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String name;
  final String createdBy;
  final List<String> memberIds;
  final List<GroupMember> members;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  int get memberCount => members.length;

  factory ExpenseGroup.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return ExpenseGroup.fromMap(doc.id, data);
  }

  factory ExpenseGroup.fromFirestore(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return ExpenseGroup.fromMap(doc.id, doc.data());
  }

  factory ExpenseGroup.fromMap(String id, Map<String, dynamic> data) {
    final rawMembers = data['members'] as List<dynamic>? ?? [];
    final created = data['createdAt'];
    final updated = data['updatedAt'];

    return ExpenseGroup(
      id: id,
      name: data['name'] as String? ?? '',
      createdBy: data['createdBy'] as String? ?? '',
      memberIds: List<String>.from(data['memberIds'] as List? ?? []),
      members: rawMembers
          .map((e) => GroupMember.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
      createdAt: created is Timestamp ? created.toDate() : null,
      updatedAt: updated is Timestamp ? updated.toDate() : null,
    );
  }
}
