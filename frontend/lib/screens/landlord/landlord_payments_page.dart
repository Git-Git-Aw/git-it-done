import 'package:flutter/material.dart';

import '../../app_services.dart';
import '../../models/models.dart';
import '../../utils/format.dart';
import '../../utils/options.dart';
import '../../widgets/common.dart';
import '../../widgets/form_dialog.dart';
import '../../widgets/photo_widgets.dart';

/// Landlord: who paid, who is unpaid or overdue, generate bills, record
/// payments, and confirm or reject the receipts tenants uploaded.
class LandlordPaymentsPage extends StatefulWidget {
  const LandlordPaymentsPage({super.key});

  @override
  State<LandlordPaymentsPage> createState() => _LandlordPaymentsPageState();
}

class _LandlordPaymentsPageState extends State<LandlordPaymentsPage> {
  String _period = periodOf(DateTime.now());

  /// all, paid, unpaid, overdue, or pending_confirmation
  String _status = 'all';

  Future<List<Bill>> _load() async {
    final query = <String, String>{
      'period': _period,
      if (_status != 'all') 'status': _status,
    };
    final data = await AppServices.api.get('/api/payments', query: query);
    return asList(data).map((e) => Bill.fromJson(asMap(e))).toList();
  }

  Future<void> _generate(BuildContext context, Future<void> Function() refresh) async {
    String? generated;
    final message = await showFormDialog(
      context,
      title: 'Generate bills',
      intro: 'Creates this month\'s bill for every tenant with an active lease. '
          'Bills that already exist are skipped.',
      fields: [
        FieldSpec(
          'period',
          'Month (YYYY-MM)',
          required: true,
          initial: _period,
          validator: (v) => isPeriodText(v) ? null : 'Use the form YYYY-MM, for example 2026-11',
        ),
      ],
      submitLabel: 'Generate',
      onSubmit: (v) async {
        final data = asMap(await AppServices.api.post('/api/payments/generate', body: {'period': v['period']}));
        generated = v['period'];
        final created = data['created'] ?? 0;
        final existing = data['alreadyBilled'] ?? 0;
        final notStarted = data['notYetStarted'] ?? 0;
        final extra = notStarted == 0 ? '' : ', $notStarted lease(s) not started yet';
        return 'Bills for ${monthLabel(v['period']!)}: $created created, $existing already existed$extra.';
      },
    );
    if (message == null) return;
    if (context.mounted) showSnack(context, message);
    final target = generated;
    if (target != null && target != _period) {
      setState(() => _period = target);
    } else {
      await refresh();
    }
  }

  Future<void> _confirm(BuildContext context, Bill bill, Future<void> Function() refresh) {
    return afterDialog(
      context,
      showFormDialog(
        context,
        title: 'Confirm receipt',
        intro: '${bill.tenantName}, ${monthLabel(bill.period)}. Check the receipt photo, then confirm the amount received.',
        fields: [
          FieldSpec('amountPaid', 'Amount received (PHP)', kind: FieldKind.number, required: true, initial: plainNumber(bill.balance)),
          const FieldSpec('remarks', 'Note (optional)'),
        ],
        submitLabel: 'Confirm payment',
        onSubmit: (v) async {
          await AppServices.api.patch('/api/payments/${bill.id}/confirm', body: {
            'amountPaid': double.parse(v['amountPaid']!),
            if (v['remarks']!.isNotEmpty) 'remarks': v['remarks'],
          });
          return 'Payment confirmed. ${bill.tenantName} was notified.';
        },
      ),
      refresh,
    );
  }

  Future<void> _reject(BuildContext context, Bill bill, Future<void> Function() refresh) {
    return afterDialog(
      context,
      showFormDialog(
        context,
        title: 'Reject receipt',
        intro: 'The bill goes back to unpaid and ${bill.tenantName} is told why.',
        fields: [
          const FieldSpec('remarks', 'Reason', kind: FieldKind.multiline, hint: 'For example: the photo is blurry'),
        ],
        submitLabel: 'Reject receipt',
        onSubmit: (v) async {
          await AppServices.api.patch('/api/payments/${bill.id}/reject', body: {
            if (v['remarks']!.isNotEmpty) 'remarks': v['remarks'],
          });
          return 'Receipt rejected.';
        },
      ),
      refresh,
    );
  }

