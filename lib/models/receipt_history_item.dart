import 'bill.dart';
import '../utils/category_utils.dart';

enum ReceiptStatus { split, pending, personal, settled }

class ReceiptHistoryItem {
  const ReceiptHistoryItem({required this.bill});

  final Bill bill;

  String get title => bill.title;
  double get total => bill.total;
  int get itemCount => bill.items.length;
  DateTime? get date => bill.createdAt;

  String get category =>
      bill.category ?? inferCategoryFromTitle(bill.title);

  ReceiptStatus get status {
    final stored = bill.status;
    if (stored != null) {
      switch (stored) {
        case 'split':
          return ReceiptStatus.split;
        case 'pending':
          return ReceiptStatus.pending;
        case 'settled':
          return ReceiptStatus.settled;
        default:
          return ReceiptStatus.personal;
      }
    }
    switch (computeBillStatus(bill.items)) {
      case 'split':
        return ReceiptStatus.split;
      case 'pending':
        return ReceiptStatus.pending;
      default:
        return ReceiptStatus.personal;
    }
  }

  static String formatDate(DateTime? date) {
    if (date == null) return 'Unknown date';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(date.year, date.month, date.day);
    final time =
        '${date.hour > 12 ? date.hour - 12 : (date.hour == 0 ? 12 : date.hour)}:'
        '${date.minute.toString().padLeft(2, '0')} '
        '${date.hour >= 12 ? 'PM' : 'AM'}';

    if (d == today) return 'Today, $time';
    final yesterday = today.subtract(const Duration(days: 1));
    if (d == yesterday) return 'Yesterday, $time';

    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year} • $time';
  }
}
