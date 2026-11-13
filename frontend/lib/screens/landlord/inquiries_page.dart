import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app_services.dart';
import '../../models/models.dart';
import '../../utils/format.dart';
import '../../widgets/common.dart';
import '../../widgets/form_dialog.dart';

/// Landlord: people who asked about the dorm through the visitor chat.
class InquiriesPage extends StatefulWidget {
  const InquiriesPage({super.key});

  @override
  State<InquiriesPage> createState() => _InquiriesPageState();
}

class _InquiriesPageState extends State<InquiriesPage> {
  /// all, new, or contacted
  String _status = 'all';

  Future<List<Inquiry>> _load() async {
    final data = await AppServices.api.get(
      '/api/inquiries',
      query: _status == 'all' ? null : {'status': _status},
    );
    return asList(data).map((e) => Inquiry.fromJson(asMap(e))).toList();
  }

  Future<void> _mark(BuildContext context, Inquiry inquiry, String status, Future<void> Function() refresh) {
    return runAction(context, () async {
      await AppServices.api.patch('/api/inquiries/${inquiry.id}', body: {'status': status});
      return status == 'contacted' ? 'Marked as contacted.' : 'Marked as new.';
    }, refresh);
  }

  Future<void> _copy(BuildContext context, String number) async {
    await Clipboard.setData(ClipboardData(text: number));
    if (context.mounted) showSnack(context, 'Number copied.');
  }

  @override
  Widget build(BuildContext context) {
    return AsyncView<List<Inquiry>>(
      key: ValueKey<String>(_status),
      load: _load,
      builder: (context, inquiries, refresh) {
        final theme = Theme.of(context);
        return PageList(
          title: 'Visitor inquiries',
          onRefresh: refresh,
          children: [
            FilterChips(
              selected: _status,
              onSelected: (value) => setState(() => _status = value),
              options: const {'all': 'All', 'new': 'New', 'contacted': 'Contacted'},
            ),
            const SizedBox(height: 12),
            if (inquiries.isEmpty)
              const EmptyState(
                icon: Icons.question_answer_outlined,
                message: 'No inquiries yet. Visitors can leave their name and number in the "Ask about the dorm" chat.',
              )
            else
              for (final inquiry in inquiries)
                SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text(inquiry.name, style: theme.textTheme.titleMedium)),
                          StatusChip(inquiry.status),
                        ],
                      ),
                      const SizedBox(height: 8),
                      InfoRow('Contact number', inquiry.contactNumber),
                      if (inquiry.message != null) InfoRow('Message', inquiry.message!),
                      InfoRow('Received', formatDateTime(inquiry.createdAt)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () => _copy(context, inquiry.contactNumber),
                            icon: const Icon(Icons.copy),
                            label: const Text('Copy number'),
                          ),
                          if (inquiry.status == 'new')
                            FilledButton.icon(
                              onPressed: () => _mark(context, inquiry, 'contacted', refresh),
                              icon: const Icon(Icons.check),
                              label: const Text('Mark contacted'),
                            )
                          else
                            OutlinedButton.icon(
                              onPressed: () => _mark(context, inquiry, 'new', refresh),
                              icon: const Icon(Icons.undo),
                              label: const Text('Mark as new'),
                            ),
                        ],
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
