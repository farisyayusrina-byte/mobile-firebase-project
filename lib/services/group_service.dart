import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/expense_group.dart';
import 'firestore_service.dart';

class GroupService {
  GroupService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static const String groupsCollection = 'groups';

  CollectionReference<Map<String, dynamic>> get _groups =>
      _firestore.collection(groupsCollection);

  Stream<List<ExpenseGroup>> watchMyGroups(String userId) {
    return _groups
        .where('memberIds', arrayContains: userId)
        .snapshots()
        .map((snap) {
          final list = snap.docs.map(ExpenseGroup.fromFirestore).toList();
          list.sort((a, b) {
            final ad = a.updatedAt ?? a.createdAt ?? DateTime(0);
            final bd = b.updatedAt ?? b.createdAt ?? DateTime(0);
            return bd.compareTo(ad);
          });
          return list;
        });
  }

  Future<String?> findUserIdByEmail(String email) async {
    final normalized = email.trim().toLowerCase();
    if (normalized.isEmpty) return null;
    try {
      final snap = await _firestore
          .collection(FirestoreService.usersCollection)
          .where('email', isEqualTo: normalized)
          .limit(1)
          .get();
      if (snap.docs.isEmpty) return null;
      return snap.docs.first.id;
    } catch (_) {
      // Rules may block user lookup; group still creates without linked uid.
      return null;
    }
  }

  Future<String> createGroup({
    required String userId,
    required String creatorName,
    required String creatorEmail,
    required String name,
    required List<GroupMember> extraMembers,
  }) async {
    final memberIds = <String>{userId};
    final members = <GroupMember>[
      GroupMember(name: creatorName, email: creatorEmail, userId: userId),
    ];

    for (final m in extraMembers) {
      var uid = m.userId;
      if ((uid == null || uid.isEmpty) &&
          m.email != null &&
          m.email!.isNotEmpty) {
        uid = await findUserIdByEmail(m.email!);
      }
      if (uid != null && uid.isNotEmpty) memberIds.add(uid);
      members.add(
        GroupMember(name: m.name, email: m.email, userId: uid),
      );
    }

    final doc = await _groups.add({
      'name': name.trim(),
      'createdBy': userId,
      'memberIds': memberIds.toList(),
      'members': members.map((e) => e.toMap()).toList(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return doc.id;
  }

  Future<void> addMemberByEmail({
    required String groupId,
    required String name,
    required String email,
  }) async {
    final ref = _groups.doc(groupId);
    final snap = await ref.get();
    if (!snap.exists) return;

    final data = snap.data()!;
    final members = (data['members'] as List<dynamic>? ?? [])
        .map((e) => GroupMember.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();

    if (members.any(
      (m) => m.email?.toLowerCase() == email.trim().toLowerCase(),
    )) {
      return;
    }

    final uid = await findUserIdByEmail(email);
    final newMember = GroupMember(
      name: name.trim(),
      email: email.trim().toLowerCase(),
      userId: uid,
    );
    members.add(newMember);

    final memberIds = List<String>.from(data['memberIds'] as List? ?? []);
    if (uid != null && !memberIds.contains(uid)) {
      memberIds.add(uid);
    }

    await ref.update({
      'members': members.map((e) => e.toMap()).toList(),
      'memberIds': memberIds,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<ExpenseGroup?> getGroup(String groupId) async {
    final snap = await _groups.doc(groupId).get();
    if (!snap.exists) return null;
    return ExpenseGroup.fromDoc(snap);
  }
}
