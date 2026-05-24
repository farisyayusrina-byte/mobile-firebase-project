import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/expense_group.dart';
import '../services/group_service.dart';
import '../theme/app_theme.dart';

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key, required this.user});

  final User user;

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final _groupService = GroupService();
  final _nameController = TextEditingController();
  final List<GroupMember> _members = [];
  bool _saving = false;

  Future<void> _addMember() async {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final result = await showDialog<GroupMember>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add member'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email (optional)',
                helperText: 'If they use Split with this email, they join the group',
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
                GroupMember(
                  name: name,
                  email: emailController.text.trim().isEmpty
                      ? null
                      : emailController.text.trim(),
                ),
              );
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (result != null) {
      setState(() => _members.add(result));
    }
  }

  Future<void> _create() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Group name is required')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final creatorName =
          widget.user.displayName ?? widget.user.email?.split('@').first ?? 'You';
      final id = await _groupService.createGroup(
        userId: widget.user.uid,
        creatorName: creatorName,
        creatorEmail: widget.user.email ?? '',
        name: name,
        extraMembers: _members,
      );
      if (!mounted) return;
      Navigator.pop(context, id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: const Text('New Group')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Group name',
              hintText: 'e.g. Roommates, Office lunch',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              const Text(
                'Members',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: _addMember,
                icon: const Icon(Icons.person_add_outlined),
                label: const Text('Add'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE0E8E2)),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                    child: const Icon(Icons.person, color: AppColors.primary),
                  ),
                  title: Text(
                    widget.user.displayName ?? 'You',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(widget.user.email ?? ''),
                  trailing: const Chip(label: Text('You')),
                ),
                ..._members.map(
                  (m) => ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.grey.shade200,
                      child: Text(
                        m.name.isNotEmpty ? m.name[0].toUpperCase() : '?',
                      ),
                    ),
                    title: Text(m.name),
                    subtitle: m.email != null ? Text(m.email!) : null,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          FilledButton(
            onPressed: _saving ? null : _create,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
            child: _saving
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Create group'),
          ),
        ],
      ),
    );
  }
}
