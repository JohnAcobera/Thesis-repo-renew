import 'package:flutter/material.dart';

import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../auth/login_screen.dart';
import '../auth/register_screen.dart';
import '../home/instructor_home_screen.dart';
import '../home/student_home_screen.dart';

const _primary = Color(0xFFFF7434);
const _scaffold = Color(0xFFFFF8EE);
const _inputFill = Color(0xFFFFF1DF);
const _border = Color(0xFFE8D7C2);
const _heading = Color(0xFF3B2419);
const _body = Color(0xFF725F53);

class LandingScreen extends StatefulWidget {
  const LandingScreen({this.sessionRestorer, super.key});

  final Future<UserModel?> Function()? sessionRestorer;

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  bool _sessionRestoreFailed = false;

  @override
  void initState() {
    super.initState();
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    try {
      final user =
          await (widget.sessionRestorer ?? AuthService().restoreSession)();
      if (!mounted ||
          user == null ||
          ModalRoute.of(context)?.isCurrent != true) {
        return;
      }
      final destination = user.role == 'instructor'
          ? InstructorHomeScreen(user: user)
          : StudentHomeScreen(user: user);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;
        Navigator.of(
          context,
        ).pushReplacement(MaterialPageRoute<void>(builder: (_) => destination));
      });
    } on Exception {
      if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;
      setState(() => _sessionRestoreFailed = true);
    }
  }

  void _openLogin() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const LoginScreen()));
  }

  void _openRegister() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const RegisterScreen()));
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
                    if (_sessionRestoreFailed) ...[
                      const Padding(
                        padding: EdgeInsets.only(top: 16),
                        child: Text(
                          'Could not restore your saved session. You can still '
                          'log in.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Color(0xFFA33A2B)),
                        ),
                      ),
                    ],
                    LandingTopNav(onLogin: _openLogin),
                    _HeroSection(onSignUp: _openRegister),
                    const _FeatureCarousel(),
                    const _WhyQuizForgeSection(),
                    const SizedBox(height: 40),
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

