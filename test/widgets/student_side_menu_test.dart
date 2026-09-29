import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thesis_repo_renew/screens/import_screen.dart';
import 'package:thesis_repo_renew/screens/home/student_home_screen.dart';
import 'package:thesis_repo_renew/models/user_model.dart';
import 'package:thesis_repo_renew/screens/profile_screen.dart';
import 'package:thesis_repo_renew/widgets/student_nav_bar.dart';
import 'package:thesis_repo_renew/widgets/student_side_menu.dart';

void main() {
  testWidgets('navbar omits the import shortcut', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(appBar: StudentNavBar(), body: SizedBox.shrink()),
      ),
    );

    expect(find.byTooltip('Import'), findsNothing);
    expect(find.byTooltip('Open profile menu'), findsOneWidget);
  });

  testWidgets('student scaffold keeps a back action beside the menu', (
    tester,
  ) async {
    var didGoBack = false;
    await tester.pumpWidget(
      MaterialApp(
        home: StudentScaffold(
          title: 'Generate a Study Material',
          username: 'Student Name',
          email: 'student@example.com',
          body: const SizedBox.shrink(),
          onBack: () => didGoBack = true,
        ),
      ),
    );

    expect(find.byTooltip('Open menu'), findsOneWidget);
    await tester.tap(find.byTooltip('Back'));
    expect(didGoBack, isTrue);
  });

  testWidgets('import screen displays the student side-menu controls', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ImportScreen(
          username: 'Student Name',
          email: 'student@example.com',
        ),
      ),
    );

    expect(find.byTooltip('Open menu'), findsOneWidget);
    expect(find.byTooltip('Back'), findsNothing);
    await tester.tap(find.byTooltip('Open menu'));
    await tester.pumpAndSettle();
    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    expect(find.text('Your profile'), findsOneWidget);
    expect(find.text('student@example.com'), findsWidgets);
    expect(find.byTooltip('Open menu'), findsOneWidget);
  });

  testWidgets('dashboard Profile menu opens the profile screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: StudentHomeScreen(
          user: UserModel(
            id: 1,
            fullName: 'Student Name',
            email: 'student@example.com',
            role: 'student',
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Open menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();

    expect(find.byType(ProfileScreen), findsOneWidget);
    expect(find.text('Your profile'), findsOneWidget);
    expect(find.text('Student Name'), findsWidgets);
  });

  testWidgets('returning to dashboard restores its selected menu item', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: StudentHomeScreen(
          user: UserModel(
            id: 1,
            fullName: 'Student Name',
            email: 'student@example.com',
            role: 'student',
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Open menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Open menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dashboard'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Open menu'));
    await tester.pumpAndSettle();

    Text menuTitle(String label) {
      final tile = tester.widget<ListTile>(
        find
            .ancestor(of: find.text(label), matching: find.byType(ListTile))
            .first,
      );
      return tile.title! as Text;
    }

    final dashboardTitle = menuTitle('Dashboard');
    expect(dashboardTitle.style?.color, const Color(0xFFF4773C));
    expect(menuTitle('Profile').style?.color, const Color(0xFF3B2419));
  });

  testWidgets('profile streak calendar marks supplied days and changes month', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(420, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final now = DateTime.now();
    const monthNames = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: ProfileScreen(
          username: 'Student Name',
          email: 'student@example.com',
          streakDays: {DateTime(now.year, now.month, 15, 12)},
        ),
      ),
    );

    expect(
      find.text('${monthNames[now.month - 1]} ${now.year}'),
      findsOneWidget,
    );
    expect(
      tester.widget<Text>(find.text('15')).style?.color,
      const Color(0xFFFFFFFF),
    );

    final nextMonth = DateTime(now.year, now.month + 1);
    await tester.ensureVisible(find.byTooltip('Next month'));
    await tester.tap(find.byTooltip('Next month'));
    await tester.pumpAndSettle();

    expect(
      find.text('${monthNames[nextMonth.month - 1]} ${nextMonth.year}'),
      findsOneWidget,
    );
  });

  testWidgets(
    'profile shows an empty achievements section below the calendar',
    (tester) async {
      tester.view.physicalSize = const Size(420, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: ProfileScreen(
            username: 'Student Name',
            email: 'student@example.com',
          ),
        ),
      );

      final calendar = find.text('Learning streak');
      final achievements = find.text('Your Achievements');
      expect(calendar, findsOneWidget);
      expect(achievements, findsOneWidget);
      expect(
        tester.getTopLeft(achievements).dy,
        greaterThan(tester.getTopLeft(calendar).dy),
      );
      expect(find.text('No achievements yet'), findsOneWidget);
      expect(find.text('Your achievements will appear here.'), findsOneWidget);
    },
  );

  testWidgets('menu pushes the body and selects a menu item', (tester) async {
    StudentMenuItem? selectedItem;
    const bodyKey = ValueKey<String>('student-body');

    await tester.pumpWidget(
      MaterialApp(
        home: StudentScaffold(
          title: 'Student Dashboard',
          username: 'Student Name',
          email: 'student@example.com',
          body: const SizedBox.expand(
            key: bodyKey,
            child: ColoredBox(color: Colors.white),
          ),
          onMenuSelected: (item) => selectedItem = item,
        ),
      ),
    );

    final closedMenuOpacity = tester.widget<AnimatedOpacity>(
      find.ancestor(
        of: find.text('Achievements'),
        matching: find.byType(AnimatedOpacity),
      ),
    );
    expect(closedMenuOpacity.opacity, 0);
    expect(find.bySemanticsLabel('Achievements'), findsNothing);

    final initialBodyLeft = tester.getTopLeft(find.byKey(bodyKey)).dx;
    await tester.tap(find.byTooltip('Open menu'));
    await tester.pumpAndSettle();

    expect(find.text('Student Name'), findsOneWidget);
    final emailText = tester.widget<Text>(find.text('student@example.com'));
    expect(emailText.maxLines, 1);
    expect(
      tester
          .renderObject<RenderParagraph>(find.text('student@example.com'))
          .didExceedMaxLines,
      isFalse,
    );
    expect(find.text('Profile'), findsOneWidget);
    expect(find.text('Achievements'), findsOneWidget);
    expect(find.text('Quiz'), findsOneWidget);
    await tester.dragFrom(const Offset(150, 300), const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(find.text('Summarizer'), findsOneWidget);
    expect(find.text('Flashcard'), findsOneWidget);
    expect(find.text('Reviewer'), findsOneWidget);
    final menuDivider = tester.widget<Divider>(find.byType(Divider).first);
    expect(
      tester.getSize(find.byWidget(menuDivider)).width,
      lessThan(tester.view.physicalSize.width),
    );
    expect(
      tester.getTopLeft(find.byKey(bodyKey)).dx,
      greaterThan(initialBodyLeft),
    );

    await tester.dragFrom(const Offset(150, 300), const Offset(0, 300));
    await tester.pumpAndSettle();
    await tester.tapAt(Offset(150, tester.getCenter(find.text('Quiz')).dy));
    await tester.pumpAndSettle();

    expect(selectedItem, StudentMenuItem.quiz);
    expect(find.byTooltip('Open menu'), findsOneWidget);
  });

  testWidgets('menu fits the stacked mobile layout', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: StudentScaffold(
          title: 'Student Dashboard',
          username: 'Student Name',
          email: 'student@example.com',
          body: const Center(child: Text('Mobile body')),
          selectedMenu: StudentMenuItem.quiz,
        ),
      ),
    );

    await tester.tap(find.byTooltip('Open menu'));
    await tester.pumpAndSettle();

    expect(find.text('Mobile body'), findsOneWidget);
    expect(find.text('Quiz'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tapAt(const Offset(350, 300));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Open menu'), findsOneWidget);

    await tester.tap(find.byTooltip('Open menu'));
    await tester.pumpAndSettle();
    await tester.dragFrom(const Offset(350, 300), const Offset(-100, 0));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Open menu'), findsOneWidget);
  });

  testWidgets('menu aligns with centered wide-screen body content', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const panelKey = ValueKey<String>('wide-panel');

    await tester.pumpWidget(
      MaterialApp(
        home: StudentScaffold(
          title: 'Student Dashboard',
          username: 'Student Name',
          email: 'student@example.com',
          body: Center(
            child: SizedBox(
              width: 1280,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: SizedBox(key: panelKey, width: 100, height: 100),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Open menu'));
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(find.byKey(panelKey)).dx, greaterThan(184));
  });
}
