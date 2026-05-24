import '../models/bill.dart';
import '../models/expense_group.dart';
import 'settlement_calculator.dart';

enum GroupStatus {
  /// Outstanding — bill belum fully assigned (red).
  owe,
  /// Friends owe you back (green +RM).
  owed,
  /// All bills in group settled.
  settled,
  /// No bills in group yet.
  empty,
}

class GroupSummary {
  const GroupSummary({
    required this.id,
    required this.name,
    required this.memberCount,
    required this.amount,
    required this.status,
  });

  final String id;
  final String name;
  final int memberCount;
  final double amount;
  final GroupStatus status;
}

class ActivityItem {
  const ActivityItem({
    required this.initial,
    required this.title,
    required this.timeLabel,
    required this.amount,
    required this.isPositive,
  });

  final String initial;
  final String title;
  final String timeLabel;
  final double amount;
  final bool isPositive;
}

class HomeSummary {
  const HomeSummary({
    required this.totalBalance,
    required this.youOwe,
    required this.owedToYou,
    required this.groups,
    required this.activities,
  });

  final double totalBalance;
  final double youOwe;
  final double owedToYou;
  final List<GroupSummary> groups;
  final List<ActivityItem> activities;
}

class HomeDataMapper {
  static HomeSummary fromGroupsAndBills({
    required List<ExpenseGroup> groups,
    required List<Bill> bills,
    String? selfName,
  }) {
    if (groups.isEmpty && bills.isEmpty) {
      return const HomeSummary(
        totalBalance: 0,
        youOwe: 0,
        owedToYou: 0,
        groups: [],
        activities: [],
      );
    }

    final settlement = SettlementCalculator.fromBills(bills, selfName: selfName);
    final youOwe = settlement.youOwe;
    final owedToYou = settlement.owedToYou;
    final balance = settlement.netBalance;

    final groupSummaries = groups.take(5).map((group) {
      final groupBills = bills.where((b) => b.groupId == group.id).toList();
      final gb = SettlementCalculator.groupBalance(
        groupBills,
        selfName: selfName,
      );

      GroupStatus status;
      double displayAmount;

      if (gb.isEmpty) {
        status = GroupStatus.empty;
        displayAmount = 0;
      } else if (gb.isFullySettled) {
        status = GroupStatus.settled;
        displayAmount = 0;
      } else if (gb.othersOweYou > 0.01) {
        status = GroupStatus.owed;
        displayAmount = gb.othersOweYou;
      } else if (gb.pendingUncollected > 0.01) {
        status = GroupStatus.owe;
        displayAmount = gb.pendingUncollected;
      } else {
        status = GroupStatus.settled;
        displayAmount = 0;
      }

      return GroupSummary(
        id: group.id,
        name: group.name,
        memberCount: group.memberCount,
        amount: displayAmount,
        status: status,
      );
    }).toList();

    final activities = bills.take(4).map((bill) {
      final othersOwe =
          SettlementCalculator.othersOweOnBill(bill, selfName: selfName);
      final isPositive = bill.status == 'settled' || othersOwe > 0;

      String title;
      if (bill.status == 'settled') {
        title = 'Settled — ${bill.title}';
      } else if (othersOwe > 0) {
        title = 'Collect RM ${othersOwe.toStringAsFixed(2)} — ${bill.title}';
      } else if (bill.status == 'pending') {
        title = 'Pending split — ${bill.title}';
      } else if (bill.groupId != null) {
        title = 'Group expense — ${bill.title}';
      } else {
        title = bill.title;
      }

      return ActivityItem(
        initial: title.isNotEmpty ? title[0].toUpperCase() : '?',
        title: title,
        timeLabel: _formatTimeAgo(bill.createdAt),
        amount: bill.total,
        isPositive: isPositive,
      );
    }).toList();

    return HomeSummary(
      totalBalance: balance,
      youOwe: youOwe,
      owedToYou: owedToYou,
      groups: groupSummaries,
      activities: activities,
    );
  }

  static String _formatTimeAgo(DateTime? date) {
    if (date == null) return 'Just now';

    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 60) {
      final m = diff.inMinutes;
      if (m < 1) return 'Just now';
      return '$m ${m == 1 ? 'minute' : 'minutes'} ago';
    }
    if (diff.inHours < 24) {
      final h = diff.inHours;
      return '$h ${h == 1 ? 'hour' : 'hours'} ago';
    }
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return '${date.day}/${date.month}/${date.year}';
  }
}
