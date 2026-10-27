import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthException;

import '../../services/auth_service.dart';
import '../../services/tutorial_service.dart';
import '../landing/landing_screen.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _otpController = TextEditingController();
  final _otpDigitControllers = List.generate(6, (_) => TextEditingController());
  final _otpFocusNodes = List.generate(6, (_) => FocusNode());
  late final _service = AuthService();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  bool _otpSent = false;
  String? _error;

  Future<void> _register() async {
    if (_isLoading) return;
    if (!_formKey.currentState!.validate()) return;
    if (!_otpSent) {
      await _sendVerificationCode();
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final verification = await _invokeRegistrationOtp({
        'action': 'verify',
        'email': _emailController.text.trim(),
        'otp': _otpController.text.trim(),
        'password': _passwordController.text,
      });
      if (verification['success'] != true) {
        throw const AuthException(
          'The verification service returned an invalid response.',
        );
      }

      await _service.register(
        fullName: _nameController.text,
        email: _emailController.text,
        password: _passwordController.text,
        role: 'student',
      );
      if (!mounted) return;
      try {
        await const TutorialService().markFirstLoginPending(
          _emailController.text,
        );
      } on Exception catch (error, stackTrace) {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: error,
            stack: stackTrace,
            library: 'registration',
            context: ErrorDescription('while scheduling the new-user tutorial'),
          ),
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Your account was created, but the welcome tutorial could not '
                'be scheduled.',
              ),
            ),
          );
        }
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account created. You can now log in.')),
      );
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
      );
    } on AuthException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _sendVerificationCode() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final response = await _invokeRegistrationOtp({
        'action': 'send',
        'email': _emailController.text.trim(),
      });
      if (response['success'] != true) {
        throw const AuthException(
          'The verification service returned an invalid response.',
        );
      }
      if (mounted) {
        setState(() => _otpSent = true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              response['message'] as String? ??
                  'Verification code sent. Check your inbox and spam folder.',
                  
            ),
          ),
        );
      }
    } on AuthException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onOtpDigitChanged(
    int index,
    String value,
    FormFieldState<String> field,
  ) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length > 1) {
      for (var i = index; i < _otpDigitControllers.length; i++) {
        final digitIndex = i - index;
        _otpDigitControllers[i].text = digitIndex < digits.length
            ? digits[digitIndex]
            : '';
      }
      final nextIndex = (index + digits.length).clamp(
        index,
        _otpDigitControllers.length - 1,
      );
      _otpFocusNodes[nextIndex].requestFocus();
    } else {
      _otpDigitControllers[index].text = digits;
      if (digits.isNotEmpty && index < _otpFocusNodes.length - 1) {
        _otpFocusNodes[index + 1].requestFocus();
      } else if (digits.isEmpty && index > 0) {
        _otpFocusNodes[index - 1].requestFocus();
      }
    }

    final otp = _otpDigitControllers
        .map((controller) => controller.text)
        .join();
    _otpController.text = otp;
    field.didChange(otp);
  }

  Future<Map<String, dynamic>> _invokeRegistrationOtp(
    Map<String, String> body,
  ) async {
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'registration-otp',
        body: body,
      );
      final data = response.data;
      if (data is Map<String, dynamic>) return data;
      if (data is Map) {
        return data.map((key, value) => MapEntry(key.toString(), value));
      }
      throw const AuthException(
        'The verification service returned an invalid response.',
      );
    } on FunctionException catch (error) {
      throw AuthException(
        error.status == 0
            ? 'Unable to connect to the verification service. Please try again.'
            : 'The verification service could not process your request. Please try again.',
      );
    } on AuthException {
      rethrow;
    } on Exception {
      throw const AuthException(
        'Unable to connect to the verification service. Please try again.',
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _otpController.dispose();
    for (final controller in _otpDigitControllers) {
      controller.dispose();
    }
    for (final focusNode in _otpFocusNodes) {
      focusNode.dispose();
    }
    super.dispose();
  }

  Widget _otpInput() {
    return FormField<String>(
      validator: (value) => value == null || !RegExp(r'^\d{6}$').hasMatch(value)
          ? 'Enter the six-digit verification code.'
          : null,
      builder: (field) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Email verification code',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (var i = 0; i < _otpDigitControllers.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: Semantics(
                    label: 'Verification code digit ${i + 1}',
                    child: TextField(
                      controller: _otpDigitControllers[i],
                      focusNode: _otpFocusNodes[i],
                      keyboardType: TextInputType.number,
                      textInputAction: i == _otpDigitControllers.length - 1
                          ? TextInputAction.done
                          : TextInputAction.next,
                      autofillHints: i == 0
                          ? const [AutofillHints.oneTimeCode]
                          : null,
                      textAlign: TextAlign.center,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: (value) => _onOtpDigitChanged(i, value, field),
                      decoration: const InputDecoration(
                        counterText: '',
                        contentPadding: EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (field.errorText != null) ...[
            const SizedBox(height: 8),
            Text(
              field.errorText!,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontSize: 12,
              ),
            ),
          ] else
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('Enter the six-digit code sent to your email (Check spam folder).'),
              
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create account'),
        automaticallyImplyLeading: false,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pushReplacement(
            MaterialPageRoute<void>(builder: (_) => const LandingScreen()),
          ),
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back to landing page',
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Join the community', style: _headingStyle),
                    const SizedBox(height: 8),
                    const Text('Create your student account to get started.'),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _nameController,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(labelText: 'Full name'),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Enter your full name.'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(labelText: 'Email'),
                      validator: _validateEmail,
                    ),
                    if (_otpSent) ...[
                      const SizedBox(height: 16),
                      _otpInput(),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _isLoading ? null : _sendVerificationCode,
                          child: const Text('Resend code'),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    _passwordField(
                      controller: _passwordController,
                      label: 'Password',
                      obscure: _obscurePassword,
                      textInputAction: TextInputAction.next,
                      onToggle: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Create a password.';
                        }
                        if (value.length < 8) {
                          return 'Use at least 8 characters.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    _passwordField(
                      controller: _confirmController,
                      label: 'Confirm password',
                      obscure: _obscureConfirm,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) {
                        if (!_isLoading) _register();
                      },
                      onToggle: () =>
                          setState(() => _obscureConfirm = !_obscureConfirm),
                      validator: (value) => value != _passwordController.text
                          ? 'Passwords do not match.'
                          : null,
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      _Message(text: _error!),
                    ],
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _isLoading ? null : _register,
                      style: _buttonStyle,
                      child: _isLoading
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              _otpSent
                                  ? 'Verify and create account'
                                  : 'Send verification code',
                            ),
                    ),
                    TextButton(
                      onPressed: _isLoading
                          ? null
                          : () => Navigator.of(context).pushReplacement(
                              MaterialPageRoute<void>(
                                builder: (_) => const LoginScreen(),
                              ),
                            ),
                      child: const Text('Already have an account? Log in'),
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

  Widget _passwordField({
    required TextEditingController controller,
    required String label,
    required bool obscure,
    required TextInputAction textInputAction,
    ValueChanged<String>? onSubmitted,
    required VoidCallback onToggle,
    required String? Function(String?) validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      textInputAction: textInputAction,
      onFieldSubmitted: onSubmitted,
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: IconButton(
          onPressed: onToggle,
          icon: Icon(
            obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
          ),
        ),
      ),
      validator: validator,
    );
  }
}

const _headingStyle = TextStyle(
  fontSize: 30,
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
  if (value == null || value.trim().isEmpty) {
    return 'Enter your email.';
  }
  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value.trim())) {
    return 'Enter a valid email.';
  }
  return null;
}

class _Message extends StatelessWidget {
  const _Message({required this.text});

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
