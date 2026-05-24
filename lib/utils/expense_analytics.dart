import '../models/bill.dart';
import '../models/receipt_history_item.dart';

enum ExpensePeriod { week, month, year }

class CategorySpend {
  const CategorySpend({
    required this.category,
    required this.amount,
    required this.color,
  });

  final String category;
  final double amount;
  final int color;
}

/// One bar in the overview chart.
class PeriodBucket {
  const PeriodBucket({
    required this.label,
    required this.key,
    required this.amount,
  });

  final String label;
  /// Month 1–12, day 1–31, or year.
  final int key;
  final double amount;
}

class ExpenseAnalytics {
  ExpenseAnalytics({
    required this.bills,
    this.period = ExpensePeriod.month,
    DateTime? anchor,
    this.selectedMonth,
    this.selectedYear,
  }) : anchor = anchor ?? DateTime.now();

  final List<Bill> bills;
  final ExpensePeriod period;
  final DateTime anchor;
  /// For [ExpensePeriod.month] — which month to show (defaults to current).
  final int? selectedMonth;
  final int? selectedYear;

  static const categoryColors = {
    'Food & Dining': 0xFF829C89,
    'Transport': 0xFF42A5F5,
    'Groceries': 0xFF66BB6A,
    'Shopping': 0xFFAB47BC,
    'Entertainment': 0xFFFF7043,
  };

  static const _monthLabels = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  static const _weekdayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  int get _year => selectedYear ?? anchor.year;

  int get _month => selectedMonth ?? anchor.month;

  DateTime get _weekStart {
    final d = DateTime(anchor.year, anchor.month, anchor.day);
    return d.subtract(Duration(days: d.weekday - DateTime.monday));
  }

  DateTime get _weekEnd => _weekStart.add(const Duration(days: 7));

  List<Bill> get _filteredBills {
    return bills.where((b) {
      final d = b.createdAt;
      if (d == null) return false;
      switch (period) {
        case ExpensePeriod.week:
          return !d.isBefore(_weekStart) && d.isBefore(_weekEnd);
        case ExpensePeriod.month:
          return d.year == _year && d.month == _month;
        case ExpensePeriod.year:
          return d.year == _year;
      }
    }).toList();
  }

  List<Bill> get _previousPeriodBills {
    return bills.where((b) {
      final d = b.createdAt;
      if (d == null) return false;
      switch (period) {
        case ExpensePeriod.week:
          final prevStart = _weekStart.subtract(const Duration(days: 7));
          final prevEnd = _weekStart;
          return !d.isBefore(prevStart) && d.isBefore(prevEnd);
        case ExpensePeriod.month:
          final prev = DateTime(_year, _month - 1);
          return d.year == prev.year && d.month == prev.month;
        case ExpensePeriod.year:
          return d.year == _year - 1;
      }
    }).toList();
  }

  double get totalExpenses =>
      _filteredBills.fold(0, (s, b) => s + b.total);

  double get previousPeriodTotal =>
      _previousPeriodBills.fold(0, (s, b) => s + b.total);

  double get percentVsPreviousPeriod {
    if (previousPeriodTotal <= 0) return 0;
    return ((totalExpenses - previousPeriodTotal) / previousPeriodTotal) * 100;
  }

  String get comparisonLabel {
    switch (period) {
      case ExpensePeriod.week:
        return 'vs last week';
      case ExpensePeriod.month:
        return 'vs last month';
      case ExpensePeriod.year:
        return 'vs last year';
    }
  }

  String get overviewTitle {
    switch (period) {
      case ExpensePeriod.week:
        return 'This Week';
      case ExpensePeriod.month:
        return 'Monthly Overview';
      case ExpensePeriod.year:
        return 'This Year';
    }
  }

  String get emptyDataMessage {
    switch (period) {
      case ExpensePeriod.week:
        return 'No spending data this week yet.';
      case ExpensePeriod.month:
        return 'No spending data for ${_monthLabels[_month - 1]} yet.';
      case ExpensePeriod.year:
        return 'No spending data for $_year yet.';
    }
  }

