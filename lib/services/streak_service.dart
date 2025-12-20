// FILE: lib/services/streak_service.dart
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';

class StreakService {
  static const String _currentStreakKey = 'student_current_streak';
  static const String _bestStreakKey = 'student_best_streak';
  static const String _lastActivityDateKey = 'student_last_activity_date';
  static const String _totalActiveDaysKey = 'student_total_active_days';

  // Get current streak
  static Future<int> getCurrentStreak() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_currentStreakKey) ?? 0;
  }

  // Get best streak
  static Future<int> getBestStreak() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_bestStreakKey) ?? 0;
  }

  // Get last activity date
  static Future<DateTime?> getLastActivityDate() async {
    final prefs = await SharedPreferences.getInstance();
    final dateString = prefs.getString(_lastActivityDateKey);
    if (dateString == null) return null;
    return DateTime.parse(dateString);
  }

  // Get total active days
  static Future<int> getTotalActiveDays() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_totalActiveDaysKey) ?? 0;
  }

  // Record activity - call this whenever student does any learning activity
  static Future<StreakUpdate> recordActivity() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    // Get last activity date
    final lastActivityDate = await getLastActivityDate();
    final lastDate = lastActivityDate != null
        ? DateTime(lastActivityDate.year, lastActivityDate.month, lastActivityDate.day)
        : null;

    int currentStreak = await getCurrentStreak();
    int bestStreak = await getBestStreak();
    int totalActiveDays = await getTotalActiveDays();
    
    bool streakIncreased = false;
    bool reachedMilestone = false;
    String? milestoneMessage;

    // Check if activity is for today
    if (lastDate == null || lastDate.isBefore(today)) {
      // New day activity
      
      if (lastDate == null) {
        // First time ever
        currentStreak = 1;
        totalActiveDays = 1;
        streakIncreased = true;
      } else {
        // Check if yesterday
        final yesterday = today.subtract(Duration(days: 1));
        
        if (lastDate == yesterday) {
          // Consecutive day - increase streak
          currentStreak++;
          totalActiveDays++;
          streakIncreased = true;
          
          // Check for milestones
          final milestone = _getMilestone(currentStreak);
          if (milestone != null) {
            reachedMilestone = true;
            milestoneMessage = milestone;
          }
        } else {
          // Missed days - reset streak
          currentStreak = 1;
          totalActiveDays++;
          streakIncreased = false;
        }
      }

      // Update best streak if needed
      if (currentStreak > bestStreak) {
        bestStreak = currentStreak;
        await prefs.setInt(_bestStreakKey, bestStreak);
      }

      // Save updated values
      await prefs.setInt(_currentStreakKey, currentStreak);
      await prefs.setInt(_totalActiveDaysKey, totalActiveDays);
      await prefs.setString(_lastActivityDateKey, today.toIso8601String());

      print('✅ [Streak] Activity recorded: Day $currentStreak (Best: $bestStreak)');

      return StreakUpdate(
        currentStreak: currentStreak,
        bestStreak: bestStreak,
        totalActiveDays: totalActiveDays,
        streakIncreased: streakIncreased,
        reachedMilestone: reachedMilestone,
        milestoneMessage: milestoneMessage,
      );
    } else {
      // Already did activity today
      print('ℹ️ [Streak] Activity already recorded for today');
      return StreakUpdate(
        currentStreak: currentStreak,
        bestStreak: bestStreak,
        totalActiveDays: totalActiveDays,
        streakIncreased: false,
        reachedMilestone: false,
      );
    }
  }

  // Get streak status (for checking if streak is at risk)
  static Future<StreakStatus> getStreakStatus() async {
    final lastActivityDate = await getLastActivityDate();
    if (lastActivityDate == null) {
      return StreakStatus.none;
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final lastDate = DateTime(
      lastActivityDate.year,
      lastActivityDate.month,
      lastActivityDate.day,
    );

    final daysDifference = today.difference(lastDate).inDays;

    if (daysDifference == 0) {
      return StreakStatus.active; // Activity done today
    } else if (daysDifference == 1) {
      return StreakStatus.atRisk; // Need to do activity today to maintain
    } else {
      return StreakStatus.lost; // Streak is lost
    }
  }

  // Get motivational message based on streak
  static String getMotivationalMessage(int streak) {
    if (streak == 0) {
      return "Start your learning journey today! 🚀";
    } else if (streak == 1) {
      return "Great start! Keep it going tomorrow! 💪";
    } else if (streak < 7) {
      return "You're on fire! $streak days strong! 🔥";
    } else if (streak < 30) {
      return "Amazing dedication! $streak days in a row! 🌟";
    } else if (streak < 100) {
      return "You're unstoppable! $streak days! 🏆";
    } else {
      return "LEGEND! $streak days of learning! 👑";
    }
  }

  // Get milestone message
  static String? _getMilestone(int streak) {
    switch (streak) {
      case 3:
        return "🔥 3 Day Streak! Getting Started!";
      case 7:
        return "🎉 7 Day Streak! Week Warrior!";
      case 14:
        return "💪 14 Day Streak! Two Weeks Strong!";
      case 30:
        return "🏆 30 Day Streak! Monthly Master!";
      case 50:
        return "⭐ 50 Day Streak! Halfway to Century!";
      case 100:
        return "👑 100 Day Streak! Century Champion!";
      case 365:
        return "🎊 365 Day Streak! YEARLY LEGEND!";
      default:
        return null;
    }
  }

  // Get emoji for streak
  static String getStreakEmoji(int streak) {
    if (streak == 0) return "💤";
    if (streak < 3) return "🔥";
    if (streak < 7) return "🔥🔥";
    if (streak < 30) return "🔥🔥🔥";
    if (streak < 100) return "🔥🔥🔥🔥";
    return "🔥🔥🔥🔥🔥";
  }

  // Reset streak (for testing or user request)
  static Future<void> resetStreak() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_currentStreakKey, 0);
    await prefs.remove(_lastActivityDateKey);
    print('🔄 [Streak] Streak reset');
  }

  // Get all streak data
  static Future<StreakData> getStreakData() async {
    final currentStreak = await getCurrentStreak();
    final bestStreak = await getBestStreak();
    final totalActiveDays = await getTotalActiveDays();
    final lastActivityDate = await getLastActivityDate();
    final status = await getStreakStatus();

    return StreakData(
      currentStreak: currentStreak,
      bestStreak: bestStreak,
      totalActiveDays: totalActiveDays,
      lastActivityDate: lastActivityDate,
      status: status,
      motivationalMessage: getMotivationalMessage(currentStreak),
      streakEmoji: getStreakEmoji(currentStreak),
    );
  }
}

