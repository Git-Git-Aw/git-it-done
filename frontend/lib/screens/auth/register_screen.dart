import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../app_services.dart';
import '../../theme.dart';
import '../../utils/format.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _contact = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  String? _error;
  String? _doneMessage;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _contact.dispose();
    _password.dispose();
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
      final message = await AppServices.auth.register(
        fullName: _name.text,
        email: _email.text,
        password: _password.text,
        contactNumber: _contact.text,
      );
      if (mounted) setState(() => _doneMessage = message);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: brandAppBar('Create tenant account'),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: _doneMessage != null ? _buildDone(theme) : _buildForm(theme),
          ),
        ),
      ),
    );
  }

  Widget _buildDone(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(Icons.check_circle_outline, size: 64, color: theme.colorScheme.primary),
        const SizedBox(height: 12),
        Text(_doneMessage!, textAlign: TextAlign.center),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Back to login'),
        ),
      ],
    );
  }

  Widget _buildForm(ThemeData theme) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'The landlord must approve your account before you can log in.',
            style: TextStyle(color: theme.hintColor),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _name,
            decoration: fieldDecoration('Full name', icon: Icons.person_outline),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter your full name' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: fieldDecoration('Email', icon: Icons.email_outlined),
            validator: (v) => isValidEmail(v ?? '') ? null : 'Enter a valid email',
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _contact,
            keyboardType: TextInputType.phone,
            decoration: fieldDecoration('Contact number (optional)', icon: Icons.phone_outlined),
            validator: (v) => (v != null && v.trim().length > 20) ? 'At most 20 characters' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _password,
            obscureText: true,
            decoration: fieldDecoration('Password (at least 8 characters)', icon: Icons.lock_outline),
            validator: (v) => (v == null || v.length < 8) ? 'Use at least 8 characters' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _confirm,
            obscureText: true,
            decoration: fieldDecoration('Confirm password', icon: Icons.lock_outline),
            validator: (v) => v == _password.text ? null : 'Passwords do not match',
            onFieldSubmitted: (_) => _submit(),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: _busy
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Register'),
          ),
        ],
      ),
    );
  }
}
