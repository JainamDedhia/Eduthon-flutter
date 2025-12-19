import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/streak_service.dart';
import '../../widgets/common/rounded_card.dart';

/// Streak Badge - Small badge for dashboard header
class StreakBadge extends StatefulWidget {
  const StreakBadge({super.key});

  @override
  State<StreakBadge> createState() => _StreakBadgeState();
}

class _StreakBadgeState extends State<StreakBadge> {
  int _streak = 0;

  @override
  void initState() {
    super.initState();
    _loadStreak();
  }

  Future<void> _loadStreak() async {
    final streak = await StreakService.getCurrentStreak();
    if (mounted) {
      setState(() => _streak = streak);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_streak == 0) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingM,
        vertical: AppTheme.spacingXS,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.orange, Colors.red],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusXL),
        boxShadow: AppTheme.softShadow,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.local_fire_department,
            color: AppTheme.white,
            size: 18,
          ),
          const SizedBox(width: AppTheme.spacingXS),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Text(
              '$_streak',
              key: ValueKey(_streak),
              style: const TextStyle(
                color: AppTheme.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
                fontFamily: 'Roboto',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Streak Card - Full card for profile screen
class StreakCard extends StatefulWidget {
  const StreakCard({super.key});

  @override
  State<StreakCard> createState() => _StreakCardState();
}

class _StreakCardState extends State<StreakCard> {
  int _currentStreak = 0;
  int _longestStreak = 0;
  int _daysUntilMilestone = 0;
  int _nextMilestone = 7;
  double _progress = 0.0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadStreakData();
  }

  Future<void> _loadStreakData() async {
    setState(() => _loading = true);
    
    final current = await StreakService.getCurrentStreak();
    final longest = await StreakService.getLongestStreak();
    final daysUntil = await StreakService.getDaysUntilMilestone();
    final nextMilestone = await StreakService.getNextMilestone();
    final progress = await StreakService.getMilestoneProgress();

    if (mounted) {
      setState(() {
        _currentStreak = current;
        _longestStreak = longest;
        _daysUntilMilestone = daysUntil;
        _nextMilestone = nextMilestone;
        _progress = progress;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const RoundedCard(
        padding: EdgeInsets.all(AppTheme.spacingL),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return RoundedCard(
      padding: const EdgeInsets.all(AppTheme.spacingL),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.orange.withOpacity(0.1),
              Colors.red.withOpacity(0.1),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(AppTheme.radiusL),
        ),
        padding: const EdgeInsets.all(AppTheme.spacingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppTheme.spacingS),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.orange, Colors.red],
                    ),
                    borderRadius: BorderRadius.circular(AppTheme.radiusM),
                  ),
                  child: const Icon(
                    Icons.local_fire_department,
                    color: AppTheme.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: AppTheme.spacingM),
                const Expanded(
                  child: Text(
                    'Current Streak',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                      fontFamily: 'Roboto',
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppTheme.spacingL),

            // Streak Number
            Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 500),
                transitionBuilder: (child, animation) {
                  return ScaleTransition(
                    scale: animation,
                    child: child,
                  );
                },
                child: Text(
                  '$_currentStreak',
                  key: ValueKey(_currentStreak),
                  style: TextStyle(
                    fontSize: 64,
                    fontWeight: FontWeight.bold,
                    foreground: Paint()
                      ..shader = LinearGradient(
                        colors: [Colors.orange, Colors.red],
                      ).createShader(
                        const Rect.fromLTWH(0, 0, 200, 70),
                      ),
                    fontFamily: 'Roboto',
                  ),
                ),
              ),
            ),

            const SizedBox(height: AppTheme.spacingS),
            const Center(
              child: Text(
                'days',
                style: TextStyle(
                  fontSize: 16,
                  color: AppTheme.textSecondary,
                  fontFamily: 'Roboto',
                ),
              ),
            ),

            const SizedBox(height: AppTheme.spacingL),
            const Divider(),

            // Stats Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(
                  'Longest',
                  '$_longestStreak',
                  Icons.trending_up,
                ),
                _buildStatItem(
                  'Next Goal',
                  '$_nextMilestone',
                  Icons.flag,
                ),
              ],
            ),

            const SizedBox(height: AppTheme.spacingL),

            // Progress Bar
            if (_daysUntilMilestone > 0) ...[
              Text(
                '$_daysUntilMilestone days until $_nextMilestone-day milestone',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                  fontFamily: 'Roboto',
                ),
              ),
              const SizedBox(height: AppTheme.spacingS),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppTheme.radiusM),
                child: LinearProgressIndicator(
                  value: _progress,
                  minHeight: 8,
                  backgroundColor: AppTheme.lightGrey,
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.orange),
                ),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(AppTheme.spacingS),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusS),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.emoji_events, color: Colors.orange, size: 20),
                    SizedBox(width: AppTheme.spacingS),
                    Text(
                      'All milestones achieved!',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Roboto',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.orange, size: 24),
        const SizedBox(height: AppTheme.spacingXS),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
            fontFamily: 'Roboto',
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppTheme.textSecondary,
            fontFamily: 'Roboto',
          ),
        ),
      ],
    );
  }
}

