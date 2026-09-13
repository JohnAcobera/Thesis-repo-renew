import 'package:flutter/material.dart';

import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import 'register_screen.dart';
import '../home/instructor_home_screen.dart';
import '../home/student_home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _service = AuthService();
  bool _obscurePassword = true;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    try {
      final user = await _service.restoreSession();
      if (!mounted) return;
      if (user != null) _openHome(user);
    } catch (_) {
      if (mounted) setState(() => _error = 'Unable to restore your session.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final result = await _service.login(
        email: _emailController.text,
        password: _passwordController.text,
      );
      if (mounted) _openHome(result.user);
    } on AuthException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _openHome(UserModel user) {
    final screen = user.role == 'instructor'
        ? InstructorHomeScreen(user: user)
        : StudentHomeScreen(user: user);
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute<void>(builder: (_) => screen));
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                    _BrandHeader(label: 'LEARN TOGETHER'),
                    const SizedBox(height: 34),
                    const Text('Welcome Back', style: _headingStyle),
                    const SizedBox(height: 8),
                    const Text('Sign in to continue your learning journey.'),
                    const SizedBox(height: 28),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: 'Email'),
                      validator: (value) => _validateEmail(value),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
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
                      _Message(text: _error!, isError: true),
                    ],
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _isLoading ? null : _login,
                      style: _buttonStyle,
                      child: _isLoading
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Log in'),
                    ),
                    const SizedBox(height: 18),
                    TextButton(
                      onPressed: _isLoading
                          ? null
                          : () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const RegisterScreen(),
                              ),
                            ),
                      child: const Text("Don't have an account? Register"),
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

const _headingStyle = TextStyle(
  fontSize: 32,
  fontWeight: FontWeight.w800,
  color: Color(0xFF3B2419),
);
final _buttonStyle = FilledButton.styleFrom(
  backgroundColor: const Color(0xFFF4773C),
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

class _BrandHeader extends StatelessWidget {
  const _BrandHeader({required this.label});

  final String label;

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
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
            color: Color(0xFF3B2419),
          ),
        ),
      ],
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text, required this.isError});

  final String text;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isError ? const Color(0xFFFFE6E0) : const Color(0xFFE4F4E8),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: isError ? const Color(0xFFA33A2B) : Colors.green,
        ),
      ),
    );
  }
}
