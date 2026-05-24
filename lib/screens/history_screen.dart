import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/receipt_history_item.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import '../widgets/split_widgets.dart';
import 'bill_detail_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key, required this.user});

  final User user;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedCategory = 'All';
  bool _sortNewestFirst = true;

  static const _categories = [
    'All',
    'Food & Dining',
    'Transport',
    'Groceries',
    'Shopping',
    'Entertainment',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<ReceiptHistoryItem> _filterAndSort(List<ReceiptHistoryItem> items) {
    var list = items.where((item) {
      final matchesSearch = _searchQuery.isEmpty ||
          item.title.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesCategory = _selectedCategory == 'All' ||
          item.category == _selectedCategory;
      return matchesSearch && matchesCategory;
    }).toList();

    list.sort((a, b) {
      final ad = a.date ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bd = b.date ?? DateTime.fromMillisecondsSinceEpoch(0);
      return _sortNewestFirst ? bd.compareTo(ad) : ad.compareTo(bd);
    });
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final firestore = FirestoreService();

    return SafeArea(
      child: StreamBuilder(
        stream: firestore.watchBills(widget.user.uid),
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
          final allItems =
              bills.map((b) => ReceiptHistoryItem(bill: b)).toList();
          final filtered = _filterAndSort(allItems);

          final totalSpent =
              allItems.fold<double>(0, (s, i) => s + i.total);
          final splitCount = allItems
              .where((i) => i.status == ReceiptStatus.split)
              .length;

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            children: [
              const Text(
                'Receipt History',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'View and manage all your scanned receipts',
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _searchController,
                onChanged: (v) => setState(() => _searchQuery = v.trim()),
                decoration: InputDecoration(
                  hintText: 'Search receipts...',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 38,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _categories.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final cat = _categories[index];
                    final selected = cat == _selectedCategory;
                    return FilterChip(
                      label: Text(cat),
                      selected: selected,
                      onSelected: (_) =>
                          setState(() => _selectedCategory = cat),
                      selectedColor: AppColors.primary,
                      checkmarkColor: Colors.white,
                      labelStyle: TextStyle(
                        color: selected ? Colors.white : Colors.grey.shade700,
                        fontWeight:
                            selected ? FontWeight.w600 : FontWeight.normal,
                        fontSize: 13,
                      ),
                      backgroundColor: Colors.white,
                      side: BorderSide(
                        color: selected
                            ? AppColors.primary
                            : Colors.grey.shade300,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      value: '${allItems.length}',
                      label: 'Total Receipts',
                      valueColor: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _StatCard(
                      value: 'RM ${totalSpent.toStringAsFixed(0)}',
                      label: 'Total Spent',
                      valueColor: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _StatCard(
                      value: '$splitCount',
                      label: 'Bills Split',
                      valueColor: AppColors.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  const Text(
                    'All Receipts',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () =>
                        setState(() => _sortNewestFirst = !_sortNewestFirst),
                    icon: const Icon(Icons.filter_list, size: 18),
                    label: Text(_sortNewestFirst ? 'Sort' : 'Sort ↑'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (filtered.isEmpty)
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE0E8E2)),
                  ),
                  child: Center(
                    child: Text(
                      allItems.isEmpty
                          ? 'No receipts yet.\nScan a receipt to get started.'
                          : 'No receipts match your search.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ),
                )
              else
                ...filtered.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _ReceiptCard(
                      item: item,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                BillDetailScreen(bill: item.bill),
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

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.value,
    required this.label,
    required this.valueColor,
  });

  final String value;
  final String label;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE0E8E2)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: valueColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}

class _ReceiptCard extends StatelessWidget {
  const _ReceiptCard({required this.item, required this.onTap});

  final ReceiptHistoryItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE0E8E2)),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.receipt_long,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          'RM ${item.total.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Icon(
                          Icons.chevron_right,
                          color: Colors.grey.shade400,
                          size: 20,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${ReceiptHistoryItem.formatDate(item.date)} • '
                      '${item.itemCount} items',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _StatusChip(status: item.status),
                        const SizedBox(width: 8),
                        Text(
                          item.category,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final ReceiptStatus status;

  @override
  Widget build(BuildContext context) {
    late final Color bg;
    late final Color fg;
    late final String label;

    switch (status) {
      case ReceiptStatus.split:
        bg = AppColors.primary.withValues(alpha: 0.2);
        fg = AppColors.primaryDark;
        label = 'Split';
      case ReceiptStatus.pending:
        bg = const Color(0xFFFFF3E0);
        fg = const Color(0xFFE65100);
        label = 'Pending';
      case ReceiptStatus.personal:
        bg = const Color(0xFFE3F2FD);
        fg = const Color(0xFF1565C0);
        label = 'Personal';
      case ReceiptStatus.settled:
        bg = const Color(0xFFE8F5E9);
        fg = const Color(0xFF2E7D32);
        label = 'Settled';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }
}
