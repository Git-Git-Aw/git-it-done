import 'package:flutter/material.dart';

import '../../app_services.dart';
import '../../models/models.dart';
import '../../utils/format.dart';
import '../../utils/options.dart';
import '../../widgets/common.dart';
import '../../widgets/form_dialog.dart';
import '../../widgets/photo_widgets.dart';

class _MaintenanceData {
  _MaintenanceData(this.reports, this.rooms);

  final List<MaintenanceReport> reports;
  final List<Room> rooms;
}

/// Landlord: every maintenance report, filter by room and status, and update
/// the status, remarks, and who is assigned.
class LandlordMaintenancePage extends StatefulWidget {
  const LandlordMaintenancePage({super.key});

  @override
  State<LandlordMaintenancePage> createState() => _LandlordMaintenancePageState();
}

class _LandlordMaintenancePageState extends State<LandlordMaintenancePage> {
  /// all, Pending, In Progress, or Resolved
  String _status = 'all';

  /// null = all rooms
  int? _roomId;

  Future<_MaintenanceData> _load() async {
    final query = <String, String>{
      if (_status != 'all') 'status': _status,
      if (_roomId != null) 'roomId': '$_roomId',
    };
    final reportsData = await AppServices.api.get('/api/maintenance', query: query);
    final roomsData = await AppServices.api.get('/api/rooms');
    return _MaintenanceData(
      asList(reportsData).map((e) => MaintenanceReport.fromJson(asMap(e))).toList(),
      asList(roomsData).map((e) => Room.fromJson(asMap(e))).toList(),
    );
  }

  Future<void> _update(BuildContext context, MaintenanceReport report, Future<void> Function() refresh) {
    return afterDialog(
      context,
      showFormDialog(
        context,
        title: 'Update report',
        intro: 'Room ${report.roomNumber}: ${titleCase(report.category)}. The tenant is notified when the status changes.',
        fields: [
          FieldSpec('status', 'Status', kind: FieldKind.choice, options: maintenanceStatuses, initial: report.status),
          FieldSpec('assignedTo', 'Assigned to (optional)', initial: report.assignedTo ?? ''),
          FieldSpec('remarks', 'Remarks (optional)', kind: FieldKind.multiline, initial: report.remarks ?? ''),
        ],
        onSubmit: (v) async {
          await AppServices.api.patch('/api/maintenance/${report.id}', body: {
            'status': v['status'],
            'assignedTo': v['assignedTo'],
            'remarks': v['remarks'],
          });
          return 'Report updated.';
        },
      ),
      refresh,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AsyncView<_MaintenanceData>(
      key: ValueKey<String>('$_status-$_roomId'),
      load: _load,
      builder: (context, data, refresh) {
        final theme = Theme.of(context);
        return PageList(
          title: 'Maintenance',
          onRefresh: refresh,
          children: [
            FilterChips(
              selected: _status,
              onSelected: (value) => setState(() => _status = value),
              options: const {
                'all': 'All',
                'Pending': 'Pending',
                'In Progress': 'In progress',
                'Resolved': 'Resolved',
              },
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: DropdownMenu<int>(
                width: 240,
                initialSelection: _roomId ?? 0,
                label: const Text('Room'),
                dropdownMenuEntries: [
                  const DropdownMenuEntry<int>(value: 0, label: 'All rooms'),
                  for (final room in data.rooms)
                    DropdownMenuEntry<int>(value: room.id, label: 'Room ${room.roomNumber}'),
                ],
                onSelected: (value) => setState(() {
                  _roomId = (value == null || value == 0) ? null : value;
                }),
              ),
            ),
            const SizedBox(height: 12),
            if (data.reports.isEmpty)
              const EmptyState(icon: Icons.build_outlined, message: 'No maintenance reports here.')
            else
              for (final report in data.reports)
                SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(categoryIcon(report.category), color: theme.colorScheme.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Room ${report.roomNumber}: ${titleCase(report.category)}',
                              style: theme.textTheme.titleMedium,
                            ),
                          ),
                          StatusChip(report.status),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(report.description),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          StatusChip(report.urgency, label: '${titleCase(report.urgency)} urgency'),
                          Text(
                            'From ${report.tenantName}, ${formatDate(report.createdAt)}',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                      if (report.assignedTo != null) InfoRow('Assigned to', report.assignedTo!),
                      if (report.remarks != null) InfoRow('Remarks', report.remarks!),
                      if (report.resolvedAt != null) InfoRow('Resolved on', formatDate(report.resolvedAt)),
                      if (report.photoPath != null) ...[
                        const SizedBox(height: 8),
                        NetworkPhoto(report.photoPath!, size: 130),
                      ],
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () => _update(context, report, refresh),
                        icon: const Icon(Icons.edit_note),
                        label: const Text('Update status'),
                      ),
                    ],
                  ),
                ),
          ],
        );
      },
    );
  }
}
