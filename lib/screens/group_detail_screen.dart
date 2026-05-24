import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/expense_group.dart';
import '../services/firestore_service.dart';
import '../services/group_service.dart';
import '../theme/app_theme.dart';
import '../widgets/split_widgets.dart';
import 'add_bill_screen.dart';
import 'bill_detail_screen.dart';

class GroupDetailScreen extends StatefulWidget {
  const GroupDetailScreen({
    super.key,
    required this.user,
    required this.group,
  });

  final User user;
  final ExpenseGroup group;

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen> {
  final _groupService = GroupService();
  final _firestore = FirestoreService();
  late ExpenseGroup _group;

  @override
  void initState() {
    super.initState();
    _group = widget.group;
  }

  Future<void> _addMember() async {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add member'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await _groupService.addMemberByEmail(
        groupId: _group.id,
        name: nameController.text.trim(),
        email: emailController.text.trim(),
      );
      final updated = await _groupService.getGroup(_group.id);
      if (updated != null && mounted) setState(() => _group = updated);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    }
  }

  void _addExpense() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AddBillScreen(
          userId: widget.user.uid,
          groupId: _group.id,
          groupName: _group.name,
          defaultParticipants: _group.members.map((m) => m.name).toList(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: Text(_group.name)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addExpense,
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add expense', style: TextStyle(color: Colors.white)),
      ),
      body: StreamBuilder(
        stream: _firestore.watchBillsForGroup(_group.id),
        builder: (context, snapshot) {
          final bills = snapshot.data ?? [];
          final total = bills.fold<double>(0, (s, b) => s + b.total);

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 88),
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_group.memberCount} members',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'RM ${total.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Text(
                      'Total group spending',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  const Text(
                    'Members',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _addMember,
                    icon: const Icon(Icons.person_add_outlined, size: 18),
                    label: const Text('Add'),
                  ),
                ],
              ),
              ..._group.members.map(
                (m) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                      child: Text(
                        m.name.isNotEmpty ? m.name[0].toUpperCase() : '?',
                        style: const TextStyle(color: AppColors.primary),
                      ),
                    ),
                    title: Text(m.name),
                    subtitle: m.email != null ? Text(m.email!) : null,
                    trailing: m.userId == widget.user.uid
                        ? const Chip(label: Text('You'))
                        : null,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Group expenses',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              if (snapshot.connectionState == ConnectionState.waiting)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                )
              else if (snapshot.hasError)
                SplitErrorState(message: snapshot.error.toString())
              else if (bills.isEmpty)
                Container(
                  padding: const EdgeInsets.all(24),
                  alignment: Alignment.center,
                  child: Text(
                    'No expenses in this group yet.',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                )
              else
                ...bills.map(
                  (bill) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text(bill.title),
                      subtitle: Text(
                        '${bill.participants.length} people · ${bill.status ?? 'personal'}',
                      ),
                      trailing: Text(
                        'RM ${bill.total.toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => BillDetailScreen(bill: bill),
                          ),
                        );
                      },
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
