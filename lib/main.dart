import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'screens/admin/admin_login_screen.dart';
import 'screens/landing/landing_screen.dart';

const _buttonColor = Color(0xFFFF7434);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  final isConfigured = _hasValidConfiguration(supabaseUrl, supabaseAnonKey);

  if (isConfigured) {
    await Supabase.initialize(
      url: supabaseUrl,
      publishableKey: supabaseAnonKey,
    );
  }

  runApp(MainApp(isConfigured: isConfigured));
}

bool _hasValidConfiguration(String url, String key) {
  return url.startsWith('https://') &&
      url.endsWith('.supabase.co') &&
      key.isNotEmpty &&
      !key.startsWith('REPLACE_') &&
      !key.startsWith('YOUR_') &&
      !key.contains('publishable-key');
}

class MainApp extends StatelessWidget {
  const MainApp({required this.isConfigured, super.key});

  final bool isConfigured;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: _buttonColor,
          brightness: Brightness.light,
        ).copyWith(primary: _buttonColor),
        pageTransitionsTheme: PageTransitionsTheme(
          builders: {
            for (final platform in TargetPlatform.values)
              platform: const FadeUpwardsPageTransitionsBuilder(),
          },
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: _buttonColor,
            foregroundColor: Colors.white,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: _buttonColor,
            foregroundColor: Colors.white,
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: _buttonColor,
            side: const BorderSide(color: _buttonColor),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: _buttonColor),
        ),
        scaffoldBackgroundColor: const Color(0xFFFFF8EE),
        fontFamily: 'sans',
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFFFF1DF),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: Color(0xFFE8D7C2)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: Color(0xFFE8D7C2)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: _buttonColor, width: 2),
          ),
        ),
      ),
      home: isConfigured
          ? _isAdminRoute(Uri.base)
                ? const AdminLoginScreen()
                : const LandingScreen()
          : const _ConfigurationScreen(),
    );
  }
}

bool _isAdminRoute(Uri uri) {
  final path = uri.path.replaceFirst(RegExp(r'/+$'), '');
  final fragment = uri.fragment.split('?').first;
  return path == '/admin' || fragment == '/admin';
}

class _ConfigurationScreen extends StatelessWidget {
  const _ConfigurationScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Supabase is not configured.\nAdd your real public Supabase '
            'anon/publishable key to the .env file and pass it with '
            '--dart-define-from-file=.env.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
