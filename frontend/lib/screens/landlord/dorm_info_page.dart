import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../app_services.dart';
import '../../models/models.dart';
import '../../theme.dart';
import '../../widgets/common.dart';

/// Landlord: the public information about the dorm. Visitors and the AI
/// chatbox read exactly this (rooms and prices come from the rooms list).
class DormInfoPage extends StatelessWidget {
  const DormInfoPage({super.key});

  Future<DormInfo> _load() async {
    final data = await AppServices.api.get('/api/dorm-info');
    return DormInfo.fromJson(asMap(data));
  }

  @override
  Widget build(BuildContext context) {
    return AsyncView<DormInfo>(
      load: _load,
      builder: (context, info, refresh) {
        return PageList(
          title: 'Dorm information',
          onRefresh: refresh,
          children: [
            const Text(
              'Visitors see this in the "Ask about the dorm" chat. Only write information you are happy to make public.',
            ),
            const SizedBox(height: 12),
            _DormInfoForm(info: info),
          ],
        );
      },
    );
  }
}

class _DormInfoForm extends StatefulWidget {
  const _DormInfoForm({required this.info});

  final DormInfo info;

  @override
  State<_DormInfoForm> createState() => _DormInfoFormState();
}

class _DormInfoFormState extends State<_DormInfoForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name = TextEditingController(text: widget.info.dormName);
  late final TextEditingController _address = TextEditingController(text: widget.info.address);
  late final TextEditingController _contact = TextEditingController(text: widget.info.contactNumber);
  late final TextEditingController _about = TextEditingController(text: widget.info.about);
  late final TextEditingController _rules = TextEditingController(text: widget.info.houseRules);
  late final TextEditingController _requirements = TextEditingController(text: widget.info.requirements);
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    _contact.dispose();
    _about.dispose();
    _rules.dispose();
    _requirements.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await AppServices.api.put('/api/dorm-info', body: {
        'dormName': _name.text.trim(),
        'address': _address.text.trim(),
        'contactNumber': _contact.text.trim(),
        'about': _about.text.trim(),
        'houseRules': _rules.text.trim(),
        'requirements': _requirements.text.trim(),
      });
      if (mounted) showSnack(context, 'Dorm information saved.');
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _field(TextEditingController controller, String label, {bool multiline = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        minLines: multiline ? 4 : 1,
        maxLines: multiline ? 10 : 1,
        keyboardType: multiline ? TextInputType.multiline : TextInputType.text,
        decoration: fieldDecoration(label),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _name,
              decoration: fieldDecoration('Dorm name'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter the dorm name' : null,
            ),
            const SizedBox(height: 12),
            _field(_address, 'Address'),
            _field(_contact, 'Contact number'),
            _field(_about, 'About the dorm', multiline: true),
            _field(_rules, 'House rules', multiline: true),
            _field(_requirements, 'Requirements to rent a room', multiline: true),
            FilledButton.icon(
              onPressed: _busy ? null : _save,
              icon: _busy
                  ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.save_outlined),
              label: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
