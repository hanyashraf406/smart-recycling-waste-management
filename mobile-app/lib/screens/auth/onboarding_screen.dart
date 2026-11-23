import 'package:flutter/material.dart';
import '../../models/onboarding_page.dart';
import '../../models/app_colors.dart';
import '../../widgets/trash_logo.dart';
import 'role_selection_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingPage> _pages = [
    OnboardingPage(
      title: 'Drop Off Your Recyclables',
      subtitle: 'Head to the nearest collection center and drop off your plastic, glass, metals, and more.',
      imagePath: 'assets/images/onboarding1.png',
    ),
    OnboardingPage(
      title: 'We Sort Everything for You',
      subtitle: 'Our team takes your materials, weighs them, and processes them for recycling.',
      imagePath: 'assets/images/onboarding2.png',
    ),
    OnboardingPage(
      title: 'Earn Points & Redeem Rewards',
      subtitle: 'Every drop-off gives you points. Use them for cash, discounts, or eco-friendly products.',
      imagePath: 'assets/images/onboarding3.png',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageController.addListener(() {
      setState(() {
        _currentPage = _pageController.page?.round() ?? 0;
      });
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToSelection() => Navigator.pushReplacementNamed(context, '/role-selection');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _goToSelection,
                    child: Text(
                      'Skip',
                      style: TextStyle(
                        color: theme.textTheme.bodyMedium?.color,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(bottom: 20),
              child: TrashLogo(size: 120),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _pages.length,
                itemBuilder: (context, index) => _buildPage(_pages[index]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_pages.length, (index) {
                  return Container(
                    width: _currentPage == index ? 24 : 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: _currentPage == index
                          ? AppColors.primary
                          : theme.dividerColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_currentPage > 0)
                    TextButton(
                      onPressed: () => _pageController.previousPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.arrow_back_rounded, size: 20, color: theme.textTheme.bodyMedium?.color),
                          const SizedBox(width: 8),
                          Text('Back', style: TextStyle(color: theme.textTheme.bodyMedium?.color, fontWeight: FontWeight.w600, fontSize: 16)),
                        ],
                      ),
                    )
                  else
                    const SizedBox(width: 100),
                  ElevatedButton(
                    onPressed: () {
                      if (_currentPage < _pages.length - 1) {
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      } else {
                        _goToSelection();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _currentPage < _pages.length - 1 ? 'Next' : 'Get Started',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          _currentPage < _pages.length - 1 ? Icons.arrow_forward_rounded : Icons.check_rounded,
                          size: 20,
                          color: Colors.white,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPage(OnboardingPage page) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 20),
              child: Image.asset(
                page.imagePath,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Center(
                    child: Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(Icons.image_not_supported, size: 60, color: theme.textTheme.bodySmall?.color),
                    ),
                  );
                },
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              page.title,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: theme.textTheme.bodyLarge?.color, height: 1.3),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: Text(
              page.subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: theme.textTheme.bodyMedium?.color, height: 1.6),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}