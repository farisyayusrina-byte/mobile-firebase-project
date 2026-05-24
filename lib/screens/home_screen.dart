import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/bill.dart';
import '../models/expense_group.dart';
import '../services/auth_service.dart';
import '../services/demo_data_service.dart';
import '../services/firestore_service.dart';
import '../services/group_service.dart';
import '../services/notification_service.dart';
import 'notifications_screen.dart';
import '../theme/app_theme.dart';
import '../utils/home_data_mapper.dart';
import '../widgets/home_dashboard_widgets.dart';
import '../widgets/split_widgets.dart';
import 'add_bill_screen.dart';
import 'create_group_screen.dart';
import 'group_detail_screen.dart';
import 'groups_screen.dart';
import 'settle_up_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.user});

  final User user;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _demoData = DemoDataService();
  final _notifications = NotificationService();
  bool _seedingDemo = false;

  Future<void> _loadDemoData(BuildContext context) async {
    setState(() => _seedingDemo = true);
    try {
      final count = await _demoData.seedDemoBills(
        widget.user.uid,
        creatorEmail: widget.user.email,
        creatorName: widget.user.displayName,
      );
      if (!context.mounted) return;
      if (count == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Demo data already loaded. Use reseed from menu.'),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added demo groups & $count bills'),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _seedingDemo = false);
    }
  }

  Future<void> _reseedDemoData(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reload demo data?'),
        content: const Text(
          'This deletes your existing bills and adds fresh sample data.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reload'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _seedingDemo = true);
    try {
      final count = await _demoData.reseedDemoBills(widget.user.uid);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Reloaded $count demo bills')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _seedingDemo = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final firestore = FirestoreService();
    final groupService = GroupService();
    final auth = AuthService();
    final name =
        widget.user.displayName ?? widget.user.email?.split('@').first ?? 'User';

    return SafeArea(
      child: StreamBuilder<List<ExpenseGroup>>(
        stream: groupService.watchMyGroups(widget.user.uid),
        builder: (context, groupSnapshot) {
          final groups = groupSnapshot.data ?? [];

          return StreamBuilder<List<Bill>>(
        stream: firestore.watchBills(widget.user.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              groupSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          if (snapshot.hasError) {
            final err = snapshot.error.toString();
            final isPermission = err.contains('permission-denied');
            return SplitErrorState(
              message: isPermission
                  ? 'Firestore rules are blocking access.\n'
                      'Console → Firestore → Rules → Publish.'
                  : err,
            );
          }

          final bills = snapshot.data ?? [];
          final selfName =
              widget.user.displayName ?? widget.user.email?.split('@').first;
          final summary = HomeDataMapper.fromGroupsAndBills(
            groups: groups,
            bills: bills,
            selfName: selfName,
          );

          return StreamBuilder<int>(
            stream: _notifications.watchUnreadCount(widget.user.uid),
            builder: (context, unreadSnap) {
              final unread = unreadSnap.data ?? 0;

              return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async {},
            child: ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                HomeWelcomeHeader(
                  name: name,
                  unreadCount: unread,
                  onNotifications: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            NotificationsScreen(user: widget.user),
                      ),
                    );
                  },
                  onLogout: () => auth.signOut(),
                ),
                if (bills.isEmpty || _seedingDemo) ...[
                  const SizedBox(height: 12),
                  _DemoDataBanner(
                    loading: _seedingDemo,
                    isEmpty: bills.isEmpty,
                    onLoadDemo: () => _loadDemoData(context),
                    onReseed: () => _reseedDemoData(context),
                  ),
                ],
                const SizedBox(height: 16),
                BalanceCard(
                  totalBalance: summary.totalBalance,
                  youOwe: summary.youOwe,
                  owedToYou: summary.owedToYou,
                ),
                const SizedBox(height: 20),
                QuickActionsRow(
                  onAddExpense: () => _openAddBill(context),
                  onNewGroup: () => _openCreateGroup(context),
                  onSettleUp: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => SettleUpScreen(user: widget.user),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),
                SectionHeaderRow(
                  title: 'Your Groups',
                  onViewAll: groups.isEmpty
                      ? null
                      : () => _openAllGroups(context),
                ),
                if (summary.groups.isEmpty)
                  _EmptySection(
                    message: 'No groups yet. Create one to split with friends.',
                    actionLabel: 'New Group',
                    onAction: () => _openCreateGroup(context),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: summary.groups
                          .map(
                            (g) => GestureDetector(
                              onTap: () {
                                final group = groups.firstWhere(
                                  (eg) => eg.id == g.id,
                                  orElse: () => groups.first,
                                );
                                Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => GroupDetailScreen(
                                      user: widget.user,
                                      group: group,
                                    ),
                                  ),
                                );
                              },
                              child: GroupCard(group: g),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                const SizedBox(height: 16),
                const SectionHeaderRow(title: 'Recent Activity'),
                ActivityCard(items: summary.activities),
              ],
            ),
          );
            },
          );
        },
      );
        },
      ),
    );
  }

  void _openCreateGroup(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CreateGroupScreen(user: widget.user),
      ),
    );
  }

  void _openAllGroups(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => GroupsScreen(user: widget.user),
      ),
    );
  }

  void _openAddBill(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AddBillScreen(userId: widget.user.uid),
      ),
    );
  }

}

class _DemoDataBanner extends StatelessWidget {
  const _DemoDataBanner({
    required this.loading,
    required this.isEmpty,
    required this.onLoadDemo,
    required this.onReseed,
  });

  final bool loading;
  final bool isEmpty;
  final VoidCallback onLoadDemo;
  final VoidCallback onReseed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Empty? Load sample data',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isEmpty
                  ? 'Adds demo bills to Firestore so Home, History & Expenses look filled.'
                  : 'Reload demo bills (replaces your current bills).',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: loading ? null : onLoadDemo,
                    child: loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Load demo data'),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: loading ? null : onReseed,
                  child: const Text('Reseed'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptySection extends StatelessWidget {
  const _EmptySection({
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: onAction,
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}
