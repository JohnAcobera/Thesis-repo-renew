import 'package:flutter/material.dart';

import '../widgets/student_side_menu.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({required this.username, required this.email, super.key});

  final String username;
  final String email;

  @override
  Widget build(BuildContext context) => StudentScaffold(
    title: 'Profile',
    username: username,
    email: email,
    selectedMenu: StudentMenuItem.profile,
    onMenuSelected: (item) {
      if (item == StudentMenuItem.dashboard) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    },
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Your profile',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: const Color(0xFF3B2419),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'View your student account information.',
                  style: TextStyle(color: Color(0xFF765C4F)),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE8D7C2)),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x12000000),
                        blurRadius: 18,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Column(
                          children: [
                            const CircleAvatar(
                              radius: 40,
                              backgroundColor: Color(0xFFFFE5D5),
                              child: Icon(
                                Icons.account_circle,
                                size: 56,
                                color: Color(0xFFF4773C),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              username,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(
                                    color: const Color(0xFF3B2419),
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),
                      const Divider(color: Color(0xFFE8D7C2)),
                      const SizedBox(height: 16),
                      _ProfileDetail(
                        label: 'Full name',
                        value: username,
                        icon: Icons.person_outline,
                      ),
                      const SizedBox(height: 20),
                      _ProfileDetail(
                        label: 'Email address',
                        value: email,
                        icon: Icons.email_outlined,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _ProfileDetail extends StatelessWidget {
  const _ProfileDetail({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, color: const Color(0xFFF4773C)),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: Color(0xFF8A7A70))),
            const SizedBox(height: 4),
            SelectableText(
              value,
              style: const TextStyle(
                color: Color(0xFF3B2419),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}
