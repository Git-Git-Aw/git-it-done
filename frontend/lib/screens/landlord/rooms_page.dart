import 'package:flutter/material.dart';

import '../../app_services.dart';
import '../../models/models.dart';
import '../../utils/format.dart';
import '../../widgets/common.dart';
import '../../widgets/form_dialog.dart';

/// Landlord: add, edit, archive and restore rooms, and see who is in each room.
class RoomsPage extends StatefulWidget {
  const RoomsPage({super.key});

  @override
  State<RoomsPage> createState() => _RoomsPageState();
}

class _RoomsPageState extends State<RoomsPage> {
  /// all (not archived), vacant, occupied, full, or archived
  String _filter = 'all';

  Future<List<Room>> _load() async {
    final data = await AppServices.api.get('/api/rooms', query: {'archived': 'true'});
    return asList(data).map((e) => Room.fromJson(asMap(e))).toList();
  }

  List<FieldSpec> _fields(Room? room) {
    return [
      FieldSpec('roomNumber', 'Room number', required: true, initial: room?.roomNumber ?? '', maxLength: 20),
      FieldSpec('description', 'Description', kind: FieldKind.multiline, initial: room?.description ?? ''),
      FieldSpec(
        'monthlyRate',
        'Monthly rate (PHP)',
        kind: FieldKind.number,
        required: true,
        initial: room == null ? '' : plainNumber(room.monthlyRate),
      ),
      FieldSpec(
        'capacity',
        'Capacity (how many tenants)',
        kind: FieldKind.number,
        required: true,
        initial: room == null ? '1' : '${room.capacity}',
        validator: (v) => (double.tryParse(v) ?? 0) >= 1 ? null : 'At least 1',
      ),
    ];
  }

  Map<String, dynamic> _body(Map<String, String> v) {
    return {
      'roomNumber': v['roomNumber'],
      'description': v['description'],
      'monthlyRate': double.parse(v['monthlyRate']!),
      'capacity': double.parse(v['capacity']!).round(),
    };
  }

  Future<void> _add(BuildContext context, Future<void> Function() refresh) {
    return afterDialog(
      context,
      showFormDialog(
        context,
        title: 'Add room',
        fields: _fields(null),
        onSubmit: (v) async {
          await AppServices.api.post('/api/rooms', body: _body(v));
          return 'Room ${v['roomNumber']} added.';
        },
      ),
      refresh,
    );
  }

  Future<void> _edit(BuildContext context, Room room, Future<void> Function() refresh) {
    return afterDialog(
      context,
      showFormDialog(
        context,
        title: 'Edit room ${room.roomNumber}',
        fields: _fields(room),
        onSubmit: (v) async {
          await AppServices.api.put('/api/rooms/${room.id}', body: _body(v));
          return 'Room ${v['roomNumber']} updated.';
        },
      ),
      refresh,
    );
  }

  Future<void> _archive(BuildContext context, Room room, Future<void> Function() refresh) async {
    final ok = await confirmDialog(
      context,
      title: 'Archive room ${room.roomNumber}?',
      message: 'The room is hidden from the lists but its records are kept. You can restore it later.',
      confirmLabel: 'Archive',
    );
    if (!ok || !context.mounted) return;
    await runAction(context, () async {
      await AppServices.api.patch('/api/rooms/${room.id}/archive');
      return 'Room ${room.roomNumber} archived.';
    }, refresh);
  }

  Future<void> _restore(BuildContext context, Room room, Future<void> Function() refresh) {
    return runAction(context, () async {
      await AppServices.api.patch('/api/rooms/${room.id}/restore');
      return 'Room ${room.roomNumber} restored.';
    }, refresh);
  }

  bool _matches(Room room) {
    switch (_filter) {
      case 'archived':
        return room.isArchived;
      case 'all':
        return !room.isArchived;
      default:
        return !room.isArchived && room.occupancyStatus == _filter;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AsyncView<List<Room>>(
      load: _load,
      builder: (context, rooms, refresh) {
        final active = rooms.where((r) => !r.isArchived).toList();
        final shown = rooms.where(_matches).toList();
        final occupiedRooms = active.where((r) => r.occupants > 0).length;
        final slots = active.fold<int>(0, (sum, r) => sum + r.capacity);
        final taken = active.fold<int>(0, (sum, r) => sum + r.occupants);
        final rate = slots == 0 ? 0 : (taken * 100 / slots).round();
        return PageList(
          title: 'Rooms',
          onRefresh: refresh,
          actions: [
            FilledButton.icon(
              onPressed: () => _add(context, refresh),
              icon: const Icon(Icons.add),
              label: const Text('Add room'),
            ),
          ],
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                MetricCard(
                  label: 'Rooms',
                  value: '${active.length}',
                  footnote: '$occupiedRooms occupied, ${active.length - occupiedRooms} vacant',
                ),
                MetricCard(
                  label: 'Occupancy rate',
                  value: '$rate%',
                  footnote: '$taken of $slots beds taken',
                ),
              ],
            ),
            const SizedBox(height: 12),
            FilterChips(
              selected: _filter,
              onSelected: (value) => setState(() => _filter = value),
              options: const {
                'all': 'All',
                'vacant': 'Vacant',
                'occupied': 'Occupied',
                'full': 'Full',
                'archived': 'Archived',
              },
            ),
            const SizedBox(height: 12),
            if (shown.isEmpty)
              const EmptyState(icon: Icons.meeting_room_outlined, message: 'No rooms here.')
            else
              for (final room in shown)
                _RoomCard(
                  room: room,
                  onEdit: () => _edit(context, room, refresh),
                  onArchive: () => _archive(context, room, refresh),
                  onRestore: () => _restore(context, room, refresh),
                ),
          ],
        );
      },
    );
  }
}

class _RoomCard extends StatelessWidget {
  const _RoomCard({
    required this.room,
    required this.onEdit,
    required this.onArchive,
    required this.onRestore,
  });

  final Room room;
  final VoidCallback onEdit;
  final VoidCallback onArchive;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = room.isArchived ? 'archived' : room.occupancyStatus;
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('Room ${room.roomNumber}', style: theme.textTheme.titleMedium)),
              StatusChip(status),
            ],
          ),
          const SizedBox(height: 8),
          InfoRow('Monthly rate', peso(room.monthlyRate)),
          InfoRow('Occupancy', '${room.occupants} of ${room.capacity}'),
          if (room.description.isNotEmpty) InfoRow('About', room.description),
          if (room.occupantNames.isNotEmpty) InfoRow('Tenants', room.occupantNames.join(', ')),
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
              if (room.isArchived)
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
      ),
    );
  }
}
