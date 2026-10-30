import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'screens/admin/admin_login_screen.dart';
import 'screens/landing/landing_screen.dart';
import 'widgets/app_background.dart';

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
      builder: (context, child) {
        final mediaQuery = MediaQuery.of(context);
        final content = mediaQuery.size.width < 600
            ? MediaQuery(
                data: mediaQuery.copyWith(
                  textScaler: _ScaledTextScaler(mediaQuery.textScaler, 0.9),
                ),
                child: child ?? const SizedBox.shrink(),
              )
            : child ?? const SizedBox.shrink();

        return Stack(
          fit: StackFit.expand,
          children: [
            const Positioned.fill(child: AppBackground()),
            content,
          ],
        );
      },
      theme: ThemeData(
        colorScheme:
            ColorScheme.fromSeed(
              seedColor: _buttonColor,
              brightness: Brightness.light,
            ).copyWith(
              primary: _buttonColor,
              surface: const Color(0xFFFFFCF8),
              onSurface: const Color(0xFF3B2419),
            ),
        pageTransitionsTheme: PageTransitionsTheme(
          builders: {
            for (final platform in TargetPlatform.values)
              platform: const _SmoothPageTransitionsBuilder(),
          },
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: _buttonColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: _buttonColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: _buttonColor,
            side: const BorderSide(color: _buttonColor),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: _buttonColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        tooltipTheme: TooltipThemeData(
          decoration: BoxDecoration(
            color: const Color(0xFFFFF8EB),
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 14,
                offset: Offset(0, 6),
              ),
            ],
          ),
          textStyle: const TextStyle(color: Color(0xFF1F1A17), fontSize: 12),
        ),
        scaffoldBackgroundColor: Colors.transparent,
        fontFamily: 'sans',
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          foregroundColor: Color(0xFF3B2419),
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
        cardTheme: CardThemeData(
          color: Colors.white.withValues(alpha: 0.6),
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: Colors.white.withValues(alpha: 0.78),
              width: 1.2,
            ),
          ),
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: const Color(0xFFFFFCF8).withValues(alpha: 0.96),
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: BorderSide(
              color: Colors.white.withValues(alpha: 0.88),
              width: 1.2,
            ),
          ),
        ),
        bottomSheetTheme: BottomSheetThemeData(
          backgroundColor: const Color(0xFFFFFCF8).withValues(alpha: 0.96),
          surfaceTintColor: Colors.transparent,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFFFF1DF).withValues(alpha: 0.88),
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

class _SmoothPageTransitionsBuilder extends PageTransitionsBuilder {
  const _SmoothPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curvedAnimation = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    return FadeTransition(
      opacity: curvedAnimation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0.015, 0),
          end: Offset.zero,
        ).animate(curvedAnimation),
        child: child,
      ),
    );
  }
}

class _ScaledTextScaler extends TextScaler {
  const _ScaledTextScaler(this.baseScaler, this.factor);

  final TextScaler baseScaler;
  final double factor;

  @override
  double scale(double fontSize) => baseScaler.scale(fontSize) * factor;

  @override
  double get textScaleFactor => scale(1);
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
