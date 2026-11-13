import 'package:flutter/material.dart';

import 'app_services.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home/app_shell.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // The window opens at once with a loading screen; the saved data and the
  // login are prepared behind it.
  runApp(const AppBootstrap());
}

/// Prepares the app (saved data, login) and shows a loading screen meanwhile.
class AppBootstrap extends StatefulWidget {
  const AppBootstrap({super.key});

  @override
  State<AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<AppBootstrap> {
  bool _ready = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    if (_failed) setState(() => _failed = false);
    try {
      await AppServices.init();
      if (!mounted) return;
      setState(() => _ready = true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_ready) return const GitInsideApp();
    return MaterialApp(
      title: 'Git-Inside',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: _StartupScreen(failed: _failed, onRetry: _start),
    );
  }
}

/// The first screen: logo and a spinner (or a Try again button if the app
/// could not start).
class _StartupScreen extends StatelessWidget {
  const _StartupScreen({required this.failed, required this.onRetry});

  final bool failed;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: brandGradient),
        width: double.infinity,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset('assets/logo.png', height: 96),
              const SizedBox(height: 16),
              const Text(
                'Git-Inside',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 24),
              if (failed) ...[
                const Text(
                  'The app could not start.',
                  style: TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: onRetry,
                  child: const Text('Try again'),
                ),
              ] else
                const CircularProgressIndicator(color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}

class GitInsideApp extends StatelessWidget {
  const GitInsideApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Git-Inside',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: const AuthGate(),
    );
  }
}

/// Shows the login screen or the signed-in app, depending on the login state.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  @override
  void initState() {
    super.initState();
    AppServices.auth.restore();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppServices.auth,
      builder: (context, _) {
        final auth = AppServices.auth;
        if (auth.restoring) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final user = auth.user;
        if (user == null) {
          return const LoginScreen();
        }
        return AppShell(key: ValueKey(user.id), user: user);
      },
    );
  }
}

