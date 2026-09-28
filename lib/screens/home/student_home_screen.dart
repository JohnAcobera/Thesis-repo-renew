import 'package:flutter/material.dart';

import '../../models/user_model.dart';
import '../import_screen.dart';
import '../../widgets/student_nav_bar.dart';

class StudentHomeScreen extends StatelessWidget {
  const StudentHomeScreen({required this.user, super.key});

  final UserModel user;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: StudentNavBar(
      username: user.fullName,
      email: user.email,
      onImportSelected: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) =>
                ImportScreen(username: user.fullName, email: user.email),
          ),
        );
      },
    ),
    body: LayoutBuilder(
      builder: (context, viewport) {
        final isWide = viewport.maxWidth >= 800;
        final dashboardHeight = (viewport.maxHeight - 48)
            .clamp(420.0, 720.0)
            .toDouble();

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1280),
              child: isWide
                  ? SizedBox(
                      height: dashboardHeight,
                      child: _WideStudentDashboard(user: user),
                    )
                  : _StackedStudentDashboard(user: user),
            ),
          ),
        );
      },
    ),
  );
}

class _WideStudentDashboard extends StatelessWidget {
  const _WideStudentDashboard({required this.user});

  final UserModel user;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Expanded(
        flex: 6,
        child: Column(
          children: [
            Expanded(
              flex: 6,
              child: _DashboardPanel(
                icon: Icons.waving_hand_outlined,
                title: 'Hi, ${user.fullName}!',
                description: 'Your learning dashboard is ready.',
                titleSize: 30,
              ),
            ),
            const SizedBox(height: 20),
            const Expanded(
              flex: 4,
              child: _DashboardPanel(
                icon: Icons.auto_stories_outlined,
                title: 'Learning overview',
                description: 'Your learning progress will appear here.',
              ),
            ),
          ],
        ),
      ),
      const SizedBox(width: 20),
      const Expanded(
        flex: 4,
        child: _DashboardPanel(
          icon: Icons.history,
          title: 'Recent activity',
          description: 'Your recent learning activity will appear here.',
        ),
      ),
    ],
  );
}

class _StackedStudentDashboard extends StatelessWidget {
  const _StackedStudentDashboard({required this.user});

  final UserModel user;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      _DashboardPanel(
        icon: Icons.waving_hand_outlined,
        title: 'Hi, ${user.fullName}!',
        description: 'Your learning dashboard is ready.',
        titleSize: 28,
      ),
      const SizedBox(height: 16),
      const _DashboardPanel(
        icon: Icons.auto_stories_outlined,
        title: 'Learning overview',
        description: 'Your learning progress will appear here.',
      ),
      const SizedBox(height: 16),
      const _DashboardPanel(
        icon: Icons.history,
        title: 'Recent activity',
        description: 'Your recent learning activity will appear here.',
      ),
    ],
  );
}

class _DashboardPanel extends StatelessWidget {
  const _DashboardPanel({
    required this.icon,
    required this.title,
    required this.description,
    this.titleSize = 22,
  });

  final IconData icon;
  final String title;
  final String description;
  final double titleSize;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
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
        Icon(icon, color: const Color(0xFFF4773C), size: 28),
        const SizedBox(height: 16),
        Text(
          title,
          style: TextStyle(
            fontSize: titleSize,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF3B2419),
          ),
        ),
        const SizedBox(height: 10),
        Text(description),
      ],
    ),
  );
}