  Map<DateTime, double> get _dailyTotals {
    final map = <DateTime, double>{};
    for (final bill in _filteredBills) {
      final d = bill.createdAt!;
      final day = DateTime(d.year, d.month, d.day);
      map[day] = (map[day] ?? 0) + bill.total;
    }
    return map;
  }

  /// Lowest **daily** spending total in the selected period.
  double get lowestDay {
    final totals = _dailyTotals.values;
    if (totals.isEmpty) return 0;
    return totals.reduce((a, b) => a < b ? a : b);
  }

  /// Highest **daily** spending total in the selected period.
  double get highestDay {
    final totals = _dailyTotals.values;
    if (totals.isEmpty) return 0;
    return totals.reduce((a, b) => a > b ? a : b);
  }

  List<CategorySpend> get spendingByCategory {
    final map = <String, double>{};
    for (final bill in _filteredBills) {
      final cat = bill.category ?? ReceiptHistoryItem(bill: bill).category;
      map[cat] = (map[cat] ?? 0) + bill.total;
    }
    final list = map.entries
        .map(
          (e) => CategorySpend(
            category: e.key,
            amount: e.value,
            color: categoryColors[e.key] ?? 0xFF829C89,
          ),
        )
        .toList();
    list.sort((a, b) => b.amount.compareTo(a.amount));
    return list;
  }

  String? get topCategory =>
      spendingByCategory.isEmpty ? null : spendingByCategory.first.category;

  double monthlyTotalFor(int month, int year) {
    return bills.where((b) {
      final d = b.createdAt;
      if (d == null) return false;
      return d.year == year && d.month == month;
    }).fold(0, (s, b) => s + b.total);
  }

  /// Bars for the overview chart (depends on [period]).
  List<PeriodBucket> get overviewBuckets {
    switch (period) {
      case ExpensePeriod.week:
        return List.generate(7, (i) {
          final day = _weekStart.add(Duration(days: i));
          final amount = _dailyTotals[DateTime(day.year, day.month, day.day)] ?? 0;
          return PeriodBucket(
            label: _weekdayLabels[i],
            key: day.day,
            amount: amount,
          );
        });
      case ExpensePeriod.month:
        return List.generate(5, (i) {
          final dt = DateTime(_year, _month - 4 + i);
          final amount = monthlyTotalFor(dt.month, dt.year);
          return PeriodBucket(
            label: _monthLabels[dt.month - 1],
            key: dt.month,
            amount: amount,
          );
        });
      case ExpensePeriod.year:
        return List.generate(12, (i) {
          final month = i + 1;
          final amount = monthlyTotalFor(month, _year);
          return PeriodBucket(
            label: _monthLabels[i],
            key: month,
            amount: amount,
          );
        });
    }
  }

  List<String> get insights {
    final lines = <String>[];
    final pct = percentVsPreviousPeriod;
    if (previousPeriodTotal > 0) {
      if (pct < 0) {
        lines.add(
          'You spent ${pct.abs().toStringAsFixed(0)}% less than ${comparisonLabel.replaceFirst('vs ', '')}. Keep it up!',
        );
      } else if (pct > 0) {
        lines.add(
          'You spent ${pct.toStringAsFixed(0)}% more than ${comparisonLabel.replaceFirst('vs ', '')}.',
        );
      }
    }
    if (topCategory != null) {
      final scope = switch (period) {
        ExpensePeriod.week => 'this week',
        ExpensePeriod.month => 'in ${_monthLabels[_month - 1]}',
        ExpensePeriod.year => 'this year',
      };
      lines.add('$topCategory is your highest category $scope.');
    }
    final shoppingList =
        spendingByCategory.where((c) => c.category == 'Shopping');
    if (shoppingList.isNotEmpty && shoppingList.first.amount > 100) {
      lines.add('Consider setting a budget for Shopping expenses.');
    }
    if (lines.isEmpty) {
      lines.add('Add more receipts to unlock spending insights.');
    }
    return lines.take(3).toList();
  }
}
