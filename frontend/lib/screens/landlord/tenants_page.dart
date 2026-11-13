import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../app_services.dart';
import '../../models/models.dart';
import '../../utils/format.dart';
import '../../widgets/common.dart';
import '../../widgets/form_dialog.dart';

/// Landlord: approve, create, edit and archive tenants; assign and end leases.
class TenantsPage extends StatefulWidget {
  const TenantsPage({super.key});

  @override
  State<TenantsPage> createState() => _TenantsPageState();
}

class _TenantsPageState extends State<TenantsPage> {
  /// all (not archived), pending, active, or archived
  String _filter = 'all';

  Future<List<TenantRecord>> _load() async {
    final data = await AppServices.api.get('/api/tenants');
    return asList(data).map((e) => TenantRecord.fromJson(asMap(e))).toList();
  }

  bool _matches(TenantRecord t) {
    switch (_filter) {
      case 'archived':
        return t.status == 'archived';
      case 'all':
        return t.status != 'archived';
      default:
        return t.status == _filter;
    }
  }

  Future<void> _create(BuildContext context, Future<void> Function() refresh) {
    return afterDialog(
      context,
      showFormDialog(
        context,
        title: 'Add tenant',
        intro: 'The account is active right away. Share the email and password with the tenant.',
        fields: [
          const FieldSpec('fullName', 'Full name', required: true),
          FieldSpec(
            'email',
            'Email',
            required: true,
            validator: (v) => isValidEmail(v) ? null : 'Enter a valid email',
          ),
          const FieldSpec('contactNumber', 'Contact number'),
          FieldSpec(
            'password',
            'Password (at least 8 characters)',
            kind: FieldKind.password,
            required: true,
            validator: (v) => v.length >= 8 ? null : 'Use at least 8 characters',
          ),
        ],
        submitLabel: 'Create account',
        onSubmit: (v) async {
          await AppServices.api.post('/api/tenants', body: {
            'fullName': v['fullName'],
            'email': v['email'],
            'contactNumber': v['contactNumber'],
            'password': v['password'],
          });
          return 'Tenant ${v['fullName']} added.';
        },
      ),
      refresh,
    );
  }

  Future<void> _edit(BuildContext context, TenantRecord t, Future<void> Function() refresh) {
    return afterDialog(
      context,
      showFormDialog(
        context,
        title: 'Edit ${t.fullName}',
        fields: [
          FieldSpec('fullName', 'Full name', required: true, initial: t.fullName),
          FieldSpec(
            'email',
            'Email',
            required: true,
            initial: t.email,
            validator: (v) => isValidEmail(v) ? null : 'Enter a valid email',
          ),
          FieldSpec('contactNumber', 'Contact number', initial: t.contactNumber ?? ''),
        ],
        onSubmit: (v) async {
          await AppServices.api.put('/api/tenants/${t.id}', body: {
            'fullName': v['fullName'],
            'email': v['email'],
            'contactNumber': v['contactNumber'],
          });
          return 'Tenant updated.';
        },
      ),
      refresh,
    );
  }

  Future<void> _approve(BuildContext context, TenantRecord t, Future<void> Function() refresh) {
    return runAction(context, () async {
      await AppServices.api.patch('/api/tenants/${t.id}/approve');
      return '${t.fullName} approved. They can log in now.';
    }, refresh);
  }

  Future<void> _archive(BuildContext context, TenantRecord t, Future<void> Function() refresh) async {
    final ok = await confirmDialog(
      context,
      title: 'Archive ${t.fullName}?',
      message: 'The tenant can no longer log in, but their records are kept.',
      confirmLabel: 'Archive',
    );
    if (!ok || !context.mounted) return;
    await runAction(context, () async {
      await AppServices.api.patch('/api/tenants/${t.id}/archive');
      return '${t.fullName} archived.';
    }, refresh);
  }

