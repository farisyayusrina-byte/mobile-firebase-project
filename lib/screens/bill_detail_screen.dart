import 'package:flutter/material.dart';

import '../models/bill.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import '../widgets/split_widgets.dart';

class BillDetailScreen extends StatefulWidget {
  const BillDetailScreen({super.key, required this.bill});

  final Bill bill;

  @override
  State<BillDetailScreen> createState() => _BillDetailScreenState();
}

class _BillDetailScreenState extends State<BillDetailScreen> {
  final _firestore = FirestoreService();
  late List<BillItem> _items;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _items = List<BillItem>.from(widget.bill.items);
  }

  Future<void> _saveAssignments() async {
    setState(() => _saving = true);
    try {
      await _firestore.updateBillItems(widget.bill.id, _items);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Assignments saved')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _assignItem(int index, String? person) {
    setState(() {
      _items[index] = _items[index].copyWith(assignedTo: person ?? '');
    });
  }

  @override
  Widget build(BuildContext context) {
    final bill = widget.bill;
    final participants = bill.participants;

    return Scaffold(
      appBar: AppBar(title: Text(bill.title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (bill.receiptImageUrl != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                bill.receiptImageUrl!,
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  height: 120,
                  color: Colors.grey.shade200,
                  child: const Icon(Icons.broken_image, size: 48),
                ),
              ),
            ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.payments,
                      color: AppColors.primary,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Bill total',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                        Text(
                          'RM ${bill.total.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryDark,
                          ),
                        ),
                        if (bill.participants.isNotEmpty)
                          Text(
                            bill.participants.join(' · '),
                            style: const TextStyle(fontSize: 12),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (bill.ocrText != null && bill.ocrText!.isNotEmpty) ...[
            const SizedBox(height: 16),
            FormSectionCard(
              title: 'Receipt text (ML Kit)',
              icon: Icons.document_scanner,
              child: Text(
                bill.ocrText!,
                style: TextStyle(
                  color: Colors.grey.shade800,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
          const SectionTitle('Assign items to participants'),
          if (_items.isEmpty)
            const SplitEmptyState(
              icon: Icons.list_alt,
              title: 'No items',
              message: 'Add items from the add bill screen.',
            )
          else
            ...List.generate(_items.length, (index) {
              final item = _items[index];
              final assigned = item.assignedTo;
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          Text(
                            'RM ${item.price.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                      if (assigned.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Chip(
                          avatar: const Icon(Icons.person, size: 16),
                          label: Text(assigned),
                          backgroundColor:
                              AppColors.primary.withValues(alpha: 0.1),
                          labelStyle: const TextStyle(
                            color: AppColors.primaryDark,
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String?>(
                        initialValue:
                            assigned.isEmpty ? null : assigned,
                        decoration: const InputDecoration(
                          labelText: 'Assign to',
                          isDense: true,
                        ),
                        items: [
                          const DropdownMenuItem<String?>(
                            child: Text('— Select participant —'),
                          ),
                          ...participants.map(
                            (p) => DropdownMenuItem<String?>(
                              value: p,
                              child: Text(p),
                            ),
                          ),
                        ],
                        onChanged: (value) => _assignItem(index, value),
                      ),
                    ],
                  ),
                ),
              );
            }),
          const SizedBox(height: 80),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            onPressed: _saving || _items.isEmpty ? null : _saveAssignments,
            child: Text(_saving ? 'Saving...' : 'Save assignments'),
          ),
        ),
      ),
    );
  }
}
