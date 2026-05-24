import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import '../utils/expense_analytics.dart';
import '../widgets/split_widgets.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key, required this.user});

  final User user;

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  ExpensePeriod _period = ExpensePeriod.month;
  int _selectedMonth = DateTime.now().month;
  int? _highlightedChartKey;

  void _onPeriodChanged(ExpensePeriod p) {
    setState(() {
      _period = p;
      _selectedMonth = DateTime.now().month;
      _highlightedChartKey = null;
    });
  }

  void _onChartBucketTap(PeriodBucket bucket) {
    setState(() {
      if (_period == ExpensePeriod.month) {
        _selectedMonth = bucket.key;
      } else if (_period == ExpensePeriod.year) {
        _highlightedChartKey = bucket.key;
      } else {
        _highlightedChartKey = bucket.key;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final firestore = FirestoreService();
    final now = DateTime.now();

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
          final analytics = ExpenseAnalytics(
            bills: bills,
            period: _period,
            anchor: now,
            selectedMonth: _period == ExpensePeriod.month ? _selectedMonth : null,
            selectedYear: now.year,
          );
          final categories = analytics.spendingByCategory;
          final total = analytics.totalExpenses;
          final pct = analytics.percentVsPreviousPeriod;
          final isDown = pct <= 0;
          final buckets = analytics.overviewBuckets;
          final chartMax = buckets.isEmpty
              ? 1.0
              : buckets.map((b) => b.amount).reduce((a, b) => a > b ? a : b);

          int? selectedKey;
          switch (_period) {
            case ExpensePeriod.week:
              selectedKey = _highlightedChartKey ?? now.day;
            case ExpensePeriod.month:
              selectedKey = _selectedMonth;
            case ExpensePeriod.year:
              selectedKey = _highlightedChartKey ?? now.month;
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            children: [
              const Text(
                'Expense Tracking',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Monitor your spending habits and patterns',
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 20),
              _PeriodToggle(
                period: _period,
                onChanged: _onPeriodChanged,
              ),
              const SizedBox(height: 20),
              _TotalExpensesCard(
                total: total,
                percentChange: pct,
                isDown: isDown,
                comparisonLabel: analytics.comparisonLabel,
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _MiniStatCard(
                      label: _period == ExpensePeriod.week
                          ? 'Lowest (day)'
                          : 'Lowest Day',
                      value: analytics.lowestDay,
                      icon: Icons.south_east,
                      iconColor: const Color(0xFF2E7D32),
                      iconBg: const Color(0xFFE8F5E9),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _MiniStatCard(
                      label: _period == ExpensePeriod.week
                          ? 'Highest (day)'
                          : 'Highest Day',
                      value: analytics.highestDay,
                      icon: Icons.north_east,
                      iconColor: const Color(0xFFC62828),
                      iconBg: const Color(0xFFFFEBEE),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _OverviewChartCard(
                title: analytics.overviewTitle,
                buckets: buckets,
                chartMax: chartMax,
                selectedKey: selectedKey,
                onBucketTap: _onChartBucketTap,
              ),
              const SizedBox(height: 20),
              const Text(
                'Spending by Category',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              if (categories.isEmpty)
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE0E8E2)),
                  ),
                  child: Text(
                    analytics.emptyDataMessage,
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE0E8E2)),
                  ),
                  child: Column(
                    children: categories.map((cat) {
                      final pctShare =
                          total > 0 ? (cat.amount / total * 100).round() : 0;
                      return _CategoryRow(
                        category: cat.category,
                        amount: cat.amount,
                        percent: pctShare,
                        color: Color(cat.color),
                      );
                    }).toList(),
                  ),
                ),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE0E8E2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Spending Insights',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...analytics.insights.map(
                      (line) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '• ',
                              style: TextStyle(color: Colors.grey.shade700),
                            ),
                            Expanded(
                              child: Text(
                                line,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade700,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PeriodToggle extends StatelessWidget {
  const _PeriodToggle({
    required this.period,
    required this.onChanged,
  });

  final ExpensePeriod period;
  final ValueChanged<ExpensePeriod> onChanged;

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
          _chip('Week', ExpensePeriod.week),
          _chip('Month', ExpensePeriod.month),
          _chip('Year', ExpensePeriod.year),
        ],
      ),
    );
  }

  Widget _chip(String label, ExpensePeriod value) {
    final selected = period == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => onChanged(value),
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
              fontSize: 13,
              color: selected ? Colors.white : Colors.grey.shade700,
            ),
          ),
        ),
      ),
    );
  }
}

class _TotalExpensesCard extends StatelessWidget {
  const _TotalExpensesCard({
    required this.total,
    required this.percentChange,
    required this.isDown,
    required this.comparisonLabel,
  });

  final double total;
  final double percentChange;
  final bool isDown;
  final String comparisonLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total Expenses',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 14,
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
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      isDown ? Icons.trending_down : Icons.trending_up,
                      color: Colors.white.withValues(alpha: 0.85),
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${percentChange.abs().toStringAsFixed(0)}% $comparisonLabel',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.show_chart,
              color: Colors.white,
              size: 28,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStatCard extends StatelessWidget {
  const _MiniStatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
    required this.iconBg,
  });

  final String label;
  final double value;
  final IconData icon;
  final Color iconColor;
  final Color iconBg;

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
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
            child: Icon(icon, size: 16, color: iconColor),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 4),
          Text(
            'RM ${value.toStringAsFixed(2)}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ],
      ),
    );
  }
}

class _OverviewChartCard extends StatelessWidget {
  const _OverviewChartCard({
    required this.title,
    required this.buckets,
    required this.chartMax,
    required this.selectedKey,
    required this.onBucketTap,
  });

  final String title;
  final List<PeriodBucket> buckets;
  final double chartMax;
  final int? selectedKey;
  final ValueChanged<PeriodBucket> onBucketTap;

  @override
  Widget build(BuildContext context) {
    final maxAmount = chartMax > 0 ? chartMax : 1.0;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE0E8E2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 100,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: buckets.map((bucket) {
                final heightFactor =
                    bucket.amount > 0 ? (bucket.amount / maxAmount).clamp(0.08, 1.0) : 0.05;
                final isSelected = bucket.key == selectedKey;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => onBucketTap(bucket),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Container(
                          width: buckets.length > 7 ? 14 : 28,
                          height: 80 * heightFactor,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.primary.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: buckets.map((bucket) {
              final isSelected = bucket.key == selectedKey;
              return Expanded(
                child: GestureDetector(
                  onTap: () => onBucketTap(bucket),
                  child: Text(
                    bucket.label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: buckets.length > 7 ? 9 : 12,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected
                          ? AppColors.primary
                          : Colors.grey.shade600,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.category,
    required this.amount,
    required this.percent,
    required this.color,
  });

  final String category;
  final double amount;
  final int percent;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  category,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
              Text(
                'RM ${amount.toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 12),
              Text(
                '$percent%',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percent / 100,
              minHeight: 6,
              backgroundColor: Colors.grey.shade200,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
