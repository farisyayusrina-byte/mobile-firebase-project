import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'screens/auth/login_screen.dart';
import 'screens/main_shell.dart';
import 'services/auth_service.dart';
import 'services/messaging_service.dart';
import 'theme/app_theme.dart';

class SplitApp extends StatelessWidget {
  const SplitApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Split',
      theme: AppTheme.light,
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final _auth = AuthService();
  final _messaging = MessagingService();
  String? _messagingUserId;

  Future<void> _onUserSignedIn(User user) async {
    if (_messagingUserId == user.uid) return;
    _messagingUserId = user.uid;

    await _auth.syncUserProfile(user);
    await _messaging.initialize(userId: user.uid);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _auth.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          );
        }

        final user = snapshot.data;
        if (user == null) {
          _messagingUserId = null;
          return const LoginScreen();
        }

        _onUserSignedIn(user);
        return MainShell(user: user);
      },
    );
  }
}
