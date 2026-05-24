import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/home_data_mapper.dart';

class HomeWelcomeHeader extends StatelessWidget {
  const HomeWelcomeHeader({
    super.key,
    required this.name,
    required this.onLogout,
    this.onNotifications,
    this.unreadCount = 0,
  });

  final String name;
  final VoidCallback onLogout;
  final VoidCallback? onNotifications;
  final int unreadCount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 12, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome back,',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A2B4A),
                  ),
                ),
              ],
            ),
          ),
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                onPressed: onNotifications,
                icon: const Icon(Icons.notifications_none),
                color: const Color(0xFF1A2B4A),
                tooltip: 'Notifications',
              ),
              if (unreadCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 2,
                    ),
                    constraints: const BoxConstraints(minWidth: 16),
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.all(Radius.circular(10)),
                    ),
                    child: Text(
                      unreadCount > 9 ? '9+' : '$unreadCount',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            onPressed: onLogout,
            icon: const Icon(Icons.logout),
            color: const Color(0xFF1A2B4A),
            tooltip: 'Sign out',
          ),
        ],
      ),
    );
  }
}

class BalanceCard extends StatelessWidget {
  const BalanceCard({
    super.key,
    required this.totalBalance,
    required this.youOwe,
    required this.owedToYou,
  });

  final double totalBalance;
  final double youOwe;
  final double owedToYou;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.primaryDark],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Total Balance',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'RM ${totalBalance.toStringAsFixed(2)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _BalanceMini(
                  icon: Icons.south_east,
                  label: 'You owe',
                  value: youOwe,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _BalanceMini(
                  icon: Icons.north_east,
                  label: 'Owed to you',
                  value: owedToYou,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BalanceMini extends StatelessWidget {
  const _BalanceMini({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 11,
                  ),
                ),
                Text(
                  'RM ${value.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class QuickActionsRow extends StatelessWidget {
  const QuickActionsRow({
    super.key,
    required this.onAddExpense,
    required this.onNewGroup,
    required this.onSettleUp,
  });

  final VoidCallback onAddExpense;
  final VoidCallback onNewGroup;
  final VoidCallback onSettleUp;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: _QuickAction(
              icon: Icons.add,
              label: 'Add Expense',
              onTap: onAddExpense,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _QuickAction(
              icon: Icons.groups_outlined,
              label: 'New Group',
              onTap: onNewGroup,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _QuickAction(
              icon: Icons.trending_up,
              label: 'Settle Up',
              onTap: onSettleUp,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: AppColors.primary, size: 22),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A2B4A),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SectionHeaderRow extends StatelessWidget {
  const SectionHeaderRow({
    super.key,
    required this.title,
    this.onViewAll,
  });

  final String title;
  final VoidCallback? onViewAll;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A2B4A),
            ),
          ),
          const Spacer(),
          if (onViewAll != null)
            GestureDetector(
              onTap: onViewAll,
              child: const Text(
                'View All',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class GroupCard extends StatelessWidget {
  const GroupCard({super.key, required this.group});

  final GroupSummary group;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.groups,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  group.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: Color(0xFF1A2B4A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${group.memberCount} members',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          _GroupAmount(status: group.status, amount: group.amount),
        ],
      ),
    );
  }
}

class _GroupAmount extends StatelessWidget {
  const _GroupAmount({required this.status, required this.amount});

  final GroupStatus status;
  final double amount;

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case GroupStatus.empty:
        return Text(
          'No expenses',
          style: TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 13,
            color: Colors.grey.shade500,
          ),
        );
      case GroupStatus.settled:
        return Text(
          'Settled',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade600,
          ),
        );
      case GroupStatus.owed:
        return Text(
          '+RM ${amount.toStringAsFixed(2)}',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF2E7D32),
          ),
        );
      case GroupStatus.owe:
        return Text(
          'RM ${amount.toStringAsFixed(2)}',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFFC62828),
          ),
        );
    }
  }
}

String _formatAmount(ActivityItem item) {
  final value = 'RM ${item.amount.toStringAsFixed(2)}';
  if (item.isPositive) return '+$value';
  if (item.title.toLowerCase().contains('you paid')) return '-$value';
  return value;
}

Color _amountColor(ActivityItem item) {
  if (item.isPositive) return const Color(0xFF2E7D32);
  if (item.title.toLowerCase().contains('you paid')) {
    return const Color(0xFFC62828);
  }
  return const Color(0xFF1A2B4A);
}

class ActivityCard extends StatelessWidget {
  const ActivityCard({super.key, required this.items});

  final List<ActivityItem> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Text(
          'No recent activity yet',
          style: TextStyle(color: Colors.grey.shade600),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: List.generate(items.length, (index) {
          final item = items[index];
          return Column(
            children: [
              if (index > 0) Divider(height: 1, color: Colors.grey.shade200),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: Colors.grey.shade200,
                      child: Text(
                        item.initial,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A2B4A),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1A2B4A),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item.timeLabel,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      _formatAmount(item),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _amountColor(item),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}
