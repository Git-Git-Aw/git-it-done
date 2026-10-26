import 'package:flutter/material.dart';

import '../../app_services.dart';
import '../../models/models.dart';
import '../../utils/format.dart';
import '../../utils/options.dart';
import '../../widgets/common.dart';
import '../../widgets/photo_widgets.dart';
import 'report_form_screen.dart';

/// A tenant's maintenance and issue reports, with their status.
class TenantMaintenancePage extends StatelessWidget {
  const TenantMaintenancePage({super.key});

  Future<List<MaintenanceReport>> _load() async {
    final data = await AppServices.api.get('/api/maintenance/mine');
    return asList(data).map((e) => MaintenanceReport.fromJson(asMap(e))).toList();
  }

  Future<void> _newReport(BuildContext context, Future<void> Function() refresh) async {
    final message = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(builder: (_) => const ReportFormScreen()),
    );
    if (message != null) {
      if (context.mounted) showSnack(context, message);
      await refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AsyncView<List<MaintenanceReport>>(
      load: _load,
      builder: (context, reports, refresh) {
        return PageList(
          title: 'Maintenance',
          onRefresh: refresh,
          actions: [
            FilledButton.icon(
              onPressed: () => _newReport(context, refresh),
              icon: const Icon(Icons.add),
              label: const Text('New report'),
            ),
          ],
          children: [
            if (reports.isEmpty)
              const EmptyState(
                icon: Icons.build_outlined,
                message: 'No reports yet. Tap "New report" if something in your room needs fixing.',
              )
            else
              for (final report in reports) _ReportCard(report),
          ],
        );
      },
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard(this.report);

  final MaintenanceReport report;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final photo = report.photoPath;
    final assigned = report.assignedTo;
    final remarks = report.remarks;
    final resolved = report.resolvedAt;
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(categoryIcon(report.category), color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${titleCase(report.category)} issue',
                  style: theme.textTheme.titleMedium,
                ),
              ),
              StatusChip(report.status),
            ],
          ),
          const SizedBox(height: 8),
          Text(report.description),
          const SizedBox(height: 8),
          Row(
            children: [
              StatusChip(report.urgency, label: '${titleCase(report.urgency)} urgency'),
              const SizedBox(width: 8),
              Text(
                'Room ${report.roomNumber}, sent ${formatDate(report.createdAt)}',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
          if (assigned != null) ...[
            const SizedBox(height: 8),
            InfoRow('Assigned to', assigned),
          ],
          if (remarks != null) InfoRow('Landlord remarks', remarks),
          if (resolved != null) InfoRow('Resolved on', formatDate(resolved)),
          if (photo != null) ...[
            const SizedBox(height: 8),
            NetworkPhoto(photo),
          ],
        ],
      ),
    );
  }
}
