import 'package:flutter/material.dart';

import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../auth/login_screen.dart';

class StudentHomeScreen extends StatelessWidget {
  const StudentHomeScreen({required this.user, super.key});

  final UserModel user;

  Future<void> _logout(BuildContext context) async {
    await AuthService().logout();
    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) => _HomeScaffold(
    user: user,
    title: 'Student space',
    message: 'Your learning dashboard is ready.',
    onLogout: () => _logout(context),
  );
}

class _HomeScaffold extends StatelessWidget {
  const _HomeScaffold({
    required this.user,
    required this.title,
    required this.message,
    required this.onLogout,
  });

  final UserModel user;
  final String title;
  final String message;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(title),
      actions: [
        IconButton(
          onPressed: onLogout,
          icon: const Icon(Icons.logout),
          tooltip: 'Log out',
        ),
      ],
    ),
    body: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Hi, ${user.fullName}!',
            style: const TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              color: Color(0xFF3B2419),
            ),
          ),
          const SizedBox(height: 12),
          Text(message),
        ],
      ),
    ),
  );
}
