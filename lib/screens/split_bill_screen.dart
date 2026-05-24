import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/bill.dart';
import '../models/split_bill_data.dart';
import '../services/firestore_service.dart';
import '../services/notification_service.dart';
import '../services/push_outbox_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../utils/category_utils.dart';

enum SplitMode { byItems, equally }

class SplitBillScreen extends StatefulWidget {
  const SplitBillScreen({
    super.key,
    required this.userId,
    required this.fromDisplayName,
    required this.data,
    required this.onScanReceipt,
    this.onBillSaved,
  });

  final String userId;
  final String fromDisplayName;
  final SplitBillData? data;
  final VoidCallback onScanReceipt;
  final VoidCallback? onBillSaved;

  @override
  State<SplitBillScreen> createState() => _SplitBillScreenState();
}

class _SplitBillScreenState extends State<SplitBillScreen> {
  final _firestore = FirestoreService();
  final _storage = StorageService();
  final _notifications = NotificationService();
  final _pushOutbox = PushOutboxService();
  final Map<String, String> _memberEmails = {};

  SplitMode _mode = SplitMode.byItems;
  late List<String> _members;
  late List<SplitLineItem> _items;
  double _total = 0;
  XFile? _receiptImage;
  String? _ocrText;
  String? _suggestedTitle;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadData(widget.data);
  }

  @override
  void didUpdateWidget(SplitBillScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data != widget.data) {
      _loadData(widget.data);
    }
  }

  void _loadData(SplitBillData? data) {
    if (data == null) {
      _members = ['You'];
      _items = [];
      _total = 0;
      _receiptImage = null;
      _ocrText = null;
      _suggestedTitle = null;
      return;
    }
    _receiptImage = data.receiptImage;
    _ocrText = data.ocrText;
    _suggestedTitle = data.suggestedTitle;
    _members = List<String>.from(data.members);
    _items = data.items
        .map(
          (e) => SplitLineItem(
            name: e.name,
            price: e.price,
            assignedTo: e.assignedTo,
          ),
        )
        .toList();
    _total = data.total > 0
        ? data.total
        : _items.fold(0, (s, i) => s + i.price);
  }

  Map<String, double> get _memberTotals {
    final totals = {for (final m in _members) m: 0.0};
    if (_mode == SplitMode.equally && _members.isNotEmpty) {
      final share = _total / _members.length;
      for (final m in _members) {
        totals[m] = share;
      }
      return totals;
    }
    for (final item in _items) {
      final who = item.assignedTo;
      if (who != null && who.isNotEmpty && totals.containsKey(who)) {
        totals[who] = totals[who]! + item.price;
      }
    }
    return totals;
  }

  void _assignItem(int index, String? member) {
    setState(() => _items[index].assignedTo = member);
  }

  Future<void> _addMember() async {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final result = await showDialog<({String name, String email})>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add member'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'e.g. Ahmad',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email (for push)',
                hintText: 'friend@email.com',
                helperText: 'Must match their Split app login email',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final name = nameController.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(
                context,
                (name: name, email: emailController.text.trim()),
              );
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (result != null && !_members.contains(result.name)) {
      setState(() {
        _members.add(result.name);
        if (result.email.isNotEmpty) {
          _memberEmails[result.name] = result.email;
        }
      });
    }
  }

  Future<void> _confirmAndSave() async {
    final defaultTitle = _suggestedTitle?.trim().isNotEmpty == true
        ? _suggestedTitle!.trim()
        : 'Receipt ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}';

    final titleController = TextEditingController(text: defaultTitle);
    final title = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save bill'),
        content: TextField(
          controller: titleController,
          decoration: const InputDecoration(
            labelText: 'Bill title',
            hintText: 'e.g. Lunch at Mamak',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(context, titleController.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (title == null || title.isEmpty || !mounted) return;

    setState(() => _saving = true);
    try {
      String? imageUrl;
      if (_receiptImage != null) {
        imageUrl = await _storage.uploadReceiptImage(_receiptImage!);
      }

      final billItems = _items
          .map(
            (e) => BillItem(
              name: e.name,
              price: e.price,
              assignedTo: e.assignedTo ?? '',
            ),
          )
          .toList();

      final splitMode =
          _mode == SplitMode.equally ? 'equally' : 'byItems';

      final billId = await _firestore.createBill(
        userId: widget.userId,
        title: title,
        total: _total,
        participants: _members,
        items: billItems,
        receiptImageUrl: imageUrl,
        ocrText: _ocrText,
        category: inferCategoryFromTitle(title),
        status: computeBillStatus(billItems),
        splitMode: splitMode,
      );

      await _notifications.notifyBillSaved(
        userId: widget.userId,
        billTitle: title,
        billId: billId,
        members: _members,
      );

      final pushCount = await _pushOutbox.sendSplitRequests(
        fromUserId: widget.userId,
        fromDisplayName: widget.fromDisplayName,
        billId: billId,
        billTitle: title,
        memberEmails: _memberEmails,
        memberTotals: _memberTotals,
      );

      if (!mounted) return;
      if (pushCount > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '$pushCount split request(s) sent via Cloud Function',
            ),
          ),
        );
      }
      if (widget.onBillSaved != null) {
        widget.onBillSaved!();
      } else {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bill saved')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save bill: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  Color _avatarColor(String name) {
    final colors = [
      const Color(0xFF90A4AE),
      const Color(0xFF81D4FA),
      const Color(0xFFCE93D8),
      const Color(0xFFF48FB1),
      const Color(0xFFA5D6A7),
    ];
    return colors[name.hashCode.abs() % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    if (widget.data == null || _items.isEmpty) {
      return SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.receipt_long, size: 56, color: AppColors.primary),
                const SizedBox(height: 16),
                const Text(
                  'No bill to split yet',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Scan a receipt first, then tap Split Bill.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: widget.onScanReceipt,
                  child: const Text('Go to Scan'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final totals = _memberTotals;

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              children: [
                const Text(
                  'Split Bill',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Assign items to group members for accurate splitting',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 20),
                _ModeToggle(
                  mode: _mode,
                  onChanged: (m) => setState(() => _mode = m),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    const Text(
                      'Group Members',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: _addMember,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 100,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _members.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 16),
                    itemBuilder: (context, index) {
                      final name = _members[index];
                      final amount = totals[name] ?? 0;
                      return Column(
                        children: [
                          CircleAvatar(
                            radius: 26,
                            backgroundColor: _avatarColor(name),
                            child: Text(
                              _initials(name),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            name,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            'RM ${amount.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    const Text(
                      'Items to Split',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'Total: RM ${_total.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...List.generate(_items.length, (index) {
                  final item = _items[index];
                  final assigned = item.assignedTo;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE0E8E2)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.grey.shade400,
                                style: BorderStyle.solid,
                              ),
                            ),
                            child: Icon(
                              Icons.image_outlined,
                              color: Colors.grey.shade500,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  assigned == null || assigned.isEmpty
                                      ? 'Not assigned'
                                      : assigned,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: assigned == null || assigned.isEmpty
                                        ? Colors.grey.shade500
                                        : AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            'RM ${item.price.toStringAsFixed(2)}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(width: 4),
                          if (_mode == SplitMode.byItems)
                            DropdownButtonHideUnderline(
                              child: DropdownButton<String?>(
                                value: assigned?.isEmpty ?? true
                                    ? null
                                    : assigned,
                                icon: const Icon(Icons.keyboard_arrow_down),
                                items: [
                                  const DropdownMenuItem<String?>(
                                    child: Text('—'),
                                  ),
                                  ..._members.map(
                                    (m) => DropdownMenuItem<String?>(
                                      value: m,
                                      child: Text(m),
                                    ),
                                  ),
                                ],
                                onChanged: (v) => _assignItem(index, v),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 16),
                _BillSummaryCard(
                  total: _total,
                  members: _members,
                  totals: totals,
                  saving: _saving,
                  onConfirm: _confirmAndSave,
                ),
                const SizedBox(height: 80),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeToggle extends StatelessWidget {
  const _ModeToggle({required this.mode, required this.onChanged});

  final SplitMode mode;
  final ValueChanged<SplitMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFEEEFED),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: _ModeChip(
              label: 'By Items',
              selected: mode == SplitMode.byItems,
              onTap: () => onChanged(SplitMode.byItems),
            ),
          ),
          Expanded(
            child: _ModeChip(
              label: 'Split Equally',
              selected: mode == SplitMode.equally,
              onTap: () => onChanged(SplitMode.equally),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : Colors.grey.shade700,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _BillSummaryCard extends StatelessWidget {
  const _BillSummaryCard({
    required this.total,
    required this.members,
    required this.totals,
    required this.onConfirm,
    this.saving = false,
  });

  final double total;
  final List<String> members;
  final Map<String, double> totals;
  final VoidCallback onConfirm;
  final bool saving;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Text(
                'Bill Summary',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const Spacer(),
              Text(
                'RM ${total.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...members.map(
            (m) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Text(m, style: const TextStyle(color: Colors.white)),
                  const Spacer(),
                  Text(
                    'RM ${(totals[m] ?? 0).toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton(
              onPressed: saving ? null : onConfirm,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFF5F6F4),
                foregroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              child: saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary,
                      ),
                    )
                  : const Text(
                      'Confirm & Save Bill',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
