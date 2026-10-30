import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../app_services.dart';
import '../../config.dart';
import '../../models/models.dart';
import '../../utils/format.dart';
import '../../widgets/common.dart';

/// Account details, change password, offline data, and log out.
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key, required this.user});

  final AppUser user;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _syncing = false;

  Future<void> _changePassword() async {
    final message = await showDialog<String>(
      context: context,
      builder: (_) => const _ChangePasswordDialog(),
    );
    if (message != null && mounted) {
      showSnack(context, message);
    }
  }

  Future<void> _syncNow() async {
    final sync = AppServices.sync;
    if (sync == null) return;
    setState(() => _syncing = true);
    String message;
    try {
      final result = await sync.syncNow(isLandlord: widget.user.isLandlord);
      message = result.changed == 0
          ? 'Everything is up to date.'
          : 'Synced. ${result.changed} record(s) updated from the server.';
    } catch (e) {
      message = errorText(e);
    }
    if (!mounted) return;
    setState(() => _syncing = false);
    showSnack(context, message);
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final sync = AppServices.sync;
    return PlainPage(
      title: 'My profile',
      children: [
        SectionCard(
          title: 'Account',
          child: Column(
            children: [
              InfoRow('Name', user.fullName),
              InfoRow('Email', user.email),
              InfoRow('Role', user.isLandlord ? 'Landlord' : 'Tenant'),
              InfoRow('Contact number', user.contactNumber ?? '-'),
              InfoRow('Account status', '', child: StatusChip(user.status == 'active' ? 'paid' : user.status, label: titleCase(user.status))),
            ],
          ),
        ),
        SectionCard(
          title: 'Security',
          child: Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: _changePassword,
              icon: const Icon(Icons.lock_reset),
              label: const Text('Change password'),
            ),
          ),
        ),
        SectionCard(
          title: 'Offline data',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InfoRow(
                'Last synced',
                sync?.lastSyncText() ?? 'Not available on this device',
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: (sync == null || _syncing) ? null : _syncNow,
                icon: _syncing
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.sync),
                label: const Text('Sync now'),
              ),
            ],
          ),
        ),
        SectionCard(
          title: 'Connection',
          child: InfoRow('Server', AppConfig.apiBaseUrl),
        ),
        const SizedBox(height: 4),
        FilledButton.icon(
          onPressed: () => AppServices.auth.logout(),
          icon: const Icon(Icons.logout),
          label: const Text('Log out'),
        ),
      ],
    );
  }
}

class _ChangePasswordDialog extends StatefulWidget {
  const _ChangePasswordDialog();

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _newPass = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _newPass.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final message = await AppServices.auth.changePassword(_current.text, _newPass.text);
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

  InputDecoration _decoration(String label) {
    return InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Change password'),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _current,
                  obscureText: true,
                  decoration: _decoration('Current password'),
                  validator: (v) => (v == null || v.isEmpty) ? 'Enter your current password' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _newPass,
                  obscureText: true,
                  decoration: _decoration('New password (at least 8 characters)'),
                  validator: (v) => (v == null || v.length < 8) ? 'Use at least 8 characters' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _confirm,
                  obscureText: true,
                  decoration: _decoration('Confirm new password'),
                  validator: (v) => v == _newPass.text ? null : 'Passwords do not match',
                  onFieldSubmitted: (_) => _submit(),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
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
              : const Text('Save'),
        ),
      ],
    );
  }
}
