import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app_services.dart';
import '../../models/models.dart';
import '../../utils/file_download.dart';
import '../../utils/format.dart';
import '../../widgets/common.dart';

/// Landlord: the monthly payment summary, with a CSV export.
class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  String _period = periodOf(DateTime.now());
  bool _exporting = false;

  Future<MonthlyReport> _load() async {
    final data = await AppServices.api.get(
      '/api/reports/monthly',
      query: {'month': _period, 'format': 'json'},
    );
    return MonthlyReport.fromJson(asMap(data));
  }

  Future<void> _export(BuildContext context) async {
    setState(() => _exporting = true);
    try {
      final csv = await AppServices.api.getText(
        '/api/reports/monthly',
        query: {'month': _period, 'format': 'csv'},
      );
      final filename = 'payments-$_period.csv';
      final saved = await downloadTextFile(filename, csv);
      if (saved) {
        if (context.mounted) showSnack(context, 'Downloaded $filename');
      } else {
        await Clipboard.setData(ClipboardData(text: csv));
        if (context.mounted) {
          showSnack(context, 'CSV copied. Paste it into Excel or Notepad and save it as $filename.');
        }
      }
    } catch (e) {
      if (context.mounted) showSnack(context, errorText(e));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AsyncView<MonthlyReport>(
      key: ValueKey<String>(_period),
      load: _load,
      builder: (context, report, refresh) {
        return PageList(
          title: 'Monthly report',
          onRefresh: refresh,
          actions: [
            FilledButton.icon(
              onPressed: _exporting ? null : () => _export(context),
              icon: const Icon(Icons.download),
              label: const Text('Export CSV'),
            ),
          ],
          children: [
            MonthBar(period: _period, onChanged: (value) => setState(() => _period = value)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                MetricCard(label: 'Billed', value: peso(report.billed), footnote: monthLabel(report.month)),
                MetricCard(label: 'Collected', value: peso(report.collected), color: Colors.green.shade700),
                MetricCard(
                  label: 'Outstanding',
                  value: peso(report.outstanding),
                  color: report.outstanding > 0 ? Colors.red.shade700 : null,
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (report.rows.isEmpty)
              const EmptyState(
                icon: Icons.assessment_outlined,
                message: 'No bills for this month yet. Generate bills on the Payments page first.',
              )
            else
              SectionCard(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('Room')),
                      DataColumn(label: Text('Tenant')),
                      DataColumn(label: Text('Due date')),
                      DataColumn(label: Text('Amount due'), numeric: true),
                      DataColumn(label: Text('Paid'), numeric: true),
                      DataColumn(label: Text('Balance'), numeric: true),
                      DataColumn(label: Text('Status')),
                    ],
                    rows: [
                      for (final bill in report.rows)
                        DataRow(
                          cells: [
                            DataCell(Text(bill.roomNumber)),
                            DataCell(Text(bill.tenantName)),
                            DataCell(Text(formatDate(bill.dueDate))),
                            DataCell(Text(peso(bill.amountDue))),
                            DataCell(Text(peso(bill.amountPaid))),
                            DataCell(Text(peso(bill.balance))),
                            DataCell(StatusChip(bill.displayStatus)),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
