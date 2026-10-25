import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../app_services.dart';
import '../../theme.dart';
import '../../utils/format.dart';
import '../../utils/options.dart';
import '../../utils/photo_picker.dart';
import '../../widgets/photo_widgets.dart';

/// The form a tenant fills in to report a problem in their room.
/// Closes with a success message when the report was sent.
class ReportFormScreen extends StatefulWidget {
  const ReportFormScreen({super.key});

  @override
  State<ReportFormScreen> createState() => _ReportFormScreenState();
}

class _ReportFormScreenState extends State<ReportFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _description = TextEditingController();
  String _category = 'other';
  String _urgency = 'medium';
  PickedPhoto? _photo;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final photo = _photo;
      final text = _description.text.trim();
      if (photo == null) {
        await AppServices.api.post('/api/maintenance', body: {
          'category': _category,
          'urgency': _urgency,
          'description': text,
        });
      } else {
        await AppServices.api.postMultipart(
          '/api/maintenance',
          fields: {
            'category': _category,
            'urgency': _urgency,
            'description': text,
          },
          fileField: 'photo',
          bytes: photo.bytes,
          filename: photo.name,
          contentType: photo.contentType,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop('Report sent. The landlord has been notified.');
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
    final theme = Theme.of(context);
    return Scaffold(
      appBar: brandAppBar('New maintenance report'),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('What kind of problem is it?', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      for (final category in maintenanceCategories)
                        ChoiceChip(
                          avatar: Icon(categoryIcon(category), size: 18),
                          label: Text(titleCase(category)),
                          selected: _category == category,
                          onSelected: _busy ? null : (_) => setState(() => _category = category),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text('How urgent is it?', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 8),
                  SegmentedButton<String>(
                    segments: [
                      for (final level in urgencyLevels)
                        ButtonSegment<String>(value: level, label: Text(titleCase(level))),
                    ],
                    selected: {_urgency},
                    onSelectionChanged: _busy
                        ? null
                        : (selection) => setState(() => _urgency = selection.first),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'High: danger, flooding, or no water or electricity. '
                    'Medium: something is broken but it is safe. Low: a small issue.',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _description,
                    minLines: 4,
                    maxLines: 6,
                    maxLength: 1000,
                    decoration: const InputDecoration(
                      labelText: 'Describe the problem',
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Please describe the problem' : null,
                  ),
                  const SizedBox(height: 12),
                  PhotoField(
                    label: 'Photo (optional)',
                    photo: _photo,
                    onChanged: (value) => setState(() => _photo = value),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: _busy
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Send report'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
