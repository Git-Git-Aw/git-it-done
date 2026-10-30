import 'package:flutter/material.dart';

import '../../app_services.dart';
import '../../models/models.dart';
import '../../utils/format.dart';
import '../../widgets/common.dart';
import '../../widgets/form_dialog.dart';

/// Dormitory announcements and house rules, newest first (pinned on top).
/// Tenants only read them. The landlord can also post, edit, pin, archive
/// and restore them (nothing is ever deleted).
class AnnouncementsPage extends StatefulWidget {
  const AnnouncementsPage({super.key, required this.user});

  final AppUser user;

  @override
  State<AnnouncementsPage> createState() => _AnnouncementsPageState();
}

class _AnnouncementsPageState extends State<AnnouncementsPage> {
  bool _showArchived = false;

  Future<List<Announcement>> _load() async {
    final landlordWantsArchived = widget.user.isLandlord && _showArchived;
    final data = await AppServices.api.get(
      '/api/announcements',
      query: landlordWantsArchived ? {'archived': 'true'} : null,
    );
    return asList(data).map((e) => Announcement.fromJson(asMap(e))).toList();
  }

  List<FieldSpec> _fields(Announcement? item) {
    return [
      FieldSpec('title', 'Title', required: true, initial: item?.title ?? '', maxLength: 120),
      FieldSpec('body', 'Message', kind: FieldKind.multiline, required: true, initial: item?.body ?? ''),
      FieldSpec('pinned', 'Pin to the top', kind: FieldKind.toggle, initial: (item?.pinned ?? false) ? 'true' : 'false'),
    ];
  }

  Map<String, dynamic> _body(Map<String, String> v) {
    return {
      'title': v['title'],
      'body': v['body'],
      'pinned': v['pinned'] == 'true',
    };
  }

  Future<void> _add(BuildContext context, Future<void> Function() refresh) {
    return afterDialog(
      context,
      showFormDialog(
        context,
        title: 'New announcement',
        fields: _fields(null),
        submitLabel: 'Post',
        onSubmit: (v) async {
          await AppServices.api.post('/api/announcements', body: _body(v));
          return 'Announcement posted.';
        },
      ),
      refresh,
    );
  }

  Future<void> _edit(BuildContext context, Announcement item, Future<void> Function() refresh) {
    return afterDialog(
      context,
      showFormDialog(
        context,
        title: 'Edit announcement',
        fields: _fields(item),
        onSubmit: (v) async {
          await AppServices.api.put('/api/announcements/${item.id}', body: _body(v));
          return 'Announcement updated.';
        },
      ),
      refresh,
    );
  }

  Future<void> _archive(BuildContext context, Announcement item, Future<void> Function() refresh) async {
    final ok = await confirmDialog(
      context,
      title: 'Archive this announcement?',
      message: 'Tenants will no longer see it, but it is kept and you can restore it later.',
      confirmLabel: 'Archive',
    );
    if (!ok || !context.mounted) return;
    await runAction(context, () async {
      await AppServices.api.patch('/api/announcements/${item.id}/archive');
      return 'Announcement archived.';
    }, refresh);
  }

  Future<void> _restore(BuildContext context, Announcement item, Future<void> Function() refresh) {
    return runAction(context, () async {
      await AppServices.api.patch('/api/announcements/${item.id}/restore');
      return 'Announcement restored.';
    }, refresh);
  }

  @override
  Widget build(BuildContext context) {
    final isLandlord = widget.user.isLandlord;
    return AsyncView<List<Announcement>>(
      key: ValueKey<bool>(_showArchived),
      load: _load,
      builder: (context, items, refresh) {
        return PageList(
          title: 'Announcements',
          onRefresh: refresh,
          actions: [
            if (isLandlord)
              FilledButton.icon(
                onPressed: () => _add(context, refresh),
                icon: const Icon(Icons.add),
                label: const Text('New announcement'),
              ),
          ],
          children: [
            if (isLandlord)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Show archived'),
                value: _showArchived,
                onChanged: (value) => setState(() => _showArchived = value),
              ),
            if (items.isEmpty)
              const EmptyState(
                icon: Icons.campaign_outlined,
                message: 'No announcements yet.',
              )
            else
              for (final item in items)
                _AnnouncementCard(
                  item,
                  isLandlord: isLandlord,
                  onEdit: () => _edit(context, item, refresh),
                  onArchive: () => _archive(context, item, refresh),
                  onRestore: () => _restore(context, item, refresh),
                ),
          ],
        );
      },
    );
  }
}

class _AnnouncementCard extends StatelessWidget {
  const _AnnouncementCard(
    this.item, {
    required this.isLandlord,
    required this.onEdit,
    required this.onArchive,
    required this.onRestore,
  });

  final Announcement item;
  final bool isLandlord;
  final VoidCallback onEdit;
  final VoidCallback onArchive;
  final VoidCallback onRestore;

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
              if (item.isArchived) const StatusChip('archived', label: 'Archived'),
            ],
          ),
          const SizedBox(height: 8),
          Text(item.body),
          const SizedBox(height: 8),
          Text(byline, style: theme.textTheme.bodySmall),
          if (isLandlord) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Edit'),
                ),
                if (item.isArchived)
                  OutlinedButton.icon(
                    onPressed: onRestore,
                    icon: const Icon(Icons.unarchive_outlined),
                    label: const Text('Restore'),
                  )
                else
                  OutlinedButton.icon(
                    onPressed: onArchive,
                    icon: const Icon(Icons.archive_outlined),
                    label: const Text('Archive'),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
