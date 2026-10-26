import 'package:flutter/material.dart';

import 'app_services.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home/app_shell.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppServices.init();
  runApp(const GitInsideApp());
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
