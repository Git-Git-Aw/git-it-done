import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../api/api_client.dart';
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

  Future<void> _showSummary() {
    return showDialog<void>(
      context: context,
      builder: (_) => _SummaryDialog(period: _period),
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
            MonthBar(
              period: _period,
              onChanged: (value) => setState(() => _period = value),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: _showSummary,
                icon: const Icon(Icons.auto_awesome),
                label: const Text('Generate AI summary'),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                MetricCard(
                  label: 'Total collections',
                  icon: Icons.payments_outlined,
                  value: peso(s.totalCollections),
                  color: Colors.green.shade700,
                  footnote: 'Received for ${monthLabel(s.period)}',
                ),
                MetricCard(
                  label: 'Outstanding balance',
                  icon: Icons.account_balance_wallet_outlined,
                  value: peso(s.outstandingBalance),
                  color: s.outstandingBalance > 0 ? Colors.red.shade700 : null,
                  footnote: 'All unpaid bills so far',
                ),
                MetricCard(
                  label: 'Occupancy rate',
                  icon: Icons.meeting_room_outlined,
                  value: '${s.occupancyRate}%',
                  footnote: '${s.occupiedRooms} of ${s.totalRooms} rooms occupied, ${s.vacantRooms} vacant',
                ),
                MetricCard(
                  label: 'Open maintenance',
                  icon: Icons.build_outlined,
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
                  icon: Icons.check_circle_outline,
                  value: '${s.paid}',
                  color: Colors.green.shade700,
                ),
                MetricCard(
                  label: 'Awaiting confirmation',
                  icon: Icons.hourglass_top,
                  value: '${s.pendingConfirmation}',
                  color: Colors.blue.shade700,
                  footnote: 'Proof uploaded, needs your check',
                ),
                MetricCard(
                  label: 'Unpaid',
                  icon: Icons.receipt_long_outlined,
                  value: '${s.unpaid}',
                  color: Colors.orange.shade800,
                ),
                MetricCard(
                  label: 'Overdue',
                  icon: Icons.warning_amber_rounded,
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

/// Asks the AI Dorm Manager for the monthly summary and shows the answer.
class _SummaryDialog extends StatefulWidget {
  const _SummaryDialog({required this.period});

  final String period;

  @override
  State<_SummaryDialog> createState() => _SummaryDialogState();
}

class _SummaryDialogState extends State<_SummaryDialog> {
  String? _text;
  String? _error;

  @override
  void initState() {
    super.initState();
    _generate();
  }

  Future<void> _generate() async {
    try {
      final data = await AppServices.api.post(
        '/api/chat/summary',
        body: {'period': widget.period},
      );
      final reply = ChatReply.fromJson(asMap(data));
      if (!mounted) return;
      setState(() => _text = plainText(reply.reply));
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Something went wrong. Please try again.');
    }
  }

  Future<void> _copy() async {
    final text = _text;
    if (text == null) return;
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) showSnack(context, 'Summary copied.');
  }

  @override
  Widget build(BuildContext context) {
    final text = _text;
    final error = _error;
    Widget content;
    if (error != null) {
      content = Text(error, style: TextStyle(color: Theme.of(context).colorScheme.error));
    } else if (text == null) {
      content = const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    } else {
      content = SingleChildScrollView(child: SelectableText(text));
    }
    return AlertDialog(
      title: Text('AI summary: ${monthLabel(widget.period)}'),
      content: SizedBox(width: 480, child: content),
      actions: [
        if (text != null)
          TextButton.icon(
            onPressed: _copy,
            icon: const Icon(Icons.copy),
            label: const Text('Copy'),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
