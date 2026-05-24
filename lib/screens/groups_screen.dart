import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/expense_group.dart';
import '../services/group_service.dart';
import '../theme/app_theme.dart';
import '../utils/home_data_mapper.dart';
import '../widgets/home_dashboard_widgets.dart';
import '../widgets/split_widgets.dart';
import 'create_group_screen.dart';
import 'group_detail_screen.dart';

class GroupsScreen extends StatelessWidget {
  const GroupsScreen({super.key, required this.user});

  final User user;

  @override
  Widget build(BuildContext context) {
    final groupService = GroupService();

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Your Groups'),
        actions: [
          IconButton(
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => CreateGroupScreen(user: user),
                ),
              );
            },
            icon: const Icon(Icons.add),
            tooltip: 'New group',
          ),
        ],
      ),
      body: StreamBuilder<List<ExpenseGroup>>(
        stream: groupService.watchMyGroups(user.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }
          if (snapshot.hasError) {
            return SplitErrorState(message: snapshot.error.toString());
          }

          final groups = snapshot.data ?? [];
          if (groups.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.groups_outlined, size: 56, color: Colors.grey.shade400),
                    const SizedBox(height: 16),
                    const Text(
                      'No groups yet',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Create a group to split bills with friends.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => CreateGroupScreen(user: user),
                          ),
                        );
                      },
                      child: const Text('Create group'),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(20),
            children: groups.map((g) {
              final summary = GroupSummary(
                id: g.id,
                name: g.name,
                memberCount: g.memberCount,
                amount: 0,
                status: GroupStatus.empty,
              );
              return GestureDetector(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => GroupDetailScreen(
                        user: user,
                        group: g,
                      ),
                    ),
                  );
                },
                child: GroupCard(group: summary),
              );
            }).toList(),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => CreateGroupScreen(user: user),
            ),
          );
        },
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
