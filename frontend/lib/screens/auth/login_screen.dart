import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../app_services.dart';
import '../../theme.dart';
import '../../utils/format.dart';
import 'forgot_password_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _hidePassword = true;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AppServices.auth.login(_email.text, _password.text);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _fill(String email, String password) {
    _email.text = email;
    _password.text = password;
  }

  Widget _buildForm(ThemeData theme) {
    final notice = AppServices.auth.notice;
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Image.asset('assets/logo.png', height: 96),
          const SizedBox(height: 8),
          Text(
            'Git-Inside',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'Dormitory Tenant and Landlord Management System',
            textAlign: TextAlign.center,
            style: TextStyle(color: theme.hintColor),
          ),
          const SizedBox(height: 24),
          if (notice != null) ...[
            Text(notice, style: TextStyle(color: theme.colorScheme.primary)),
            const SizedBox(height: 12),
          ],
          TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: fieldDecoration('Email', icon: Icons.email_outlined),
            validator: (v) => isValidEmail(v ?? '') ? null : 'Enter a valid email',
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _password,
            obscureText: _hidePassword,
            decoration: fieldDecoration(
              'Password',
              icon: Icons.lock_outline,
              suffix: IconButton(
                tooltip: _hidePassword ? 'Show password' : 'Hide password',
                icon: Icon(_hidePassword ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setState(() => _hidePassword = !_hidePassword),
              ),
            ),
            validator: (v) => (v == null || v.isEmpty) ? 'Enter your password' : null,
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
                : const Text('Log in'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const ForgotPasswordScreen()),
            ),
            child: const Text('Forgot password?'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const RegisterScreen()),
            ),
            child: const Text('New tenant? Create an account'),
          ),
          if (kDebugMode) ...[
            const Divider(height: 32),
            Text(
              'Demo accounts (development only)',
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.hintColor),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  onPressed: () => _fill('landlord@gitinside.test', 'Landlord123!'),
                  child: const Text('Fill landlord'),
                ),
                TextButton(
                  onPressed: () => _fill('ana@gitinside.test', 'Tenant123!'),
                  child: const Text('Fill tenant'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(gradient: brandGradient),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: _buildForm(theme),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
