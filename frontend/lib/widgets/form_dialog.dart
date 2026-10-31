import 'package:flutter/material.dart';

import '../api/api_client.dart';
import 'common.dart';

enum FieldKind { text, number, multiline, password, date, choice, toggle }

/// Describes one input of a [showFormDialog] form.
class FieldSpec {
  const FieldSpec(
    this.key,
    this.label, {
    this.kind = FieldKind.text,
    this.initial = '',
    this.required = false,
    this.options = const <String>[],
    this.hint,
    this.maxLength,
    this.validator,
  });

  /// The name under which the value is given to `onSubmit`.
  final String key;
  final String label;
  final FieldKind kind;

  /// Starting value. For a toggle use "true" or "false".
  final String initial;
  final bool required;

  /// The choices of a [FieldKind.choice] field.
  final List<String> options;
  final String? hint;
  final int? maxLength;

  /// Return an error message, or null when the value is fine.
  final String? Function(String value)? validator;
}

/// Shows a form in a pop-up. [onSubmit] receives the values by field key and
/// returns the message to show on success; it may throw [ApiException] to show
/// an error inside the form. Returns that message, or null when cancelled.
Future<String?> showFormDialog(
  BuildContext context, {
  required String title,
  required List<FieldSpec> fields,
  required Future<String> Function(Map<String, String> values) onSubmit,
  String? intro,
  String submitLabel = 'Save',
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _FormDialog(
      title: title,
      intro: intro,
      fields: fields,
      onSubmit: onSubmit,
      submitLabel: submitLabel,
    ),
  );
}

/// Asks "are you sure?". Returns true only when the person confirms.
Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Runs one action (usually a PATCH), shows its message or error in a
/// snack bar, and then reloads the page.
Future<void> runAction(
  BuildContext context,
  Future<String> Function() action,
  Future<void> Function() refresh,
) async {
  try {
    final message = await action();
    if (context.mounted) showSnack(context, message);
    await refresh();
  } catch (e) {
    if (context.mounted) showSnack(context, errorText(e));
  }
}

/// Waits for a pop-up that returns a success message, shows it, and reloads
/// the page. Does nothing when the pop-up was cancelled.
Future<void> afterDialog(
  BuildContext context,
  Future<String?> dialog,
  Future<void> Function() refresh,
) async {
  final message = await dialog;
  if (message == null) return;
  if (context.mounted) showSnack(context, message);
  await refresh();
}

/// "2026-10-05" for a date picked in the calendar.
String dateValue(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

class _FormDialog extends StatefulWidget {
  const _FormDialog({
    required this.title,
    required this.fields,
    required this.onSubmit,
    required this.submitLabel,
    this.intro,
  });

  final String title;
  final String? intro;
  final List<FieldSpec> fields;
  final Future<String> Function(Map<String, String> values) onSubmit;
  final String submitLabel;

  @override
  State<_FormDialog> createState() => _FormDialogState();
}

class _FormDialogState extends State<_FormDialog> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, String> _choices = {};
  final Map<String, bool> _toggles = {};
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    for (final field in widget.fields) {
      switch (field.kind) {
        case FieldKind.choice:
          _choices[field.key] = field.initial.isNotEmpty
              ? field.initial
              : (field.options.isEmpty ? '' : field.options.first);
        case FieldKind.toggle:
          _toggles[field.key] = field.initial == 'true';
        default:
          _controllers[field.key] = TextEditingController(text: field.initial);
      }
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate(FieldSpec field) async {
    final controller = _controllers[field.key];
    if (controller == null) return;
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(controller.text) ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => controller.text = dateValue(picked));
    }
  }

  String? _validate(FieldSpec field, String? raw) {
    final value = (raw ?? '').trim();
    if (field.required && value.isEmpty) return 'Required';
    if (value.isEmpty) return null;
    if (field.kind == FieldKind.number) {
      final number = double.tryParse(value);
      if (number == null || number < 0) return 'Enter a number';
    }
    final custom = field.validator;
    return custom == null ? null : custom(value);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final values = <String, String>{};
    for (final field in widget.fields) {
      switch (field.kind) {
        case FieldKind.choice:
          values[field.key] = _choices[field.key] ?? '';
        case FieldKind.toggle:
          values[field.key] = '${_toggles[field.key] ?? false}';
        case FieldKind.password:
          values[field.key] = _controllers[field.key]?.text ?? '';
        default:
          values[field.key] = (_controllers[field.key]?.text ?? '').trim();
      }
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final message = await widget.onSubmit(values);
      if (!mounted) return;
      Navigator.of(context).pop(message);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _busy = false;
        });
      }
    }
  }

  Widget _buildField(FieldSpec field) {
    final theme = Theme.of(context);
    switch (field.kind) {
      case FieldKind.choice:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(field.label, style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final option in field.options)
                  ChoiceChip(
                    label: Text(option),
                    selected: _choices[field.key] == option,
                    onSelected: _busy ? null : (_) => setState(() => _choices[field.key] = option),
                  ),
              ],
            ),
          ],
        );
      case FieldKind.toggle:
        return SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(field.label),
          value: _toggles[field.key] ?? false,
          onChanged: _busy ? null : (value) => setState(() => _toggles[field.key] = value),
        );
      case FieldKind.date:
        final controller = _controllers[field.key]!;
        return TextFormField(
          controller: controller,
          readOnly: true,
          onTap: _busy ? null : () => _pickDate(field),
          decoration: InputDecoration(
            labelText: field.label,
            hintText: field.hint ?? 'Tap to pick a date',
            border: const OutlineInputBorder(),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!field.required && controller.text.isNotEmpty)
                  IconButton(
                    tooltip: 'Clear',
                    icon: const Icon(Icons.clear),
                    onPressed: _busy ? null : () => setState(() => controller.clear()),
                  ),
                IconButton(
                  tooltip: 'Pick a date',
                  icon: const Icon(Icons.calendar_today_outlined),
                  onPressed: _busy ? null : () => _pickDate(field),
                ),
              ],
            ),
          ),
          validator: (value) => _validate(field, value),
        );
      default:
        final multiline = field.kind == FieldKind.multiline;
        return TextFormField(
          controller: _controllers[field.key],
          obscureText: field.kind == FieldKind.password,
          keyboardType: field.kind == FieldKind.number
              ? const TextInputType.numberWithOptions(decimal: true)
              : (multiline ? TextInputType.multiline : TextInputType.text),
          minLines: multiline ? 3 : 1,
          maxLines: multiline ? 6 : 1,
          maxLength: field.maxLength,
          enabled: !_busy,
          decoration: InputDecoration(
            labelText: field.label,
            hintText: field.hint,
            alignLabelWithHint: multiline,
            border: const OutlineInputBorder(),
          ),
          validator: (value) => _validate(field, value),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.intro != null) ...[
                  Text(widget.intro!),
                  const SizedBox(height: 12),
                ],
                for (var i = 0; i < widget.fields.length; i++) ...[
                  if (i > 0) const SizedBox(height: 12),
                  _buildField(widget.fields[i]),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
                ],
              ],
            ),
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
              : Text(widget.submitLabel),
        ),
      ],
    );
  }
}
