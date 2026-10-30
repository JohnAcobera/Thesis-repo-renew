import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thesis_repo_renew/models/classroom_model.dart';
import 'package:thesis_repo_renew/services/auth_service.dart';
import 'package:thesis_repo_renew/services/classroom_service.dart';
import 'package:thesis_repo_renew/services/leaderboard_service.dart';
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
    await tester.tap(find.byTooltip('Open profile menu'));
    await tester.pumpAndSettle();
    expect(find.text('Profile'), findsOneWidget);
    expect(find.text('Logout'), findsOneWidget);
    expect(find.text('Settings'), findsNothing);
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

  testWidgets('student can open the weekly leaderboard from the side menu', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final leaderboardRepository = _FakeLeaderboardRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: StudentHomeScreen(
          leaderboardRepository: leaderboardRepository,
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
    await tester.tap(find.text('Leaderboard'));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text('Weekly Leaderboard'),
      ),
      findsOneWidget,
    );
    expect(find.text('Student rankings'), findsOneWidget);
    expect(find.text('Alex Student'), findsOneWidget);
    expect(find.text('1,999 LP'), findsOneWidget);
    BorderSide rowBorder(String studentName) {
      final row = tester.widget<Container>(
        find
            .ancestor(
              of: find.text(studentName),
              matching: find.byType(Container),
            )
            .first,
      );
      return (row.decoration! as BoxDecoration).border!.top;
    }

    expect(
      rowBorder('Alex Student'),
      const BorderSide(color: Color(0xFFFFC107), width: 5),
    );
    expect(
      rowBorder('Blair Student'),
      const BorderSide(color: Color(0xFF9EA7B3), width: 4),
    );
    expect(
      rowBorder('Casey Student'),
      const BorderSide(color: Color(0xFFB76524), width: 3),
    );
    expect(find.text('#1'), findsOneWidget);
    expect(find.text('#2'), findsOneWidget);
    expect(find.text('#3'), findsOneWidget);
    expect(find.text('#4'), findsOneWidget);
    expect(find.text('#10'), findsOneWidget);
    expect(find.text('#11'), findsNothing);
    expect(
      rowBorder('Drew Student'),
      const BorderSide(color: Color(0xFFE8D7C2), width: 1),
    );
    expect(find.text('Weekly activity'), findsNothing);
    await tester.tap(find.byTooltip('Select leaderboard week'));
    await tester.pumpAndSettle();
    expect(find.text('This week'), findsOneWidget);
    expect(find.text('Last week (-1)'), findsOneWidget);
    expect(find.text('Two weeks ago (-2)'), findsOneWidget);
    await tester.tap(find.text('Last week (-1)'));
    await tester.pumpAndSettle();
    expect(find.text('LAST WEEK (-1)'), findsOneWidget);
    expect(leaderboardRepository.requestedWeeks, [0, -1]);
    await tester.drag(find.byType(ListView).first, const Offset(0, -10000));
    await tester.pumpAndSettle();
    expect(find.text('#99'), findsOneWidget);
    expect(find.text('#100'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('inventory uses the dashboard top bar without a duplicate', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
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
    await tester.tap(find.text('Inventory'));
    await tester.pumpAndSettle();

    expect(find.byType(AppBar), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text('Inventory'),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
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
    expect(find.text('Settings'), findsNothing);
    expect(find.text('STUDENT'), findsOneWidget);
    expect(find.text('Student'), findsNothing);

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    expect(find.text('Your profile'), findsOneWidget);
    expect(find.text('student@example.com'), findsWidgets);
    expect(find.byTooltip('Open menu'), findsOneWidget);
  });

  testWidgets('import screen offers three learning modes', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ImportScreen(
          username: 'Student Name',
          email: 'student@example.com',
        ),
      ),
    );

    expect(find.text('Learning Mode'), findsOneWidget);
    expect(find.text('Quiz'), findsOneWidget);
    expect(find.text('Flashcards'), findsOneWidget);
    expect(find.text('Matching'), findsOneWidget);
    expect(find.text('Question Types'), findsOneWidget);

    await tester.tap(find.text('Flashcards').first);
    await tester.pumpAndSettle();
    expect(find.text('Question Types'), findsNothing);
    expect(find.text('Number of Items'), findsOneWidget);

    await tester.tap(find.text('Matching').first);
    await tester.pumpAndSettle();
    expect(find.text('Question Types'), findsNothing);
    expect(find.text('Number of Items'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dashboard tutorial button opens the tutorial preview', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
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
    await tester.pump();

    expect(find.byTooltip('Preview tutorial'), findsOneWidget);
    await tester.tap(find.byTooltip('Preview tutorial'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome to your first study session'), findsOneWidget);
    expect(find.textContaining('YOUR QUICK START'), findsOneWidget);
    expect(find.byTooltip('Dismiss tutorial'), findsOneWidget);
    final tutorialTitleTop = tester
        .getTopLeft(find.text('Welcome to your first study session'))
        .dy;

    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -500),
    );
    await tester.pumpAndSettle();

    expect(find.text('Welcome to your first study session'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Welcome to your first study session')).dy,
      tutorialTitleTop,
    );

    await tester.tap(find.byTooltip('Dismiss tutorial'));
    await tester.pumpAndSettle();

    expect(find.text('Welcome to your first study session'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('new student dashboard automatically opens the tutorial', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: StudentHomeScreen(
          user: UserModel(
            id: 1,
            fullName: 'New Student',
            email: 'new-student@example.com',
            role: 'student',
          ),
          showTutorialOnOpen: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Welcome to your first study session'), findsOneWidget);
    expect(find.byTooltip('Dismiss tutorial'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dismissed tutorial stays dismissed even when opened again', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'quizforge_tutorial_dismissed_student@example.com': true,
    });
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: ImportScreen(
          username: 'Student Name',
          email: 'student@example.com',
          showTutorialOnOpen: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Welcome to your first study session'), findsNothing);
    expect(find.byTooltip('Dismiss tutorial'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tutorial advances and scrolls to question types', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: ImportScreen(
          username: 'Student Name',
          email: 'student@example.com',
          showTutorialOnOpen: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    for (var step = 0; step < 3; step++) {
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
    }

    expect(find.text('Pick your question style'), findsOneWidget);
    final targetRect = tester.getRect(find.text('Question Types'));
    final scrollViewport = tester.getRect(find.byType(SingleChildScrollView));
    expect(targetRect.top, greaterThanOrEqualTo(scrollViewport.top));
    expect(targetRect.bottom, lessThanOrEqualTo(scrollViewport.bottom));
    expect(tester.takeException(), isNull);
  });

  testWidgets('learning mode choices fill the narrow screen content width', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: ImportScreen(
          username: 'Student Name',
          email: 'student@example.com',
        ),
      ),
    );

    final tileSizes = ['quiz', 'flashcards', 'matching'].map((mode) {
      final tile = tester.getSize(find.byKey(ValueKey('learning-mode-$mode')));
      expect(tile.width, greaterThan(280));
      return tile;
    }).toList();
    expect(tileSizes.map((size) => size.width).toSet(), hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('dashboard Profile menu opens the profile screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = _FakeStudentClassroomRepository();
    final leaderboardRepository = _FakeLeaderboardRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: StudentHomeScreen(
          classroomService: repository,
          leaderboardRepository: leaderboardRepository,
          user: UserModel(
            id: 1,
            fullName: 'Student Name',
            email: 'student@example.com',
            role: 'student',
            createdAt: DateTime(2024, 3, 12),
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
    expect(find.text('Student'), findsWidgets);
    expect(find.text('March 12, 2024'), findsOneWidget);

    await tester.tap(find.byTooltip('Open menu'));
    await tester.pumpAndSettle();
    expect(find.text('My Classroom'), findsOneWidget);
    await tester.tap(find.text('My Classroom'));
    await tester.pumpAndSettle();
    expect(find.byType(ProfileScreen), findsNothing);
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text('My Classroom'),
      ),
      findsOneWidget,
    );
    expect(find.text('Your classrooms'), findsOneWidget);

    await tester.tap(find.byTooltip('Open menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Open menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Leaderboard'));
    await tester.pumpAndSettle();

    expect(find.byType(ProfileScreen), findsNothing);
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text('Weekly Leaderboard'),
      ),
      findsOneWidget,
    );
    expect(find.text('Student rankings'), findsOneWidget);
    expect(leaderboardRepository.requestedWeeks, [0]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('student can open My Classroom and join using its code', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _FakeStudentClassroomRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: StudentHomeScreen(
          user: const UserModel(
            id: 2,
            fullName: 'Student Name',
            email: 'student@example.com',
            role: 'student',
          ),
          classroomService: repository,
        ),
      ),
    );

    await tester.tap(find.byTooltip('Open menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('My Classroom').first);
    await tester.pumpAndSettle();

    expect(find.text('Join classroom'), findsOneWidget);
    expect(find.text('Create classroom'), findsNothing);
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text('My Classroom'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byTooltip('Open menu'));
    await tester.pumpAndSettle();
    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
    for (final removedItem in ['Quiz', 'Summarizer', 'Flashcard', 'Reviewer']) {
      expect(find.text(removedItem), findsNothing);
    }
    await tester.tap(find.text('My Classroom').first);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Join classroom'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Classroom code'),
      ' abcd2345 ',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Join classroom').last);
    await tester.pumpAndSettle();

    expect(repository.joinedCode, 'ABCD2345');
    expect(find.text('Joined Biology'), findsOneWidget);
    expect(find.text('Biology'), findsOneWidget);
    expect(find.text('Code: ABCD2345'), findsOneWidget);
    expect(tester.takeException(), isNull);
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

  testWidgets('profile omits the achievements section', (tester) async {
    tester.view.physicalSize = const Size(420, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: ProfileScreen(
          username: 'Student Name',
          email: 'student@example.com',
          authService: _LearnerPointsAuthService(0, ranking: 2),
          streakDays: {},
        ),
      ),
    );
    await tester.pump();

    final calendar = find.text('Learning streak');
    final achievements = find.text('Your Achievements');
    expect(calendar, findsOneWidget);
    expect(achievements, findsNothing);
    expect(find.text('LP'), findsOneWidget);
    expect(find.text('0'), findsOneWidget);
    expect(find.text('Weekly ranking #2'), findsOneWidget);
    expect(find.byIcon(Icons.diamond_outlined), findsOneWidget);
    final learnerPointsTooltip = tester.widget<Tooltip>(
      find.byWidgetPredicate(
        (widget) =>
            widget is Tooltip &&
            widget.richMessage?.toPlainText().contains(
                  'HOW TO EARN LEARNER POINTS',
                ) ==
                true,
      ),
    );
    final tooltipText = learnerPointsTooltip.richMessage!.toPlainText();
    expect(tooltipText, contains('up to 700 LP per day'));
    expect(tooltipText, contains('first attempt on a quiz adds 50 LP'));
    expect(tooltipText, contains('the second adds 25 LP'));
    expect(tooltipText, contains('one-time 150 LP bonus'));
    expect(
      find.bySemanticsLabel('Show how to earn Learner Points'),
      findsOneWidget,
    );
    expect(find.text('No achievements yet'), findsNothing);
    expect(find.text('Your achievements will appear here.'), findsNothing);
    expect(
      tester.widget<Text>(find.text('Weekly ranking #2')).style?.color,
      const Color(0xFF9EA7B3),
    );
  });

  testWidgets('instructor profile omits learner-only sections', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ProfileScreen(
          username: 'Instructor Name',
          email: 'instructor@example.com',
          role: 'INSTRUCTOR',
          authService: _LearnerPointsAuthService(1000, ranking: 2),
        ),
      ),
    );

    expect(find.text('Instructor'), findsOneWidget);
    expect(find.text('LP'), findsNothing);
    expect(find.byIcon(Icons.diamond_outlined), findsNothing);
    expect(find.text('Weekly ranking #2'), findsNothing);
    expect(find.text('Your learning stats'), findsNothing);
  });

  testWidgets('profile displays the loaded learner point balance with commas', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ProfileScreen(
          username: 'Student Name',
          email: 'student@example.com',
          authService: _LearnerPointsAuthService(1234567, ranking: 2),
          streakDays: {},
        ),
      ),
    );
    await tester.pump();

    expect(find.text('1,234,567'), findsOneWidget);
  });

  testWidgets('profile streak counts consecutive login days', (tester) async {
    final today = DateTime.now();
    final yesterday = today.subtract(const Duration(days: 1));

    await tester.pumpWidget(
      MaterialApp(
        home: ProfileScreen(
          username: 'Student Name',
          email: 'student@example.com',
          streakDays: {today, yesterday},
        ),
      ),
    );

    expect(find.text('2 days in a row'), findsOneWidget);
  });

  testWidgets('profile resets the streak after a missed day', (tester) async {
    final today = DateTime.now();
    final lastLogin = DateTime(
      today.year,
      today.month,
      today.day,
    ).subtract(const Duration(days: 2));

    await tester.pumpWidget(
      MaterialApp(
        home: ProfileScreen(
          username: 'Student Name',
          email: 'student@example.com',
          streakDays: {lastLogin},
        ),
      ),
    );

    expect(find.text('0 days in a row'), findsOneWidget);
  });

  testWidgets('menu overlays the body and selects a menu item', (tester) async {
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
        of: find.text('My Classroom'),
        matching: find.byType(AnimatedOpacity),
      ),
    );
    expect(closedMenuOpacity.opacity, 0);
    expect(find.bySemanticsLabel('Achievements'), findsNothing);

    final initialBodyLeft = tester.getTopLeft(find.byKey(bodyKey)).dx;
    final closedDrawerLeft = tester.getTopLeft(find.text('My Classroom')).dx;
    await tester.tap(find.byTooltip('Open menu'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 140));

    final drawerLeftDuringAnimation = tester
        .getTopLeft(find.text('My Classroom'))
        .dx;
    expect(drawerLeftDuringAnimation, lessThan(0));
    expect(drawerLeftDuringAnimation, greaterThan(closedDrawerLeft));

    await tester.pumpAndSettle();

    expect(find.text('Student Name'), findsNWidgets(2));
    expect(find.text('student@example.com'), findsNWidgets(2));
    final emailText = tester.widget<Text>(
      find.text('student@example.com').first,
    );
    expect(emailText.maxLines, 1);
    expect(
      tester
          .renderObject<RenderParagraph>(find.text('student@example.com').first)
          .didExceedMaxLines,
      isFalse,
    );
    expect(find.text('Profile'), findsOneWidget);
    expect(find.text('Achievements'), findsNothing);
    expect(find.text('My Classroom'), findsOneWidget);
    for (final removedItem in ['Quiz', 'Summarizer', 'Flashcard', 'Reviewer']) {
      expect(find.text(removedItem), findsNothing);
    }

    final menuDivider = tester.widget<Divider>(find.byType(Divider).first);
    expect(
      tester.getSize(find.byWidget(menuDivider)).width,
      lessThan(tester.view.physicalSize.width),
    );
    expect(tester.getTopLeft(find.byKey(bodyKey)).dx, initialBodyLeft);

    await tester.tap(find.text('My Classroom'));
    await tester.pumpAndSettle();

    expect(selectedItem, StudentMenuItem.classroom);
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
          selectedMenu: StudentMenuItem.classroom,
        ),
      ),
    );

    await tester.tap(find.byTooltip('Open menu'));
    await tester.pumpAndSettle();

    expect(find.text('Mobile body'), findsOneWidget);
    expect(find.text('My Classroom'), findsOneWidget);
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

  testWidgets('menu overlays centered wide-screen body content', (
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

    final initialPanelLeft = tester.getTopLeft(find.byKey(panelKey)).dx;
    await tester.tap(find.byTooltip('Open menu'));
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(find.byKey(panelKey)).dx, initialPanelLeft);
  });
}

