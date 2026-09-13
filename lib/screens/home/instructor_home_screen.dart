import 'package:flutter/material.dart';

import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../auth/login_screen.dart';

class InstructorHomeScreen extends StatelessWidget {
  const InstructorHomeScreen({required this.user, super.key});

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
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Instructor space'),
      actions: [
        IconButton(
          onPressed: () => _logout(context),
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
          const Text('Your instructor dashboard is ready.'),
        ],
      ),
    ),
  );
}
