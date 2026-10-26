import 'package:flutter/material.dart';

import '../../app_services.dart';
import '../../models/models.dart';
import '../../utils/format.dart';
import '../../widgets/common.dart';

/// The landlord's overview of one month: money, rooms, payments, and repairs.
class LandlordDashboardPage extends StatefulWidget {
  const LandlordDashboardPage({super.key});

  @override
  State<LandlordDashboardPage> createState() => _LandlordDashboardPageState();
}

class _LandlordDashboardPageState extends State<LandlordDashboardPage> {
  late String _period = periodOf(DateTime.now());

  Future<LandlordSummary> _load() async {
    final data = await AppServices.api.get(
      '/api/dashboard/landlord',
      query: {'period': _period},
    );
    return LandlordSummary.fromJson(asMap(data));
  }

  void _shift(int months) {
    final year = int.parse(_period.substring(0, 4));
    final month = int.parse(_period.substring(5, 7));
    setState(() => _period = periodOf(DateTime(year, month + months)));
  }

  Widget _monthBar() {
    return Row(
      children: [
        IconButton(
          tooltip: 'Previous month',
          onPressed: () => _shift(-1),
          icon: const Icon(Icons.chevron_left),
        ),
        Expanded(
          child: Text(
            monthLabel(_period),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        IconButton(
          tooltip: 'Next month',
          onPressed: () => _shift(1),
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AsyncView<LandlordSummary>(
      key: ValueKey<String>(_period),
      load: _load,
      builder: (context, s, refresh) {
        return PageList(
          title: 'Dashboard',
          onRefresh: refresh,
          children: [
            _monthBar(),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                MetricCard(
                  label: 'Total collections',
                  value: peso(s.totalCollections),
                  color: Colors.green.shade700,
                  footnote: 'Received for ${monthLabel(s.period)}',
                ),
                MetricCard(
                  label: 'Outstanding balance',
                  value: peso(s.outstandingBalance),
                  color: s.outstandingBalance > 0 ? Colors.red.shade700 : null,
                  footnote: 'All unpaid bills so far',
                ),
                MetricCard(
                  label: 'Occupancy rate',
                  value: '${s.occupancyRate}%',
                  footnote: '${s.occupiedRooms} of ${s.totalRooms} rooms occupied, ${s.vacantRooms} vacant',
                ),
                MetricCard(
                  label: 'Open maintenance',
                  value: '${s.openMaintenance}',
                  color: s.openMaintenance > 0 ? Colors.orange.shade800 : null,
                  footnote: s.roomsNeedingMaintenance.isEmpty
                      ? 'No rooms need maintenance'
                      : 'Rooms: ${s.roomsNeedingMaintenance.join(', ')}',
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Tenant payments for ${monthLabel(s.period)}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                MetricCard(
                  label: 'Paid',
                  value: '${s.paid}',
                  color: Colors.green.shade700,
                ),
                MetricCard(
                  label: 'Awaiting confirmation',
                  value: '${s.pendingConfirmation}',
                  color: Colors.blue.shade700,
                  footnote: 'Proof uploaded, needs your check',
                ),
                MetricCard(
                  label: 'Unpaid',
                  value: '${s.unpaid}',
                  color: Colors.orange.shade800,
                ),
                MetricCard(
                  label: 'Overdue',
                  value: '${s.overdue}',
                  color: s.overdue > 0 ? Colors.red.shade700 : null,
                  footnote: 'Past the due date',
                ),
              ],
            ),
            const SizedBox(height: 16),
            SectionCard(
              title: 'Open maintenance reports',
              child: s.recentReports.isEmpty
                  ? const Text('No open reports. Everything is fixed.')
                  : Column(
                      children: [
                        for (var i = 0; i < s.recentReports.length; i++) ...[
                          if (i > 0) const Divider(height: 1),
                          _ReportTile(s.recentReports[i]),
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

class _ReportTile extends StatelessWidget {
  const _ReportTile(this.report);

  final MaintenanceBrief report;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Room ${report.roomNumber}: ${titleCase(report.category)}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              StatusChip(report.status),
            ],
          ),
          const SizedBox(height: 4),
          Text(report.description, maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 6),
          Row(
            children: [
              StatusChip(report.urgency, label: '${titleCase(report.urgency)} urgency'),
              const SizedBox(width: 8),
              Text(formatDate(report.createdAt), style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ],
      ),
    );
  }
}
