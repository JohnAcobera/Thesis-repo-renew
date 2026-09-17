import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../auth/login_screen.dart';
import '../auth/register_screen.dart';
import '../home/instructor_home_screen.dart';
import '../home/student_home_screen.dart';

const _primary = Color(0xFFF4773C);
const _scaffold = Color(0xFFFFF8EE);
const _inputFill = Color(0xFFFFF1DF);
const _border = Color(0xFFE8D7C2);
const _heading = Color(0xFF3B2419);

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  @override
  void initState() {
    super.initState();
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    final user = await AuthService().restoreSession();
    if (!mounted || user == null) return;
    final destination = user.role == 'instructor'
        ? InstructorHomeScreen(user: user)
        : StudentHomeScreen(user: user);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => destination),
      );
    });
  }

  void _openLogin() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
    );
  }

  void _openRegister() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const RegisterScreen()),
    );
  }

  void _openTeacherRegister() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const RegisterScreen(initialRole: 'instructor'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _scaffold,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    _TopNav(
                      onLogin: _openLogin,
                      onCreate: _openRegister,
                    ),
                    _HeroSection(
                      onSignUp: _openRegister,
                      onTeacher: _openTeacherRegister,
                    ),
                    const _FeatureCarousel(),
                    const _WhyEduSmartSection(),
                    const SizedBox(height: 56),
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

class _TopNav extends StatelessWidget {
  const _TopNav({
    required this.onLogin,
    required this.onCreate,
  });

  final VoidCallback onLogin;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 18),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final left = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _Brand(),
              const SizedBox(width: 24),
              _MenuButton(
                label: 'Study tools',
                items: const [
                  'AI Quiz Generator',
                  'Flashcards',
                  'Classrooms',
                ],
              ),
            ],
          );
          final actions = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(
                onPressed: onCreate,
                style: TextButton.styleFrom(
                  foregroundColor: _heading,
                  textStyle: const TextStyle(fontWeight: FontWeight.w700),
                ),
                child: const Text('Create'),
              ),
              const SizedBox(width: 4),
              FilledButton(
                onPressed: onLogin,
                style: FilledButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(100, 46),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: const Text('Log in'),
              ),
            ],
          );

          if (constraints.maxWidth < 560) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(alignment: Alignment.centerLeft, child: left),
                const SizedBox(height: 12),
                Align(alignment: Alignment.centerRight, child: actions),
              ],
            );
          }

          return Row(
            children: [left, const Spacer(), actions],
          );
        },
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: _primary,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.auto_stories_rounded, color: Colors.white),
        ),
        const SizedBox(width: 10),
        const Text(
          'EduSmart',
          style: TextStyle(
            color: _heading,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _MenuButton extends StatelessWidget {
  const _MenuButton({required this.label, required this.items});

  final String label;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: (_) {},
      itemBuilder: (context) => items
          .map((item) => PopupMenuItem<String>(value: item, child: Text(item)))
          .toList(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        child: Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                color: _heading,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Icon(Icons.keyboard_arrow_down, size: 18),
          ],
        ),
      ),
    );
  }
}

class _HeroSection extends StatelessWidget {
  const _HeroSection({required this.onSignUp, required this.onTeacher});

