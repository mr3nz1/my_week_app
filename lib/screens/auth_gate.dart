import 'package:flutter/material.dart';

import '../backend/backend.dart';
import 'login_screen.dart';
import 'week_screen.dart';

/// Decides what the user sees: the login screen, or their week.
/// Logging in or out rebuilds it by itself: no Navigator needed.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key, required this.backend});

  final Backend backend;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final Stream<AppUser?> _users = widget.backend.auth.authStateChanges();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AppUser?>(
      stream: _users,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final user = snapshot.data;
        if (user == null) {
          return LoginScreen(backend: widget.backend);
        }
        return WeekScreen(
          key: ValueKey(user.uid),
          backend: widget.backend,
          user: user,
        );
      },
    );
  }
}
