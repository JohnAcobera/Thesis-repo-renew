import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thesis_repo_renew/main.dart';
import 'package:thesis_repo_renew/widgets/app_background.dart';
import 'package:thesis_repo_renew/widgets/app_glass_surface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('reduces text size on phone-width screens', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MainApp(isConfigured: false));

    final context = tester.element(
      find.textContaining('Supabase is not configured'),
    );
    expect(MediaQuery.textScalerOf(context).scale(100), closeTo(90, 0.01));
  });

  testWidgets('keeps desktop text size unchanged', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MainApp(isConfigured: false));

    final context = tester.element(
      find.textContaining('Supabase is not configured'),
    );
    expect(MediaQuery.textScalerOf(context).scale(100), closeTo(100, 0.01));
  });

  testWidgets('applies shared app background and translucent card theme', (
    tester,
  ) async {
    await tester.pumpWidget(const MainApp(isConfigured: false));

    final context = tester.element(
      find.textContaining('Supabase is not configured'),
    );
    final theme = Theme.of(context);

    expect(find.byType(AppBackground), findsOneWidget);
    expect(theme.scaffoldBackgroundColor, Colors.transparent);
    expect(theme.cardTheme.color!.a, closeTo(0.6, 0.001));
    expect(theme.cardTheme.surfaceTintColor, Colors.transparent);
  });

  testWidgets('uses 40 percent transparency for shared glass panels', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: AppGlassSurface(child: SizedBox.shrink())),
      ),
    );

    final surfaceContainer = tester.widget<Container>(
      find.descendant(
        of: find.byType(AppGlassSurface),
        matching: find.byType(Container),
      ),
    );
    final gradient =
        (surfaceContainer.decoration! as BoxDecoration).gradient!
            as LinearGradient;

    expect(
      gradient.colors,
      everyElement(
        predicate<Color>((color) {
          return (color.a - 0.6).abs() < 0.001;
        }),
      ),
    );
  });
}
