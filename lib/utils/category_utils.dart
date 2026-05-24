import '../models/bill.dart';

/// Infer expense category from bill title / merchant name.
String inferCategoryFromTitle(String title) {
  final t = title.toLowerCase();
  if (t.contains('petron') ||
      t.contains('shell') ||
      t.contains('grab') ||
      t.contains('station') ||
      t.contains('transport') ||
      t.contains('uber')) {
    return 'Transport';
  }
  if (t.contains('uniqlo') ||
      t.contains('shop') ||
      t.contains('mall') ||
      t.contains('store')) {
    return 'Shopping';
  }
  if (t.contains('tgv') ||
      t.contains('cinema') ||
      t.contains('movie') ||
      t.contains('entertain')) {
    return 'Entertainment';
  }
  if (t.contains('grocery') ||
      t.contains('market') ||
      t.contains('lotus') ||
      t.contains('jaya') ||
      t.contains('giant')) {
    return 'Groceries';
  }
  return 'Food & Dining';
}

/// `split` | `pending` | `personal`
String computeBillStatus(List<BillItem> items) {
  if (items.isEmpty) return 'personal';
  final assigned = items.where((i) => i.assignedTo.isNotEmpty).length;
  if (assigned == items.length) return 'split';
  if (assigned > 0) return 'pending';
  return 'personal';
}
