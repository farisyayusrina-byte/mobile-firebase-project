import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/bill.dart';
import '../services/firestore_service.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import '../utils/settlement_calculator.dart';
import '../widgets/split_widgets.dart';
import 'bill_detail_screen.dart';

class SettleUpScreen extends StatefulWidget {
  const SettleUpScreen({super.key, required this.user});

  final User user;

  @override
  State<SettleUpScreen> createState() => _SettleUpScreenState();
}

class _SettleUpScreenState extends State<SettleUpScreen> {
  final _firestore = FirestoreService();
  final _notifications = NotificationService();
  final Set<String> _settling = {};

  Future<void> _settleBill(Bill bill) async {
    setState(() => _settling.add(bill.id));
    try {
      await _firestore.markBillSettled(bill.id);
      await _notifications.createNotification(
        userId: widget.user.uid,
        title: 'Payment settled',
        body: '${bill.title} marked as settled.',
        type: 'settlement',
        billId: bill.id,
        showLocalAlert: false,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${bill.title} settled')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _settling.remove(bill.id));
    }
  }

  Future<void> _settleWithPerson(
    PersonBalance person,
    List<Bill> allBills,
  ) async {
      final selfName =
          widget.user.displayName ?? widget.user.email?.split('@').first;
      final bills = SettlementCalculator.billsForPerson(
        allBills,
        person.name,
        selfName: selfName,
      );
    if (bills.isEmpty) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Settle with ${person.name}?'),
        content: Text(
          'Mark ${bills.length} bill(s) as settled.\n'
          'They owed you RM ${person.theyOweYou.toStringAsFixed(2)}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Settle all'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    try {
      await _firestore.markBillsSettled(bills.map((b) => b.id));
      await _notifications.createNotification(
        userId: widget.user.uid,
        title: 'Settled with ${person.name}',
        body: '${bills.length} bill(s) marked as paid.',
        type: 'settlement',
        showLocalAlert: false,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Settled with ${person.name}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: const Text('Settle Up')),
      body: StreamBuilder<List<Bill>>(
        stream: _firestore.watchBills(widget.user.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }
          if (snapshot.hasError) {
            return SplitErrorState(message: snapshot.error.toString());
          }

          final bills = snapshot.data ?? [];
          final selfName =
              widget.user.displayName ?? widget.user.email?.split('@').first;
          final summary = SettlementCalculator.fromBills(
            bills,
            selfName: selfName,
          );

          if (summary.people.isEmpty && summary.unsettledBills.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle_outline,
                        size: 56, color: AppColors.primary),
                    const SizedBox(height: 16),
                    const Text(
                      'All settled up!',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No outstanding balances right now.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            children: [
              Row(
                children: [
                  Expanded(
                    child: _SummaryTile(
                      label: 'You owe',
                      amount: summary.youOwe,
                      color: const Color(0xFFC62828),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SummaryTile(
                      label: 'Owed to you',
                      amount: summary.owedToYou,
                      color: const Color(0xFF2E7D32),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Net balance',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'RM ${summary.netBalance.abs().toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      summary.netBalance >= 0
                          ? 'Overall you are owed money'
                          : 'Overall you owe money',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (summary.people.isNotEmpty) ...[
                const SizedBox(height: 24),
                const Text(
                  'Settle with person',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                ...summary.people.map(
                  (p) => _PersonSettleCard(
                    balance: p,
                    onSettle: () => _settleWithPerson(p, bills),
                  ),
                ),
              ],
              if (summary.unsettledBills.isNotEmpty) ...[
                const SizedBox(height: 24),
                const Text(
                  'Unsettled bills',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                ...summary.unsettledBills.map(
                  (bill) => _BillSettleTile(
                    bill: bill,
                    loading: _settling.contains(bill.id),
                    onSettle: () => _settleBill(bill),
                    onOpen: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => BillDetailScreen(bill: bill),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.label,
    required this.amount,
    required this.color,
  });

  final String label;
  final double amount;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE0E8E2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          const SizedBox(height: 6),
          Text(
            'RM ${amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _PersonSettleCard extends StatelessWidget {
  const _PersonSettleCard({
    required this.balance,
    required this.onSettle,
  });

  final PersonBalance balance;
  final VoidCallback onSettle;

  @override
  Widget build(BuildContext context) {
    final p = balance;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: AppColors.primary.withValues(alpha: 0.15),
              child: Text(
                p.name.isNotEmpty ? p.name[0].toUpperCase() : '?',
                style: const TextStyle(color: AppColors.primary),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  if (p.theyOweYou > 0)
                    Text(
                      'Owes you RM ${p.theyOweYou.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF2E7D32),
                      ),
                    ),
                  if (p.youOweThem > 0)
                    Text(
                      'You owe RM ${p.youOweThem.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFFC62828),
                      ),
                    ),
                ],
              ),
            ),
            FilledButton(
              onPressed: onSettle,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 14),
              ),
              child: const Text('Settle'),
            ),
          ],
        ),
      ),
    );
  }
}

class _BillSettleTile extends StatelessWidget {
  const _BillSettleTile({
    required this.bill,
    required this.loading,
    required this.onSettle,
    required this.onOpen,
  });

  final Bill bill;
  final bool loading;
  final VoidCallback onSettle;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: onOpen,
        title: Text(bill.title),
        subtitle: Text(
          '${bill.participants.length} people · ${bill.status ?? 'pending'}',
        ),
        trailing: loading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : TextButton(
                onPressed: onSettle,
                child: const Text('Settle'),
              ),
        leading: Text(
          'RM ${bill.total.toStringAsFixed(2)}',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
      ),
    );
  }
}
