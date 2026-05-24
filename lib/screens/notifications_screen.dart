import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/app_notification.dart';
import '../services/messaging_service.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import '../widgets/split_widgets.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key, required this.user});

  final User user;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _notifications = NotificationService();
  final _messaging = MessagingService();
  bool _sendingTest = false;

  Future<void> _sendTest() async {
    setState(() => _sendingTest = true);
    try {
      await _notifications.sendTestNotification(widget.user.uid);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Test notification sent')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sendingTest = false);
    }
  }

  Future<void> _copyFcmToken() async {
    final token = await _messaging.getToken();
    if (token == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('FCM token not available on this device')),
      );
      return;
    }
    await Clipboard.setData(ClipboardData(text: token));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('FCM token copied (for Firebase Console tests)')),
    );
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'bill_saved':
        return Icons.receipt_long_outlined;
      case 'split_request':
        return Icons.people_outline;
      case 'reminder':
        return Icons.schedule;
      default:
        return Icons.notifications_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          StreamBuilder<List<AppNotification>>(
            stream: _notifications.watchNotifications(widget.user.uid),
            builder: (context, snapshot) {
              final unread =
                  (snapshot.data ?? []).where((n) => !n.read).length;
              if (unread == 0) return const SizedBox.shrink();
              return TextButton(
                onPressed: () =>
                    _notifications.markAllAsRead(widget.user.uid),
                child: const Text('Mark all read'),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<List<AppNotification>>(
        stream: _notifications.watchNotifications(widget.user.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }
          if (snapshot.hasError) {
            return SplitErrorState(message: snapshot.error.toString());
          }

          final items = snapshot.data ?? [];

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE0E8E2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Notification settings',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Alerts appear on your device and are saved here. '
                      'Allow notifications when prompted on first login.',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _sendingTest ? null : _sendTest,
                            child: _sendingTest
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('Send test'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _copyFcmToken,
                            child: const Text('Copy FCM token'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (items.isEmpty)
                Container(
                  padding: const EdgeInsets.all(32),
                  alignment: Alignment.center,
                  child: Column(
                    children: [
                      Icon(
                        Icons.notifications_none,
                        size: 48,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No notifications yet',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Save a bill or tap Send test above.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                )
              else
                ...items.map(
                  (n) => _NotificationTile(
                    notification: n,
                    icon: _iconForType(n.type),
                    onTap: () {
                      if (!n.read) {
                        _notifications.markAsRead(widget.user.uid, n.id);
                      }
                    },
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.notification,
    required this.icon,
    required this.onTap,
  });

  final AppNotification notification;
  final IconData icon;
  final VoidCallback onTap;

  String _timeAgo(DateTime? date) {
    if (date == null) return '';
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final n = notification;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: n.read ? Colors.white : AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE0E8E2)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: AppColors.primary, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              n.title,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: n.read
                                    ? AppColors.textPrimary
                                    : AppColors.primary,
                              ),
                            ),
                          ),
                          if (!n.read)
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        n.body,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          height: 1.35,
                        ),
                      ),
                      if (n.createdAt != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          _timeAgo(n.createdAt),
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
