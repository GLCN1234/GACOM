import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../widgets/gacom_widgets.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  int _currentPage = 0;

  final _pages = [
    _OnboardPage(
      title: 'COMPETE\nTO WIN',
      subtitle: 'Join epic gaming tournaments with real cash prizes. Show the world your skills.',
      icon: Icons.emoji_events_rounded,
      gradient: [const Color(0xFFE85D04), const Color(0xFF9B2226)],
    ),
    _OnboardPage(
      title: 'JOIN YOUR\nCOMM-UNITY',
      subtitle: 'Connect with gamers who love the same games. Build squads. Create communities.',
      icon: Icons.groups_rounded,
      gradient: [const Color(0xFF7B2FBE), const Color(0xFFE85D04)],
    ),
    _OnboardPage(
      title: 'CREATE &\nDOMINATE',
      subtitle: 'Share your gaming moments. Post clips. Go viral in the gaming world.',
      icon: Icons.videocam_rounded,
      gradient: [const Color(0xFF0D6EFD), const Color(0xFF7B2FBE)],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GacomColors.background,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: _pages.length,
            onPageChanged: (i) => setState(() => _currentPage = i),
            itemBuilder: (_, i) => _buildPage(_pages[i]),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildBottom(),
          ),
        ],
      ),
    );
  }

  Widget _buildPage(_OnboardPage page) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [GacomColors.background, GacomColors.background],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 120),
          Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: page.gradient),
              boxShadow: [BoxShadow(color: page.gradient[0].withOpacity(0.4), blurRadius: 60, spreadRadius: 10)],
            ),
            child: Icon(page.icon, size: 80, color: Colors.white),
          ).animate().scale(curve: Curves.elasticOut, duration: 800.ms),
          const SizedBox(height: 60),
          Text(
            page.title,
            textAlign: TextAlign.center,
            style: GoogleFonts.rajdhani(color: GacomColors.textPrimary, fontSize: 44, fontWeight: FontWeight.w900, height: 1),
          ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2, end: 0),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              page.subtitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(color: GacomColors.textSecondary, fontSize: 16, height: 1.6),
            ),
          ).animate().fadeIn(delay: 400.ms),
        ],
      ),
    );
  }

  Widget _buildBottom() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 48),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [GacomColors.background.withOpacity(0), GacomColors.background],
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              _pages.length,
              (i) => AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: _currentPage == i ? 24 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _currentPage == i ? GacomColors.primary : GacomColors.cardBorder,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
          GlowButton(
            text: _currentPage == _pages.length - 1 ? 'GET STARTED' : 'NEXT',
            width: double.infinity,
            onPressed: () {
              if (_currentPage == _pages.length - 1) {
                context.go('/login');
              } else {
                _pageController.nextPage(duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
              }
            },
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => context.go('/login'),
            child: Text('I already have an account',
              style: GoogleFonts.outfit(color: GacomColors.textSecondary, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardPage {
  final String title, subtitle;
  final IconData icon;
  final List<Color> gradient;
  _OnboardPage({required this.title, required this.subtitle, required this.icon, required this.gradient});
}
