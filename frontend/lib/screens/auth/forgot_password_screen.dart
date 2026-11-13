import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../app_services.dart';
import '../../theme.dart';
import '../../utils/format.dart';

/// Two steps on one page: ask for a reset token, then set a new password.
/// Email delivery is out of scope, so in development the server returns the
/// token and it is filled in automatically.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailKey = GlobalKey<FormState>();
  final _resetKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _token = TextEditingController();
  final _newPassword = TextEditingController();
  bool _busy = false;
  String? _error;
  String? _info;
  bool _done = false;

  @override
  void dispose() {
    _email.dispose();
    _token.dispose();
    _newPassword.dispose();
    super.dispose();
  }

  Future<void> _requestToken() async {
    if (!_emailKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    try {
      final data = await AppServices.auth.forgotPassword(_email.text);
      final token = data['resetToken'];
      if (!mounted) return;
      setState(() {
        if (token is String) {
          _token.text = token;
          _info = 'A reset token was created and filled in below. Enter a new password.';
        } else {
          _info = 'If the account exists, a reset token was created. '
              'Email delivery is not part of this project, so ask the landlord for the token.';
        }
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reset() async {
    if (!_resetKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    try {
      final message = await AppServices.auth.resetPassword(_token.text, _newPassword.text);
      if (mounted) {
        setState(() {
          _done = true;
          _info = message;
        });
      }
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
      appBar: brandAppBar('Forgot password'),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: _done
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Icon(Icons.check_circle_outline, size: 64, color: theme.colorScheme.primary),
                      const SizedBox(height: 12),
                      Text(_info ?? 'Password updated.', textAlign: TextAlign.center),
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Back to login'),
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Step 1: get a reset token', style: theme.textTheme.titleMedium),
                      const SizedBox(height: 12),
                      Form(
                        key: _emailKey,
                        child: TextFormField(
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          decoration: fieldDecoration('Email', icon: Icons.email_outlined),
                          validator: (v) => isValidEmail(v ?? '') ? null : 'Enter a valid email',
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: _busy ? null : _requestToken,
                        child: const Text('Get reset token'),
                      ),
                      const Divider(height: 40),
                      Text('Step 2: set a new password', style: theme.textTheme.titleMedium),
                      const SizedBox(height: 12),
                      Form(
                        key: _resetKey,
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _token,
                              decoration: fieldDecoration('Reset token', icon: Icons.vpn_key_outlined),
                              validator: (v) =>
                                  (v == null || v.trim().isEmpty) ? 'Enter the reset token' : null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _newPassword,
                              obscureText: true,
                              decoration: fieldDecoration(
                                'New password (at least 8 characters)',
                                icon: Icons.lock_outline,
                              ),
                              validator: (v) =>
                                  (v == null || v.length < 8) ? 'Use at least 8 characters' : null,
                              onFieldSubmitted: (_) => _reset(),
                            ),
                          ],
                        ),
                      ),
                      if (_info != null) ...[
                        const SizedBox(height: 12),
                        Text(_info!, style: TextStyle(color: theme.colorScheme.primary)),
                      ],
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
                      ],
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _busy ? null : _reset,
                        child: _busy
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Update password'),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