// Streak Update Result
class StreakUpdate {
  final int currentStreak;
  final int bestStreak;
  final int totalActiveDays;
  final bool streakIncreased;
  final bool reachedMilestone;
  final String? milestoneMessage;

  StreakUpdate({
    required this.currentStreak,
    required this.bestStreak,
    required this.totalActiveDays,
    required this.streakIncreased,
    required this.reachedMilestone,
    this.milestoneMessage,
  });
}

// Streak Status
enum StreakStatus {
  none, // No activity yet
  active, // Did activity today
  atRisk, // Haven't done activity today yet
  lost, // Missed yesterday, streak is broken
}

// Complete Streak Data
class StreakData {
  final int currentStreak;
  final int bestStreak;
  final int totalActiveDays;
  final DateTime? lastActivityDate;
  final StreakStatus status;
  final String motivationalMessage;
  final String streakEmoji;

  StreakData({
    required this.currentStreak,
    required this.bestStreak,
    required this.totalActiveDays,
    required this.lastActivityDate,
    required this.status,
    required this.motivationalMessage,
    required this.streakEmoji,
  });

  String get statusText {
    switch (status) {
      case StreakStatus.none:
        return "Start your streak today!";
      case StreakStatus.active:
        return "✅ Active today";
      case StreakStatus.atRisk:
        return "⚠️ Complete an activity today!";
      case StreakStatus.lost:
        return "❌ Streak lost - Start fresh!";
    }
  }

  Color get statusColor {
    switch (status) {
      case StreakStatus.none:
        return const Color(0xFF9E9E9E);
      case StreakStatus.active:
        return const Color(0xFF4CAF50);
      case StreakStatus.atRisk:
        return const Color(0xFFFF9800);
      case StreakStatus.lost:
        return const Color(0xFFF44336);
    }
  }
}