  Future<void> _record(BuildContext context, Bill bill, Future<void> Function() refresh) {
    return afterDialog(
      context,
      showFormDialog(
        context,
        title: 'Record payment',
        intro: '${bill.tenantName}, ${monthLabel(bill.period)}. Use this for cash or payments received outside the app.',
        fields: [
          FieldSpec('amountPaid', 'Amount received (PHP)', kind: FieldKind.number, required: true, initial: plainNumber(bill.balance)),
          const FieldSpec('method', 'Paid by', kind: FieldKind.choice, options: paymentMethods),
          const FieldSpec('remarks', 'Note (optional)'),
        ],
        submitLabel: 'Record payment',
        onSubmit: (v) async {
          await AppServices.api.patch('/api/payments/${bill.id}/record', body: {
            'amountPaid': double.parse(v['amountPaid']!),
            'method': v['method'],
            if (v['remarks']!.isNotEmpty) 'remarks': v['remarks'],
          });
          return 'Payment recorded for ${bill.tenantName}.';
        },
      ),
      refresh,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AsyncView<List<Bill>>(
      key: ValueKey<String>('$_period-$_status'),
      load: _load,
      builder: (context, bills, refresh) {
        final billed = bills.fold<double>(0, (sum, b) => sum + b.amountDue);
        final collected = bills.fold<double>(0, (sum, b) => sum + b.amountPaid);
        final balance = bills.fold<double>(0, (sum, b) => sum + b.balance);
        return PageList(
          title: 'Payments',
          onRefresh: refresh,
          actions: [
            FilledButton.icon(
              onPressed: () => _generate(context, refresh),
              icon: const Icon(Icons.receipt_long_outlined),
              label: const Text('Generate bills'),
            ),
          ],
          children: [
            MonthBar(period: _period, onChanged: (value) => setState(() => _period = value)),
            FilterChips(
              selected: _status,
              onSelected: (value) => setState(() => _status = value),
              options: const {
                'all': 'All',
                'paid': 'Paid',
                'unpaid': 'Unpaid',
                'overdue': 'Overdue',
                'pending_confirmation': 'Awaiting confirmation',
              },
            ),
            const SizedBox(height: 12),
            if (bills.isNotEmpty)
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  MetricCard(label: 'Billed', value: peso(billed), footnote: '${bills.length} bill${bills.length == 1 ? '' : 's'} shown'),
                  MetricCard(label: 'Collected', value: peso(collected), color: Colors.green.shade700),
                  MetricCard(
                    label: 'Balance',
                    value: peso(balance),
                    color: balance > 0 ? Colors.red.shade700 : null,
                  ),
                ],
              ),
            const SizedBox(height: 12),
            if (bills.isEmpty)
              const EmptyState(
                icon: Icons.receipt_long_outlined,
                message: 'No bills here. Use "Generate bills" to create this month\'s bills.',
              )
            else
              for (final bill in bills)
                _BillCard(
                  bill: bill,
                  onConfirm: () => _confirm(context, bill, refresh),
                  onReject: () => _reject(context, bill, refresh),
                  onRecord: () => _record(context, bill, refresh),
                ),
          ],
        );
      },
    );
  }
}

class _BillCard extends StatelessWidget {
  const _BillCard({
    required this.bill,
    required this.onConfirm,
    required this.onReject,
    required this.onRecord,
  });

  final Bill bill;
  final VoidCallback onConfirm;
  final VoidCallback onReject;
  final VoidCallback onRecord;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final waiting = bill.status == 'pending_confirmation';
    final proof = bill.proofPath;
    final method = bill.method;
    final note = bill.remarks;
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Room ${bill.roomNumber}: ${bill.tenantName}',
                  style: theme.textTheme.titleMedium,
                ),
              ),
              StatusChip(bill.displayStatus),
            ],
          ),
          const SizedBox(height: 8),
          InfoRow('Bill for', monthLabel(bill.period)),
          InfoRow('Due date', formatDate(bill.dueDate)),
          InfoRow('Amount due', peso(bill.amountDue)),
          InfoRow('Paid so far', peso(bill.amountPaid)),
          InfoRow('Balance', peso(bill.balance)),
          if (method != null) InfoRow('Paid by', method),
          if (bill.paidAt != null) InfoRow('Paid on', formatDate(bill.paidAt)),
          if (note != null) InfoRow('Note', note),
          if (proof != null) ...[
            const SizedBox(height: 8),
            Text('Receipt photo (tap to enlarge)', style: theme.textTheme.bodySmall),
            const SizedBox(height: 4),
            NetworkPhoto(proof, size: 130),
          ],
          if (bill.status != 'paid') ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (waiting) ...[
                  FilledButton.icon(
                    onPressed: onConfirm,
                    icon: const Icon(Icons.check),
                    label: const Text('Confirm receipt'),
                  ),
                  OutlinedButton.icon(
                    onPressed: onReject,
                    icon: const Icon(Icons.close),
                    label: const Text('Reject'),
                  ),
                ],
                OutlinedButton.icon(
                  onPressed: onRecord,
                  icon: const Icon(Icons.payments_outlined),
                  label: const Text('Record payment'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
