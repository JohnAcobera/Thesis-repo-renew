import 'package:flutter/material.dart';

import '../../models/admin_overview.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/admin_overview_service.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  static const _sessionStorageKey = 'admin_session_token';
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  late final _service = AuthService(sessionStorageKey: _sessionStorageKey);
  UserModel? _admin;
  bool _isCheckingSession = true;
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    try {
      final user = await _service.restoreSession();
      if (user?.role == 'admin') {
        _admin = user;
      } else if (user != null) {
        await _service.logout();
      }
    } on Exception {
      _error = 'Unable to restore your session. Please sign in again.';
    } finally {
      if (mounted) setState(() => _isCheckingSession = false);
    }
  }

  Future<void> _signIn() async {
    if (_isLoading || !_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final result = await _service.login(
        email: _emailController.text,
        password: _passwordController.text,
      );
      if (result.user.role != 'admin') {
        await _service.logout();
        if (mounted) {
          setState(() => _error = 'This account does not have admin access.');
        }
      } else if (mounted) {
        setState(() => _admin = result.user);
      }
    } on AuthException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signOut() async {
    try {
      await _service.logout();
    } on Exception {
      if (mounted) {
        setState(() => _error = 'Unable to sign out. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _admin = null);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingSession) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_admin != null) {
      return _AdminHome(onSignOut: _signOut);
    }

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _AdminBrand(),
                    const SizedBox(height: 34),
                    const Text('Admin sign in', style: _headingStyle),
                    const SizedBox(height: 8),
                    const Text('Sign in with your administrator account.'),
                    const SizedBox(height: 28),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(labelText: 'Email'),
                      validator: _validateEmail,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) {
                        if (!_isLoading) _signIn();
                      },
                      decoration: InputDecoration(
                        labelText: 'Password',
                        suffixIcon: IconButton(
                          onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                      validator: (value) => value == null || value.isEmpty
                          ? 'Enter your password.'
                          : null,
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      _ErrorMessage(text: _error!),
                    ],
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _isLoading ? null : _signIn,
                      style: _buttonStyle,
                      child: _isLoading
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Log in'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AdminBrand extends StatelessWidget {
  const _AdminBrand();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFFF4773C),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.auto_stories_rounded, color: Colors.white),
        ),
        const SizedBox(width: 12),
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'QuizForge',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
            ),
            Text(
              'ADMINISTRATION',
              style: TextStyle(
                color: Color(0xFF725F53),
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _AdminHome extends StatefulWidget {
  const _AdminHome({required this.onSignOut});

  final VoidCallback onSignOut;

  @override
  State<_AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<_AdminHome> {
  final _overviewService = AdminOverviewService();
  AdminOverview? _overview;
  String? _error;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadOverview();
  }

  Future<void> _loadOverview() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final overview = await _overviewService.load();
      if (mounted) setState(() => _overview = overview);
    } on AdminOverviewException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _AdminDashboardHeader(
              isLoading: _isLoading,
              onRefresh: _loadOverview,
              onSignOut: widget.onSignOut,
            ),
            Expanded(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1180),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(28, 28, 28, 32),
                    children: [
                      Text(
                        'Overview',
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(
                              color: const Color(0xFF3B2419),
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Current school totals and recent community activity.',
                        style: const TextStyle(color: Color(0xFF725F53)),
                      ),
                      const SizedBox(height: 24),
                      if (_error case final error?)
                        _OverviewError(message: error, onRetry: _loadOverview)
                      else if (_isLoading && _overview == null)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 72),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (_overview case final overview?) ...[
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final columns = constraints.maxWidth >= 900
                                ? 3
                                : constraints.maxWidth >= 560
                                ? 2
                                : 1;
                            const spacing = 16.0;
                            final cardWidth =
                                (constraints.maxWidth -
                                    spacing * (columns - 1)) /
                                columns;
                            return Wrap(
                              spacing: spacing,
                              runSpacing: spacing,
                              children: [
                                SizedBox(
                                  width: cardWidth,
                                  child: _SummaryCard(
                                    label: 'Students',
                                    value: overview.studentCount,
                                    icon: Icons.school_outlined,
                                    color: const Color(0xFF4B6F9C),
                                  ),
                                ),
                                SizedBox(
                                  width: cardWidth,
                                  child: _SummaryCard(
                                    label: 'Instructors',
                                    value: overview.instructorCount,
                                    icon: Icons.co_present_outlined,
                                    color: const Color(0xFF7A5AA6),
                                  ),
                                ),
                                SizedBox(
                                  width: cardWidth,
                                  child: _SummaryCard(
                                    label: 'Classrooms',
                                    value: overview.classroomCount,
                                    icon: Icons.meeting_room_outlined,
                                    color: const Color(0xFF42836D),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 32),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Recent updates',
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(
                                      color: const Color(0xFF3B2419),
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                            ),
                            if (_isLoading)
                              const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _RecentUpdatesCard(updates: overview.recentUpdates),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminDashboardHeader extends StatelessWidget {
  const _AdminDashboardHeader({
    required this.isLoading,
    required this.onRefresh,
    required this.onSignOut,
  });

  final bool isLoading;
  final VoidCallback onRefresh;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(bottom: BorderSide(color: Color(0xFFE8D7C2))),
      ),
      child: Align(
        alignment: Alignment.center,
        child: SizedBox(
          width: double.infinity,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final horizontalPadding = constraints.maxWidth < 600
                  ? 20.0
                  : 48.0;
              return Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding,
                  vertical: 12,
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 520;
                    final brand = Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF7434),
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: const Icon(
                            Icons.auto_stories_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 13),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'QuizForge',
                              style: TextStyle(
                                color: Color(0xFF3B2419),
                                fontSize: 18,
                                height: 1.2,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            SizedBox(height: 3),
                            Text(
                              'SCHOOL ADMINISTRATION',
                              style: TextStyle(
                                color: Color(0xFF8A796D),
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.1,
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                    final actions = Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton.outlined(
                          tooltip: 'Refresh overview',
                          onPressed: isLoading ? null : onRefresh,
                          style: IconButton.styleFrom(
                            foregroundColor: const Color(0xFF725F53),
                            side: const BorderSide(color: Color(0xFFE8D7C2)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.refresh_rounded),
                        ),
                        const SizedBox(width: 8),
                        if (compact)
                          IconButton(
                            tooltip: 'Sign out',
                            onPressed: onSignOut,
                            color: const Color(0xFF725F53),
                            icon: const Icon(Icons.logout_rounded),
                          )
                        else
                          TextButton.icon(
                            onPressed: onSignOut,
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFF725F53),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                            ),
                            icon: const Icon(Icons.logout_rounded, size: 18),
                            label: const Text('Sign out'),
                          ),
                      ],
                    );

                    return Row(
                      children: [
                        Expanded(child: brand),
                        actions,
                      ],
                    );
                  },
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final int value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE8D7C2)),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF725F53),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$value',
                  style: const TextStyle(
                    color: Color(0xFF3B2419),
                    fontSize: 28,
                    height: 1,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentUpdatesCard extends StatelessWidget {
  const _RecentUpdatesCard({required this.updates});

  final List<AdminRecentUpdate> updates;

  @override
  Widget build(BuildContext context) {
    if (updates.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
        decoration: _cardDecoration,
        child: const Center(
          child: Text(
            'No recent updates yet.',
            style: TextStyle(color: Color(0xFF725F53)),
          ),
        ),
      );
    }

    return Container(
      decoration: _cardDecoration,
      child: Column(
        children: [
          for (var index = 0; index < updates.length; index++) ...[
            _UpdateRow(update: updates[index]),
            if (index < updates.length - 1)
              const Divider(height: 1, indent: 72, endIndent: 20),
          ],
        ],
      ),
    );
  }
}

class _UpdateRow extends StatelessWidget {
  const _UpdateRow({required this.update});

  final AdminRecentUpdate update;

  @override
  Widget build(BuildContext context) {
    final icon = switch (update.type) {
      'classroom' => Icons.meeting_room_outlined,
      'enrollment' => Icons.person_add_alt_1_outlined,
      'activity' => Icons.assignment_outlined,
      _ => Icons.person_outline_rounded,
    };
    final date = update.createdAt.toLocal();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF1DF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: const Color(0xFFFF7434), size: 21),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  update.title,
                  style: const TextStyle(
                    color: Color(0xFF3B2419),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (update.description.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    update.description,
                    style: const TextStyle(color: Color(0xFF725F53)),
                  ),
                ],
                const SizedBox(height: 5),
                Text(
                  _formatUpdateDate(date),
                  style: const TextStyle(
                    color: Color(0xFF8A796D),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OverviewError extends StatelessWidget {
  const _OverviewError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: const Color(0xFFFFE6E0),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      children: [
        Expanded(
          child: Text(
            message,
            style: const TextStyle(color: Color(0xFFA33A2B)),
          ),
        ),
        const SizedBox(width: 12),
        TextButton(onPressed: onRetry, child: const Text('Try again')),
      ],
    ),
  );
}

final _cardDecoration = BoxDecoration(
  color: Colors.white,
  border: Border.all(color: const Color(0xFFE8D7C2)),
  borderRadius: BorderRadius.circular(18),
);

String _formatUpdateDate(DateTime date) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
  final minute = date.minute.toString().padLeft(2, '0');
  final period = date.hour >= 12 ? 'PM' : 'AM';
  return '${months[date.month - 1]} ${date.day}, ${date.year} · '
      '$hour:$minute $period';
}

const _headingStyle = TextStyle(
  fontSize: 32,
  fontWeight: FontWeight.w800,
  color: Color(0xFF3B2419),
);

final _buttonStyle = FilledButton.styleFrom(
  backgroundColor: const Color(0xFFFF7434),
  foregroundColor: Colors.white,
  minimumSize: const Size.fromHeight(56),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
);

String? _validateEmail(String? value) {
  if (value == null || value.trim().isEmpty) return 'Enter your email.';
  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value.trim())) {
    return 'Enter a valid email.';
  }
  return null;
}

class _ErrorMessage extends StatelessWidget {
  const _ErrorMessage({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFFFE6E0),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Text(text, style: const TextStyle(color: Color(0xFFA33A2B))),
  );
}