  Future<void> _assignRoom(BuildContext context, TenantRecord t, Future<void> Function() refresh) async {
    List<Room> free;
    try {
      final data = await AppServices.api.get('/api/rooms', cached: false);
      free = asList(data)
          .map((e) => Room.fromJson(asMap(e)))
          .where((r) => !r.isArchived && r.occupancyStatus != 'full')
          .toList();
    } catch (e) {
      if (context.mounted) showSnack(context, errorText(e));
      return;
    }
    if (!context.mounted) return;
    if (free.isEmpty) {
      showSnack(context, 'No room is free. Add a room or end another lease first.');
      return;
    }
    final byLabel = {for (final r in free) 'Room ${r.roomNumber}': r};
    await afterDialog(
      context,
      showFormDialog(
        context,
        title: 'Assign a room to ${t.fullName}',
        fields: [
          FieldSpec('room', 'Room', kind: FieldKind.choice, options: byLabel.keys.toList()),
          FieldSpec('startDate', 'Lease starts', kind: FieldKind.date, required: true, initial: dateValue(DateTime.now())),
          const FieldSpec('endDate', 'Lease ends (optional)', kind: FieldKind.date),
          const FieldSpec(
            'monthlyRent',
            'Monthly rent (optional)',
            kind: FieldKind.number,
            hint: 'Blank uses the room rate',
          ),
          FieldSpec(
            'dueDay',
            'Due day of the month',
            kind: FieldKind.number,
            required: true,
            initial: '5',
            validator: (v) {
              final day = double.tryParse(v) ?? 0;
              return day >= 1 && day <= 28 ? null : 'Use a day from 1 to 28';
            },
          ),
        ],
        submitLabel: 'Assign room',
        onSubmit: (v) async {
          final room = byLabel[v['room']];
          if (room == null) throw ApiException('Choose a room.');
          final body = <String, dynamic>{
            'tenantId': t.id,
            'roomId': room.id,
            'startDate': v['startDate'],
            'dueDay': double.parse(v['dueDay']!).round(),
            if (v['endDate']!.isNotEmpty) 'endDate': v['endDate'],
            if (v['monthlyRent']!.isNotEmpty) 'monthlyRent': double.parse(v['monthlyRent']!),
          };
          await AppServices.api.post('/api/leases', body: body);
          return '${t.fullName} is now in Room ${room.roomNumber}.';
        },
      ),
      refresh,
    );
  }

  Future<void> _editLease(BuildContext context, TenantRecord t, Future<void> Function() refresh) {
    final lease = t.lease!;
    return afterDialog(
      context,
      showFormDialog(
        context,
        title: 'Edit lease of ${t.fullName}',
        fields: [
          FieldSpec('startDate', 'Lease starts', kind: FieldKind.date, required: true, initial: lease.startDate.length >= 10 ? lease.startDate.substring(0, 10) : lease.startDate),
          FieldSpec('endDate', 'Lease ends (optional)', kind: FieldKind.date, initial: lease.endDate == null ? '' : (lease.endDate!.length >= 10 ? lease.endDate!.substring(0, 10) : lease.endDate!)),
          FieldSpec('monthlyRent', 'Monthly rent', kind: FieldKind.number, required: true, initial: plainNumber(lease.monthlyRent)),
          FieldSpec(
            'dueDay',
            'Due day of the month',
            kind: FieldKind.number,
            required: true,
            initial: '${lease.dueDay}',
            validator: (v) {
              final day = double.tryParse(v) ?? 0;
              return day >= 1 && day <= 28 ? null : 'Use a day from 1 to 28';
            },
          ),
        ],
        onSubmit: (v) async {
          await AppServices.api.put('/api/leases/${lease.id}', body: {
            'startDate': v['startDate'],
            'endDate': v['endDate']!.isEmpty ? null : v['endDate'],
            'monthlyRent': double.parse(v['monthlyRent']!),
            'dueDay': double.parse(v['dueDay']!).round(),
          });
          return 'Lease updated.';
        },
      ),
      refresh,
    );
  }