class LandingTopNav extends StatelessWidget {
  const LandingTopNav({required this.onLogin, super.key});

  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 18),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 400;
          final actions = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              FilledButton(
                onPressed: onLogin,
                style: FilledButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                  minimumSize: Size(compact ? 88 : 100, compact ? 42 : 46),
                  padding: EdgeInsets.symmetric(horizontal: compact ? 14 : 24),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(compact ? 16 : 18),
                  ),
                ),
                child: const Text('Log in'),
              ),
            ],
          );

          return Row(
            children: [
              Expanded(child: _Brand(compact: compact)),
              actions,
            ],
          );
        },
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: compact ? 40 : 48,
          height: compact ? 40 : 48,
          decoration: BoxDecoration(
            color: _primary,
            borderRadius: BorderRadius.circular(compact ? 14 : 16),
          ),
          child: Icon(
            Icons.auto_stories_rounded,
            color: Colors.white,
            size: compact ? 21 : 24,
          ),
        ),
        SizedBox(width: compact ? 8 : 10),
        Flexible(
          child: Text(
            'QuizForge',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: _heading,
              fontSize: compact ? 18 : 20,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _HeroSection extends StatelessWidget {
  const _HeroSection({required this.onSignUp});

  final VoidCallback onSignUp;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 52),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF3E5),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: const Color(0xFFF0DDC5)),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 720;
            final copy = _HeroCopy(compact: compact, onSignUp: onSignUp);
            if (compact) {
              return Column(
                children: [
                  const _StudyIllustration(compact: true),
                  const SizedBox(height: 28),
                  copy,
                ],
              );
            }
            return Row(
              children: [
                Expanded(flex: 6, child: copy),
                const SizedBox(width: 40),
                const Expanded(flex: 5, child: _StudyIllustration()),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _HeroCopy extends StatelessWidget {
  const _HeroCopy({required this.compact, required this.onSignUp});

  final bool compact;
  final VoidCallback onSignUp;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: compact
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(30),
          ),
          child: const Text(
            'A BETTER WAY TO STUDY',
            style: TextStyle(
              color: _primary,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'How do you want to study?',
          textAlign: compact ? TextAlign.center : TextAlign.start,
          style: TextStyle(
            color: _heading,
            fontSize: compact ? 34 : 42,
            height: 1.12,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 16),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Text(
            'Explore your learning materials, practice at your own pace, '
            'and build confidence with every study session.',
            textAlign: compact ? TextAlign.center : TextAlign.start,
            style: const TextStyle(color: _body, fontSize: 16, height: 1.6),
          ),
        ),
        const SizedBox(height: 26),
        Wrap(
          alignment: compact ? WrapAlignment.center : WrapAlignment.start,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 16,
          runSpacing: 8,
          children: [
            FilledButton(
              onPressed: onSignUp,
              style: FilledButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(132, 50),
                padding: const EdgeInsets.symmetric(horizontal: 24),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'Get started',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StudyIllustration extends StatelessWidget {
  const _StudyIllustration({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: compact ? 188 : 240,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: compact ? 84 : 100,
              height: compact ? 84 : 100,
              decoration: BoxDecoration(
                color: _primary,
                borderRadius: BorderRadius.circular(28),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x26A84B20),
                    blurRadius: 20,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: Icon(
                Icons.auto_stories_rounded,
                color: Colors.white,
                size: compact ? 46 : 54,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'QuizForge',
              style: TextStyle(
                color: _heading,
                fontSize: compact ? 21 : 24,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
              ),
            ),
          ],
        ),
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
        title: 'Practice Questions',
        description:
            'Create helpful practice questions from your notes in seconds.',
        icon: Icons.auto_awesome,
      ),
      (
        title: 'Flashcards',
        description: 'Review key ideas with simple, focused study cards.',
        icon: Icons.style_outlined,
      ),
      (
        title: 'Classroom Activities',
        description: 'Learn and practice together with your classmates.',
        icon: Icons.groups_outlined,
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 900
            ? 3
            : constraints.maxWidth >= 560
            ? 2
            : 1;
        final cardWidth = (constraints.maxWidth - (columns - 1) * 16) / columns;
        return Column(
          children: [
            const _LandingSectionHeading(
              title: 'A simple way to keep learning',
              subtitle:
                  'Tools to help you practice, review, and learn together.',
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                for (final feature in features)
                  SizedBox(
                    width: cardWidth,
                    height: 188,
                    child: _FeatureCard(
                      title: feature.title,
                      description: feature.description,
                      icon: feature.icon,
                    ),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _LandingSectionHeading extends StatelessWidget {
  const _LandingSectionHeading({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: _heading,
            fontSize: 28,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(color: _body, fontSize: 15, height: 1.5),
        ),
      ],
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
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: _border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: _inputFill,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(icon, color: _primary, size: 23),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _heading,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: _body, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

class _WhyQuizForgeSection extends StatelessWidget {
  const _WhyQuizForgeSection();

  @override
  Widget build(BuildContext context) {
    const benefits = [
      (
        icon: Icons.picture_as_pdf,
        title: 'Printable Study Guides',
        description:
            'Prepare clear copies of quizzes and flashcards for review.',
      ),
      (
        icon: Icons.offline_bolt_outlined,
        title: 'Study Anywhere',
        description:
            'Keep learning with saved activities, even when you are away from a connection.',
      ),
      (
        icon: Icons.style_outlined,
        title: 'Flashcards',
        description:
            'Make study cards from your notes and review important ideas.',
      ),
      (
        icon: Icons.leaderboard_outlined,
        title: 'Track Your Progress',
        description:
            'See how far you have come and celebrate each learning milestone.',
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
            'Set up a classroom, invite students, and share activities together.',
      ),
    ];
    return Padding(
      padding: const EdgeInsets.only(top: 56),
      child: Column(
        children: [
          const _LandingSectionHeading(
            title: 'Why QuizForge?',
            subtitle: 'Everything you need to make every study session count.',
          ),
          const SizedBox(height: 24),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 980
                  ? 3
                  : constraints.maxWidth >= 620
                  ? 2
                  : 1;
              final cardWidth =
                  (constraints.maxWidth - (columns - 1) * 16) / columns;
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: benefits.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  mainAxisExtent: columns == 1 ? 176 : 188,
                ),
                itemBuilder: (context, index) {
                  final benefit = benefits[index];
                  return SizedBox(
                    width: cardWidth,
                    child: _BenefitCard(
                      icon: benefit.icon,
                      title: benefit.title,
                      description: benefit.description,
                    ),
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _inputFill,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: _primary, size: 22),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _heading,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: _body, height: 1.4),
          ),
        ],
      ),
    );
  }
}
