import 'package:flutter/material.dart';

import '../../app_services.dart';
import '../../models/models.dart';
import '../../theme.dart';
import '../../utils/format.dart';
import '../../widgets/common.dart';

/// In-app reminders and status updates (no SMS or email in this project).
class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  IconData _iconFor(String type) {
    switch (type) {
      case 'due_reminder':
        return Icons.schedule;
      case 'overdue_reminder':
        return Icons.warning_amber_outlined;
      case 'announcement':
        return Icons.campaign_outlined;
      case 'billing':
      case 'payment':
      case 'payment_proof':
        return Icons.payments_outlined;
      case 'maintenance':
        return Icons.build_outlined;
      case 'registration':
      case 'account':
        return Icons.person_add_alt_outlined;
      case 'lease':
        return Icons.meeting_room_outlined;
      case 'inquiry':
        return Icons.question_answer_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  Future<void> _markRead(
    BuildContext context,
    AppNotification item,
    Future<void> Function() refresh,
  ) async {
    try {
      await AppServices.api.patch('/api/notifications/${item.id}/read');
      await refresh();
    } catch (e) {
      if (context.mounted) showSnack(context, errorText(e));
    }
  }

  Future<void> _markAllRead(
    BuildContext context,
    Future<void> Function() refresh,
  ) async {
    try {
      await AppServices.api.patch('/api/notifications/read-all');
      await refresh();
    } catch (e) {
      if (context.mounted) showSnack(context, errorText(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AsyncView<NotificationsResult>(
      load: AppServices.loadNotifications,
      builder: (context, result, refresh) {
        return PageList(
          title: 'Notifications',
          onRefresh: refresh,
          actions: [
            if (result.unread > 0)
              TextButton(
                onPressed: () => _markAllRead(context, refresh),
                child: const Text('Mark all read'),
              ),
          ],
          children: [
            if (result.items.isEmpty)
              const EmptyState(
                icon: Icons.notifications_none,
                message: 'No notifications yet.',
              )
            else
              for (final item in result.items)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: cardDecoration(
                    color: item.isRead ? Colors.white : const Color(0xFFFBF7FF),
                  ),
                  child: Material(
                    type: MaterialType.transparency,
                    child: ListTile(
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.all(Radius.circular(radiusL)),
                      ),
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: (item.isRead ? inkSoft : brandDeep)
                              .withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          _iconFor(item.type),
                          size: 22,
                          color: item.isRead ? inkSoft : brandDeep,
                        ),
                      ),
                      title: Text(
                        item.message,
                        style: TextStyle(
                          fontWeight:
                              item.isRead ? FontWeight.w400 : FontWeight.w700,
                          color: inkDark,
                        ),
                      ),
                      subtitle: Text(
                        formatDateTime(item.createdAt),
                        style: const TextStyle(color: inkSoft),
                      ),
                      trailing: item.isRead
                          ? null
                          : const Icon(Icons.circle, size: 10, color: brandPink),
                      onTap: item.isRead ? null : () => _markRead(context, item, refresh),
                    ),
                  ),
                ),
          ],
        );
      },
    );
  }
}