  final VoidCallback onSignUp;
  final VoidCallback onTeacher;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 72, 24, 70),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: _inputFill,
              borderRadius: BorderRadius.circular(30),
            ),
            child: const Text(
              'SMARTER STUDYING STARTS HERE',
              style: TextStyle(
                color: _primary,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'How do you want to study?',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _heading,
              fontSize: 42,
              height: 1.1,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 18),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: const Text(
              'Discover, create, and master your study material — all in one place. '
              'Generate quizzes with AI and hit your goals with EduSmart.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 17, height: 1.5),
            ),
          ),
          const SizedBox(height: 30),
          SizedBox(
            height: 56,
            child: FilledButton(
              onPressed: onSignUp,
              style: FilledButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 28),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: const Text(
                'Sign up',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 24,
            children: [
              _HeroLink(label: "I'm a teacher", onPressed: onTeacher),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroLink extends StatelessWidget {
  const _HeroLink({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      label: Text(label),
      style: TextButton.styleFrom(
        foregroundColor: _heading,
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _FeatureCarousel extends StatelessWidget {
  const _FeatureCarousel();

  @override
  Widget build(BuildContext context) {
    const features = [
      (
        title: 'AI Quiz Generation',
        description:
            'Turn your notes into smart practice questions in seconds.',
        icon: Icons.auto_awesome,
      ),
      (
        title: 'Flashcards',
        description: 'Build recall with focused cards made for your goals.',
        icon: Icons.style_outlined,
      ),
      (
        title: 'Live Classroom Quiz',
        description: 'Learn together and compete in real time with your class.',
        icon: Icons.groups_outlined,
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 600) {
          return Column(
            children: [
              for (var index = 0; index < features.length; index++) ...[
                SizedBox(
                  width: double.infinity,
                  height: 190,
                  child: _FeatureCard(
                    title: features[index].title,
                    description: features[index].description,
                    icon: features[index].icon,
                  ),
                ),
                if (index < features.length - 1) const SizedBox(height: 16),
              ],
            ],
          );
        }

        final cards = features
            .map(
              (feature) => SizedBox(
                width: 340,
                child: _FeatureCard(
                  title: feature.title,
                  description: feature.description,
                  icon: feature.icon,
                ),
              ),
            )
            .toList();
        if (constraints.maxWidth >= 1060) {
          return SizedBox(
            height: 220,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                cards[0],
                const SizedBox(width: 16),
                cards[1],
                const SizedBox(width: 16),
                cards[2],
              ],
            ),
          );
        }
        return SizedBox(
          height: 220,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: cards.length,
            separatorBuilder: (_, _) => const SizedBox(width: 16),
            itemBuilder: (context, index) => cards[index],
          ),
        );
      },
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.title,
    required this.description,
    required this.icon,
  });

  final String title;
  final String description;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: _border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _inputFill,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: _primary),
            ),
            const Spacer(),
            Text(
              title,
              style: const TextStyle(
                color: _heading,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(description, style: const TextStyle(height: 1.35)),
          ],
        ),
      ),
    );
  }
}

class _WhyEduSmartSection extends StatelessWidget {
  const _WhyEduSmartSection();

  @override
  Widget build(BuildContext context) {
    const benefits = [
      (
        icon: Icons.picture_as_pdf,
        title: 'Export to PDF',
        description:
            'Turn any AI quiz or flashcard set into a clean, printable PDF for handouts and review.',
      ),
      (
        icon: Icons.offline_bolt_outlined,
        title: 'Offline Quiz',
        description:
            'Download quizzes and study with zero internet. Progress syncs when you’re back online.',
      ),
      (
        icon: Icons.style_outlined,
        title: 'Flashcards',
        description:
            'Auto-generate flashcards from notes. Flip, shuffle, and master key terms.',
      ),
      (
        icon: Icons.leaderboard_outlined,
        title: 'Leaderboard',
        description:
            'Bragging rights included. Climb the leaderboard, outscore your classmates, and prove you’re the quiz champion.',
      ),
      (
        icon: Icons.emoji_events_outlined,
        title: 'Achievements',
        description:
            'Every study streak earns it. Collect badges and achievements as you master new topics.',
      ),
      (
        icon: Icons.groups_outlined,
        title: 'Classrooms for Teachers',
        description:
            'Create your classroom organization, invite students, and host a live quiz everyone takes together in real time.',
      ),
    ];
    return Padding(
      padding: const EdgeInsets.only(top: 72),
      child: Column(
        children: [
          const Text(
            'Why EduSmart?',
            style: TextStyle(
              color: _heading,
              fontSize: 32,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Everything you need to make every study session count.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 34),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 800 ? 3 : 1;
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: benefits.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  crossAxisSpacing: 18,
                  mainAxisSpacing: 18,
                  mainAxisExtent: 190,
                ),
                itemBuilder: (context, index) {
                  final benefit = benefits[index];
                  return _BenefitCard(
                    icon: benefit.icon,
                    title: benefit.title,
                    description: benefit.description,
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

class _BenefitCard extends StatelessWidget {
  const _BenefitCard({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: _primary, size: 28),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: _heading,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(description, style: const TextStyle(height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
