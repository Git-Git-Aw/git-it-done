import 'package:flutter/material.dart';

import '../../app_services.dart';
import '../../models/models.dart';
import '../../utils/format.dart';
import '../../widgets/common.dart';

/// What a tenant sees first: balance, next due date, room, and news.
class TenantDashboardPage extends StatelessWidget {
  const TenantDashboardPage({super.key, required this.user});

  final AppUser user;

  Future<TenantDashboard> _load() async {
    final data = await AppServices.api.get('/api/dashboard/tenant');
    return TenantDashboard.fromJson(asMap(data));
  }

  @override
  Widget build(BuildContext context) {
    return AsyncView<TenantDashboard>(
      load: _load,
      builder: (context, dash, refresh) {
        final due = dash.nextDue;
        final lease = dash.lease;
        final room = dash.room;
        return PageList(
          title: 'Hi, ${firstName(user.fullName)}',
          onRefresh: refresh,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                MetricCard(
                  label: 'Current balance',
                  value: peso(dash.balance),
                  color: dash.balance > 0 ? Colors.red.shade700 : Colors.green.shade700,
                  footnote: dash.balance > 0
                      ? 'Total of your unpaid bills'
                      : 'You are all paid up',
                ),
                MetricCard(
                  label: 'Next due date',
                  value: due == null ? 'None' : formatDate(due.dueDate),
                  footnote: due == null
                      ? 'No bills waiting'
                      : '${monthLabel(due.period)} bill: ${peso(due.balance)}',
                ),
              ],
            ),
            const SizedBox(height: 12),
            SectionCard(
              title: 'Next payment',
              child: due == null
                  ? const Text('You have no bills waiting. New bills appear here each month.')
                  : Column(
                      children: [
                        InfoRow('Bill for', monthLabel(due.period)),
                        InfoRow('Due date', formatDate(due.dueDate)),
                        InfoRow('Amount due', peso(due.amountDue)),
                        InfoRow('Paid so far', peso(due.amountPaid)),
                        InfoRow('Balance', peso(due.balance)),
                        InfoRow('Status', '', child: StatusChip(due.displayStatus)),
                      ],
                    ),
            ),
            SectionCard(
              title: 'My room and lease',
              child: lease == null || room == null
                  ? const Text('You have no active lease yet. The landlord will assign your room.')
                  : Column(
                      children: [
                        InfoRow('Room', room.roomNumber),
                        if (room.description.isNotEmpty) InfoRow('About the room', room.description),
                        InfoRow('Monthly rent', peso(lease.monthlyRent)),
                        InfoRow('Due day', 'Day ${lease.dueDay} of each month'),
                        InfoRow('Lease starts', formatDate(lease.startDate)),
                        InfoRow(
                          'Lease ends',
                          lease.endDate == null ? 'No end date' : formatDate(lease.endDate),
                        ),
                      ],
                    ),
            ),
            if (dash.unreadNotifications > 0)
              SectionCard(
                child: Row(
                  children: [
                    const Icon(Icons.notifications_active_outlined),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        dash.unreadNotifications == 1
                            ? 'You have 1 unread notification. Open the Notifications tab.'
                            : 'You have ${dash.unreadNotifications} unread notifications. Open the Notifications tab.',
                      ),
                    ),
                  ],
                ),
              ),
            SectionCard(
              title: 'Latest announcements',
              child: dash.announcements.isEmpty
                  ? const Text('No announcements yet.')
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (var i = 0; i < dash.announcements.length; i++) ...[
                          if (i > 0) const Divider(height: 24),
                          _AnnouncementSummary(dash.announcements[i]),
                        ],
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _AnnouncementSummary extends StatelessWidget {
  const _AnnouncementSummary(this.item);

  final Announcement item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (item.pinned) ...[
              const Icon(Icons.push_pin, size: 16),
              const SizedBox(width: 4),
            ],
            Expanded(
              child: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(item.body, maxLines: 3, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 4),
        Text(formatDate(item.createdAt), style: theme.textTheme.bodySmall),
      ],
    );
  }
}
