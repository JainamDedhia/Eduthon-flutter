import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/buttons.dart';
import '../widgets/gyaansetu_logo.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFFF3E7),
              Color(0xFFF8F7F4),
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 26),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Center(child: GyaanSetuLogo()),
                const SizedBox(height: 28),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.outline),
                    boxShadow: [
                      BoxShadow(
                        blurRadius: 20,
                        color: Colors.black.withValues(alpha: 0.05),
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Learn anywhere',
                        style: AppTextStyles.headline,
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Offline-first classes, AI summaries, multilingual support, and rich downloads for students and teachers.',
                        style: AppTextStyles.body,
                      ),
                      SizedBox(height: 14),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _Pill(label: 'Offline ready', icon: Icons.wifi_off),
                          _Pill(label: 'AI assistance', icon: Icons.auto_awesome),
                          _Pill(label: 'Secure sync', icon: Icons.lock_clock),
                          _Pill(label: 'Downloads', icon: Icons.download_done),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 26),
                PrimaryButton(
                  label: 'Login',
                  leading: const Icon(Icons.login_rounded, color: Colors.white),
                  onPressed: () => Navigator.pushNamed(context, '/login'),
                ),
                const SizedBox(height: 14),
                SecondaryButton(
                  label: 'Create an account',
                  leading: const Icon(Icons.person_add_alt_1, color: AppColors.primary),
                  onPressed: () => Navigator.pushNamed(context, '/register'),
                ),
                const SizedBox(height: 32),
                const Text('Why GyaanSetu', style: AppTextStyles.headline),
                const SizedBox(height: 14),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isNarrow = constraints.maxWidth < 520;
                    final crossAxisCount = isNarrow ? 2 : 3;
                    final aspectRatio = isNarrow ? 0.95 : 1.05;
                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: 4,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: aspectRatio,
                      ),
                      itemBuilder: (context, index) {
                        const items = [
                          _FeatureCardData(
                            icon: Icons.offline_bolt,
                            title: 'Offline-first',
                            description: 'Download classes and learn without data.',
                          ),
                          _FeatureCardData(
                            icon: Icons.g_translate,
                            title: 'Multilingual',
                            description: 'Translate notes to your preferred language.',
                          ),
                          _FeatureCardData(
                            icon: Icons.quiz_outlined,
                            title: 'AI quizzes',
                            description: 'Generate quizzes & mind-maps in one tap.',
                          ),
                          _FeatureCardData(
                            icon: Icons.shield_moon_outlined,
                            title: 'Secure sync',
                            description: 'Keep progress safe across devices.',
                          ),
                        ];
                        final item = items[index];
                        return _FeatureCard(
                          icon: item.icon,
                          title: item.title,
                          description: item.description,
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: AppColors.primary),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: AppTextStyles.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: AppTextStyles.body,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureCardData {
  final IconData icon;
  final String title;
  final String description;

  const _FeatureCardData({
    required this.icon,
    required this.title,
    required this.description,
  });
}

class _Pill extends StatelessWidget {
  final String label;
  final IconData icon;

  const _Pill({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(label),
        ],
      ),
      backgroundColor: AppColors.surfaceMuted,
      side: const BorderSide(color: AppColors.outline),
    );
  }
}