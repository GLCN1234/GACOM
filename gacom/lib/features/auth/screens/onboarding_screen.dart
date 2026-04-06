import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  int _currentPage = 0;

  final _pages = [
    _OnboardingPage(
      icon: Icons.sports_esports_rounded,
      title: 'COMPETE &\nDOMINATE',
      subtitle: 'Join epic gaming competitions with real cash prizes. Prove you\'re the best.',
      gradient: [GacomColors.deepOrange, GacomColors.darkOrange],
    ),
    _OnboardingPage(
      icon: Icons.groups_rounded,
      title: 'BUILD YOUR\nCOMMAND',
      subtitle: 'Join gaming communities, create squads, and rise together.',
      gradient: [Color(0xFF1A1A1A), GacomColors.deepOrange],
    ),
    _OnboardingPage(
      icon: Icons.play_circle_fill_rounded,
      title: 'CREATE &\nGO VIRAL',
      subtitle: 'Share your gaming highlights. Create content that gets the world watching.',
      gradient: [GacomColors.darkOrange, Color(0xFF1A1A1A)],
    ),
    _OnboardingPage(
      icon: Icons.account_balance_wallet_rounded,
      title: 'WIN REAL\nMONEY',
      subtitle: 'Compete, win, and withdraw straight to your bank. Your skills pay the bills.',
      gradient: [GacomColors.deepOrange, Color(0xFF090909)],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GacomColors.obsidian,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            onPageChanged: (i) => setState(() => _currentPage = i),
            itemCount: _pages.length,
            itemBuilder: (context, i) => _buildPage(_pages[i]),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildBottomControls(),
          ),
        ],
      ),
    );
  }

  Widget _buildPage(_OnboardingPage page) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [GacomColors.obsidian, ...page.gradient],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const Spacer(),
              Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  color: GacomColors.deepOrange.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(40),
                  border: Border.all(
                    color: GacomColors.deepOrange.withOpacity(0.3),
                    width: 1.5,
                  ),
                ),
                child: Icon(
                  page.icon,
                  size: 70,
                  color: GacomColors.deepOrange,
                ),
              ).animate().scale(curve: Curves.elasticOut, duration: 700.ms),
              const SizedBox(height: 48),
              Text(
                page.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Rajdhani',
                  fontSize: 42,
                  fontWeight: FontWeight.w700,
                  color: GacomColors.textPrimary,
                  height: 1.1,
                  letterSpacing: 1,
                ),
              ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.3, end: 0),
              const SizedBox(height: 20),
              Text(
                page.subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  color: GacomColors.textSecondary,
                  height: 1.6,
                ),
              ).animate().fadeIn(delay: 400.ms),
              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomControls() {
    final isLast = _currentPage == _pages.length - 1;
    return Container(
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 48),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [GacomColors.obsidian.withOpacity(0), GacomColors.obsidian],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        children: [
          SmoothPageIndicator(
            controller: _pageController,
            count: _pages.length,
            effect: const ExpandingDotsEffect(
              activeDotColor: GacomColors.deepOrange,
              dotColor: GacomColors.border,
              dotHeight: 6,
              dotWidth: 6,
              expansionFactor: 4,
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 58,
            child: ElevatedButton(
              onPressed: () {
                if (isLast) {
                  context.go(AppConstants.loginRoute);
                } else {
                  _pageController.nextPage(
                    duration: 400.ms,
                    curve: Curves.easeInOut,
                  );
                }
              },
              child: Text(
                isLast ? 'JOIN THE ARENA' : 'NEXT',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2,
                ),
              ),
            ),
          ),
          if (!isLast) ...[
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => context.go(AppConstants.loginRoute),
              child: const Text(
                'Skip',
                style: TextStyle(color: GacomColors.textMuted),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _OnboardingPage {
  final IconData icon;
  final String title;
  final String subtitle;
  final List<Color> gradient;

  const _OnboardingPage({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.gradient,
  });
}
