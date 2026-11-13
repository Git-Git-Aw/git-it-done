import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../app_services.dart';
import '../../theme.dart';
import '../../utils/format.dart';
import '../chat/chat_screens.dart';
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

  /// The three real features shown on the brand panel (wide screens).
  static const List<(IconData, String, String)> _highlights = [
    (
      Icons.smart_toy_outlined,
      'AI Dorm Manager',
      'Ask questions and get help in one chat, for tenants, landlords and visitors.',
    ),
    (
      Icons.receipt_long_outlined,
      'Payments you can follow',
      'Upload a receipt photo, the landlord confirms it, and the status updates.',
    ),
    (
      Icons.build_circle_outlined,
      'Maintenance with urgency',
      'Report a problem with a photo and see its progress until it is resolved.',
    ),
  ];

  Widget _brandHeader({required bool compact}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        LogoTile(size: compact ? 64 : 84),
        SizedBox(height: compact ? 10 : 16),
        Text(
          'Git-Inside',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: compact ? 28 : 36,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Dormitory Tenant and Landlord Management System',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white70),
        ),
      ],
    );
  }

  Widget _brandPanel() {
    return Container(
      decoration: const BoxDecoration(gradient: brandGradient),
      child: Stack(
        children: [
          Positioned(
            right: -80,
            top: -80,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
          ),
          Positioned(
            left: -60,
            bottom: -90,
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.07),
              ),
            ),
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(40),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const LogoTile(size: 56),
                        const SizedBox(width: 14),
                        const Text(
                          'Git-Inside',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Run your dorm with less stress.',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 28),
                    for (final h in _highlights) ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(h.$1, color: Colors.white),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  h.$2,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  h.$3,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    height: 1.35,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm(ThemeData theme, {required bool showTitle}) {
    final notice = AppServices.auth.notice;
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showTitle) ...[
            Text(
              'Welcome back',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: inkDark,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Log in to your Git-Inside account.',
              style: TextStyle(color: inkSoft),
            ),
            const SizedBox(height: 20),
          ],
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
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              backgroundColor: brandDeep,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(radiusM),
              ),
            ),
            onPressed: _busy ? null : _submit,
            child: _busy
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Log in'),
          ),
          const SizedBox(height: 4),
          Wrap(
            alignment: WrapAlignment.center,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const ForgotPasswordScreen(),
                  ),
                ),
                child: const Text('Forgot password?'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const RegisterScreen(),
                  ),
                ),
                child: const Text('New tenant? Create an account'),
              ),
            ],
          ),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(46),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(radiusM),
              ),
            ),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const VisitorChatScreen()),
            ),
            icon: const Icon(Icons.chat_bubble_outline),
            label: const Text('Ask about the dorm'),
          ),
          if (kDebugMode) ...[
            const SizedBox(height: 8),
            const Text(
              'Demo accounts (development only)',
              textAlign: TextAlign.center,
              style: TextStyle(color: inkSoft, fontSize: 12),
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
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Wide screen: brand panel on the left, form on the right.
          if (constraints.maxWidth >= 900) {
            return Row(
              children: [
                Expanded(flex: 5, child: _brandPanel()),
                Expanded(
                  flex: 4,
                  child: Container(
                    color: pageBackground,
                    child: Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(32),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 400),
                          child: _buildForm(theme, showTitle: true),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          }
          // Phone and small windows: one column. It scrolls only when the
          // screen is too short to show everything.
          return Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(gradient: brandGradient),
            child: SafeArea(
              child: LayoutBuilder(
                builder: (context, inner) => SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: inner.maxHeight > 32 ? inner.maxHeight - 32 : 0.0,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 440),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _brandHeader(compact: true),
                            const SizedBox(height: 18),
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(radiusL + 4),
                              ),
                              child: _buildForm(theme, showTitle: false),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