  Future<void> _endLease(BuildContext context, TenantRecord t, Future<void> Function() refresh) {
    final lease = t.lease!;
    final room = lease.room?.roomNumber ?? '';
    return afterDialog(
      context,
      showFormDialog(
        context,
        title: 'End lease',
        intro: '${t.fullName} will no longer be assigned to Room $room.',
        fields: [
          FieldSpec('endDate', 'Move-out date', kind: FieldKind.date, required: true, initial: dateValue(DateTime.now())),
        ],
        submitLabel: 'End lease',
        onSubmit: (v) async {
          await AppServices.api.patch('/api/leases/${lease.id}/end', body: {'endDate': v['endDate']});
          return 'Lease ended. Room $room is free again.';
        },
      ),
      refresh,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AsyncView<List<TenantRecord>>(
      load: _load,
      builder: (context, tenants, refresh) {
        final shown = tenants.where(_matches).toList()
          ..sort((a, b) {
            // Tenants waiting for approval come first.
            final aPending = a.status == 'pending' ? 0 : 1;
            final bPending = b.status == 'pending' ? 0 : 1;
            if (aPending != bPending) return aPending - bPending;
            return a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase());
          });
        final pendingCount = tenants.where((t) => t.status == 'pending').length;
        return PageList(
          title: 'Tenants',
          onRefresh: refresh,
          actions: [
            FilledButton.icon(
              onPressed: () => _create(context, refresh),
              icon: const Icon(Icons.person_add_alt),
              label: const Text('Add tenant'),
            ),
          ],
          children: [
            FilterChips(
              selected: _filter,
              onSelected: (value) => setState(() => _filter = value),
              options: {
                'all': 'All',
                'pending': pendingCount > 0 ? 'Waiting approval ($pendingCount)' : 'Waiting approval',
                'active': 'Active',
                'archived': 'Archived',
              },
            ),
            const SizedBox(height: 12),
            if (shown.isEmpty)
              const EmptyState(icon: Icons.people_outline, message: 'No tenants here.')
            else
              for (final t in shown)
                _TenantCard(
                  tenant: t,
                  onApprove: () => _approve(context, t, refresh),
                  onEdit: () => _edit(context, t, refresh),
                  onArchive: () => _archive(context, t, refresh),
                  onAssign: () => _assignRoom(context, t, refresh),
                  onEditLease: () => _editLease(context, t, refresh),
                  onEndLease: () => _endLease(context, t, refresh),
                ),
          ],
        );
      },
    );
  }
}

class _TenantCard extends StatelessWidget {
  const _TenantCard({
    required this.tenant,
    required this.onApprove,
    required this.onEdit,
    required this.onArchive,
    required this.onAssign,
    required this.onEditLease,
    required this.onEndLease,
  });

  final TenantRecord tenant;
  final VoidCallback onApprove;
  final VoidCallback onEdit;
  final VoidCallback onArchive;
  final VoidCallback onAssign;
  final VoidCallback onEditLease;
  final VoidCallback onEndLease;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lease = tenant.lease;
    final contact = tenant.contactNumber;
    final statusText = tenant.status == 'pending' ? 'Waiting approval' : titleCase(tenant.status);
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(tenant.fullName, style: theme.textTheme.titleMedium)),
              StatusChip(tenant.status == 'active' ? 'paid' : tenant.status, label: statusText),
            ],
          ),
          const SizedBox(height: 8),
          InfoRow('Email', tenant.email),
          if (contact != null) InfoRow('Contact', contact),
          if (lease != null) ...[
            InfoRow('Room', lease.room?.roomNumber ?? '-'),
            InfoRow('Monthly rent', peso(lease.monthlyRent)),
            InfoRow('Due day', 'Day ${lease.dueDay} of each month'),
            InfoRow('Lease', '${formatDate(lease.startDate)} to ${lease.endDate == null ? 'no end date' : formatDate(lease.endDate)}'),
          ] else if (tenant.status == 'active')
            const InfoRow('Room', 'Not assigned yet'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (tenant.status == 'pending')
                FilledButton.icon(
                  onPressed: onApprove,
                  icon: const Icon(Icons.check),
                  label: const Text('Approve'),
                ),
              if (tenant.status == 'active' && lease == null)
                FilledButton.icon(
                  onPressed: onAssign,
                  icon: const Icon(Icons.meeting_room_outlined),
                  label: const Text('Assign room'),
                ),
              if (lease != null) ...[
                OutlinedButton.icon(
                  onPressed: onEditLease,
                  icon: const Icon(Icons.edit_calendar_outlined),
                  label: const Text('Edit lease'),
                ),
                OutlinedButton.icon(
                  onPressed: onEndLease,
                  icon: const Icon(Icons.logout),
                  label: const Text('End lease'),
                ),
              ],
              if (tenant.status != 'archived')
                OutlinedButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Edit'),
                ),
              if (tenant.status != 'archived' && lease == null)
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
