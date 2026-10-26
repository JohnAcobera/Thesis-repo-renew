import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thesis_repo_renew/main.dart';

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
}
