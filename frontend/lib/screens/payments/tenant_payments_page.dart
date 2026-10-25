import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../app_services.dart';
import '../../models/models.dart';
import '../../utils/format.dart';
import '../../utils/options.dart';
import '../../utils/photo_picker.dart';
import '../../widgets/common.dart';
import '../../widgets/photo_widgets.dart';

/// A tenant's billing statements, payment history, and proof-of-payment upload.
class TenantPaymentsPage extends StatelessWidget {
  const TenantPaymentsPage({super.key});

  Future<List<Bill>> _load() async {
    final data = await AppServices.api.get('/api/payments/mine');
    return asList(data).map((e) => Bill.fromJson(asMap(e))).toList();
  }

  @override
  Widget build(BuildContext context) {
    return AsyncView<List<Bill>>(
      load: _load,
      builder: (context, bills, refresh) {
        final open = bills.where((b) => b.status != 'paid').toList()
          ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
        final paid = bills.where((b) => b.status == 'paid').toList();
        final total = open.fold<double>(0, (sum, b) => sum + b.balance);
        final theme = Theme.of(context);
        return PageList(
          title: 'Payments',
          onRefresh: refresh,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: MetricCard(
                label: 'Total balance',
                value: peso(total),
                color: total > 0 ? Colors.red.shade700 : Colors.green.shade700,
                footnote: open.isEmpty
                    ? 'You have no unpaid bills'
                    : '${open.length} bill${open.length == 1 ? '' : 's'} waiting',
              ),
            ),
            const SizedBox(height: 16),
            Text('Bills to pay', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            if (open.isEmpty)
              const SectionCard(
                child: Text('Nothing to pay right now. New bills appear here each month.'),
              )
            else
              for (final bill in open) _BillCard(bill: bill, onChanged: refresh),
            const SizedBox(height: 8),
            Text('Payment history', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            if (paid.isEmpty)
              const SectionCard(child: Text('No payments yet.'))
            else
              for (final bill in paid) _HistoryTile(bill),
          ],
        );
      },
    );
  }
}

class _BillCard extends StatelessWidget {
  const _BillCard({required this.bill, required this.onChanged});

  final Bill bill;
  final Future<void> Function() onChanged;

  Future<void> _openUpload(BuildContext context) async {
    final message = await showDialog<String>(
      context: context,
      builder: (_) => _ProofDialog(bill: bill),
    );
    if (message != null) {
      if (context.mounted) showSnack(context, message);
      await onChanged();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final waiting = bill.status == 'pending_confirmation';
    final proof = bill.proofPath;
    final note = bill.remarks;
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(monthLabel(bill.period), style: theme.textTheme.titleMedium),
              ),
              StatusChip(bill.displayStatus),
            ],
          ),
          const SizedBox(height: 8),
          InfoRow('Due date', formatDate(bill.dueDate)),
          InfoRow('Amount due', peso(bill.amountDue)),
          if (bill.amountPaid > 0) InfoRow('Paid so far', peso(bill.amountPaid)),
          InfoRow('Balance', peso(bill.balance)),
          if (note != null) InfoRow('Note', note),
          const SizedBox(height: 8),
          if (waiting) ...[
            const Text('Receipt uploaded. Waiting for the landlord to confirm your payment.'),
            if (proof != null) ...[
              const SizedBox(height: 8),
              NetworkPhoto(proof),
            ],
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => _openUpload(context),
              icon: const Icon(Icons.upload_file),
              label: const Text('Upload a different receipt'),
            ),
          ] else
            FilledButton.icon(
              onPressed: () => _openUpload(context),
              icon: const Icon(Icons.upload_file),
              label: const Text('Upload proof of payment'),
            ),
        ],
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile(this.bill);

  final Bill bill;

  @override
  Widget build(BuildContext context) {
    final when = formatDate(bill.paidAt ?? bill.dueDate);
    final method = bill.method;
    final subtitle = method == null ? 'Paid on $when' : 'Paid on $when via $method';
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(Icons.check_circle, color: Colors.green.shade700),
        title: Text(monthLabel(bill.period)),
        subtitle: Text(subtitle),
        trailing: Text(
          peso(bill.amountPaid),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

/// Pick a receipt photo and how you paid, then send it to the landlord.
class _ProofDialog extends StatefulWidget {
  const _ProofDialog({required this.bill});

  final Bill bill;

  @override
  State<_ProofDialog> createState() => _ProofDialogState();
}

class _ProofDialogState extends State<_ProofDialog> {
  final _remarks = TextEditingController();
  PickedPhoto? _photo;
  String _method = paymentMethods.first;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _remarks.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final photo = _photo;
    if (photo == null) {
      setState(() => _error = 'Choose or take a photo of your receipt first.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final note = _remarks.text.trim();
      await AppServices.api.postMultipart(
        '/api/payments/${widget.bill.id}/proof',
        fields: {
          'method': _method,
          if (note.isNotEmpty) 'remarks': note,
        },
        fileField: 'proof',
        bytes: photo.bytes,
        filename: photo.name,
        contentType: photo.contentType,
      );
      if (!mounted) return;
      Navigator.of(context).pop('Receipt uploaded. The landlord will confirm your payment.');
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bill = widget.bill;
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text('Proof of payment for ${monthLabel(bill.period)}'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Balance: ${peso(bill.balance)}'),
              const SizedBox(height: 12),
              Text('How did you pay?', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final method in paymentMethods)
                    ChoiceChip(
                      label: Text(method),
                      selected: _method == method,
                      onSelected: _busy ? null : (_) => setState(() => _method = method),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              PhotoField(
                label: 'Photo of your receipt',
                photo: _photo,
                onChanged: (value) => setState(() => _photo = value),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _remarks,
                maxLength: 100,
                decoration: const InputDecoration(
                  labelText: 'Note for the landlord (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Send receipt'),
        ),
      ],
    );
  }
}
