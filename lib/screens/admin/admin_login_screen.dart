import 'package:flutter/material.dart';

import '../../models/user_model.dart';
import '../../services/auth_service.dart';

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
    if (_admin case final admin?) {
      return _AdminHome(admin: admin, onSignOut: _signOut);
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

class _AdminHome extends StatelessWidget {
  const _AdminHome({required this.admin, required this.onSignOut});

  final UserModel admin;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin panel'),
        actions: [
          TextButton.icon(
            onPressed: onSignOut,
            icon: const Icon(Icons.logout),
            label: const Text('Log out'),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Signed in as ${admin.fullName}.\nAdmin tools will be added here.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
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
