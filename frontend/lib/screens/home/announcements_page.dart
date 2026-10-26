import 'package:flutter/material.dart';

import '../../app_services.dart';
import '../../models/models.dart';
import '../../utils/format.dart';
import '../../widgets/common.dart';

/// Dormitory announcements and house rules, newest first (pinned on top).
class AnnouncementsPage extends StatelessWidget {
  const AnnouncementsPage({super.key, required this.user});

  final AppUser user;

  Future<List<Announcement>> _load() async {
    final data = await AppServices.api.get('/api/announcements');
    return asList(data).map((e) => Announcement.fromJson(asMap(e))).toList();
  }

  @override
  Widget build(BuildContext context) {
    return AsyncView<List<Announcement>>(
      load: _load,
      builder: (context, items, refresh) {
        return PageList(
          title: 'Announcements',
          onRefresh: refresh,
          children: [
            if (items.isEmpty)
              const EmptyState(
                icon: Icons.campaign_outlined,
                message: 'No announcements yet.',
              )
            else
              for (final item in items) _AnnouncementCard(item),
          ],
        );
      },
    );
  }
}

class _AnnouncementCard extends StatelessWidget {
  const _AnnouncementCard(this.item);

  final Announcement item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final byline = item.authorName.isEmpty
        ? 'Posted ${formatDate(item.createdAt)}'
        : 'Posted ${formatDate(item.createdAt)} by ${item.authorName}';
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (item.pinned) ...[
                Icon(Icons.push_pin, size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: 6),
              ],
              Expanded(child: Text(item.title, style: theme.textTheme.titleMedium)),
            ],
          ),
          const SizedBox(height: 8),
          Text(item.body),
          const SizedBox(height: 8),
          Text(byline, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}