class _LearnerPointsAuthService implements ProfileDataService {
  _LearnerPointsAuthService(this.points, {required this.ranking});

  final int points;
  final int? ranking;

  @override
  Future<int> learnerPoints() async => points;

  @override
  Future<int?> weeklyRanking() async => ranking;

  @override
  Future<Set<DateTime>> loginDates() async => {};
}

class _FakeLeaderboardRepository implements LeaderboardRepository {
  final requestedWeeks = <int>[];

  @override
  Future<List<WeeklyLeaderboardEntry>> weeklyLeaderboard({
    required int weekOffset,
  }) async {
    requestedWeeks.add(weekOffset);
    return List.generate(100, (index) {
      final rank = index + 1;
      return WeeklyLeaderboardEntry(
        rank: rank,
        userId: rank + 1,
        fullName: switch (rank) {
          1 => 'Alex Student',
          2 => 'Blair Student',
          3 => 'Casey Student',
          4 => 'Drew Student',
          _ => 'Student $rank',
        },
        points: (2000 - rank).clamp(0, 2000).toInt(),
      );
    });
  }
}

class _FakeStudentClassroomRepository implements ClassroomRepository {
  String? joinedCode;
  final classroom = ClassroomModel(
    id: 'class-id',
    name: 'Biology',
    subject: 'General Biology 1',
    code: 'ABCD2345',
    createdAt: DateTime.utc(2026),
    iconKey: 'science',
    studentCount: 1,
  );

  @override
  Future<List<ClassroomStudentSummary>> classroomStudents(
    String classroomId,
  ) async => [];

  @override
  Future<List<ClassroomStudentSummary>> classroomClassmates(
    String classroomId,
  ) async => [];

  @override
  Future<void> removeClassroomStudent({
    required String classroomId,
    required int studentId,
  }) async {}

  @override
  Future<InstructorDashboardStats> getInstructorDashboardStats() async =>
      const InstructorDashboardStats(studentCount: 0, activeClassCount: 0);

  @override
  Future<ClassroomModel> createClassroom({
    required String name,
    required String subject,
    required String iconKey,
  }) async => throw UnimplementedError();

  @override
  Future<ClassroomModel> joinClassroom({required String code}) async {
    joinedCode = code.toUpperCase();
    return classroom;
  }

  @override
  Future<List<ClassroomModel>> listClassrooms() async => [];

  @override
  Future<List<ClassroomModel>> listStudentClassrooms() async =>
      joinedCode == null ? [] : [classroom];

  @override
  Future<void> deleteClassroom(String classroomId) async {}
}
