import 'package:shared_preferences/shared_preferences.dart';

/// Streak Service
/// Manages user streak tracking for consecutive days of app usage
class StreakService {
  static const String _keyLastActivityDate = 'last_activity_date';
  static const String _keyCurrentStreak = 'current_streak';
  static const String _keyLongestStreak = 'longest_streak';
  static const String _keyLastMilestone = 'last_milestone';

  /// Check and update streak on app launch
  /// Returns true if streak was incremented (new day)
  static Future<bool> checkAndUpdateStreak() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      final lastActivityStr = prefs.getString(_keyLastActivityDate);
      
      if (lastActivityStr == null) {
        // First time - initialize streak
        await prefs.setString(_keyLastActivityDate, today.toIso8601String());
        await prefs.setInt(_keyCurrentStreak, 1);
        await prefs.setInt(_keyLongestStreak, 1);
        return true;
      }

      final lastActivity = DateTime.parse(lastActivityStr);
      final lastActivityDate = DateTime(
        lastActivity.year,
        lastActivity.month,
        lastActivity.day,
      );

      final daysDifference = today.difference(lastActivityDate).inDays;

      if (daysDifference == 0) {
        // Same day - no change
        return false;
      } else if (daysDifference == 1) {
        // Next day - increment streak
        final currentStreak = prefs.getInt(_keyCurrentStreak) ?? 0;
        final newStreak = currentStreak + 1;
        
        await prefs.setString(_keyLastActivityDate, today.toIso8601String());
        await prefs.setInt(_keyCurrentStreak, newStreak);
        
        // Update longest streak if needed
        final longestStreak = prefs.getInt(_keyLongestStreak) ?? 0;
        if (newStreak > longestStreak) {
          await prefs.setInt(_keyLongestStreak, newStreak);
        }

        return true;
      } else {
        // More than 1 day gap - reset streak
        await prefs.setString(_keyLastActivityDate, today.toIso8601String());
        await prefs.setInt(_keyCurrentStreak, 1);
        return false;
      }
    } catch (e) {
      print('❌ [StreakService] Error checking streak: $e');
      return false;
    }
  }

  /// Increment streak (called when user performs qualifying action)
  /// This ensures streak is updated even if checkAndUpdateStreak wasn't called
  /// Returns true if streak was incremented (new day)
  static Future<bool> incrementStreak() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      final lastActivityStr = prefs.getString(_keyLastActivityDate);
      
      if (lastActivityStr == null) {
        // First time
        await prefs.setString(_keyLastActivityDate, today.toIso8601String());
        await prefs.setInt(_keyCurrentStreak, 1);
        await prefs.setInt(_keyLongestStreak, 1);
        return true;
      }

      final lastActivity = DateTime.parse(lastActivityStr);
      final lastActivityDate = DateTime(
        lastActivity.year,
        lastActivity.month,
        lastActivity.day,
      );

      final daysDifference = today.difference(lastActivityDate).inDays;

      if (daysDifference == 0) {
        // Same day - no change needed
        return false;
      } else if (daysDifference == 1) {
        // Next day - increment
        final currentStreak = prefs.getInt(_keyCurrentStreak) ?? 0;
        final newStreak = currentStreak + 1;
        
        await prefs.setString(_keyLastActivityDate, today.toIso8601String());
        await prefs.setInt(_keyCurrentStreak, newStreak);
        
        // Update longest streak
        final longestStreak = prefs.getInt(_keyLongestStreak) ?? 0;
        if (newStreak > longestStreak) {
          await prefs.setInt(_keyLongestStreak, newStreak);
        }
        return true;
      } else {
        // Gap - reset
        await prefs.setString(_keyLastActivityDate, today.toIso8601String());
        await prefs.setInt(_keyCurrentStreak, 1);
        return false;
      }
    } catch (e) {
      print('❌ [StreakService] Error incrementing streak: $e');
      return false;
    }
  }

  /// Get current streak count
  static Future<int> getCurrentStreak() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(_keyCurrentStreak) ?? 0;
    } catch (e) {
      print('❌ [StreakService] Error getting current streak: $e');
      return 0;
    }
  }

  /// Get longest streak ever achieved
  static Future<int> getLongestStreak() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(_keyLongestStreak) ?? 0;
    } catch (e) {
      print('❌ [StreakService] Error getting longest streak: $e');
      return 0;
    }
  }

  /// Get days until next milestone
  /// Milestones: 7, 30, 100 days
  static Future<int> getDaysUntilMilestone() async {
    try {
      final currentStreak = await getCurrentStreak();
      
      if (currentStreak < 7) {
        return 7 - currentStreak;
      } else if (currentStreak < 30) {
        return 30 - currentStreak;
      } else if (currentStreak < 100) {
        return 100 - currentStreak;
      } else {
        // Already reached all milestones
        return 0;
      }
    } catch (e) {
      print('❌ [StreakService] Error getting days until milestone: $e');
      return 0;
    }
  }

  /// Get next milestone value
  static Future<int> getNextMilestone() async {
    try {
      final currentStreak = await getCurrentStreak();
      
      if (currentStreak < 7) {
        return 7;
      } else if (currentStreak < 30) {
        return 30;
      } else if (currentStreak < 100) {
        return 100;
      } else {
        return 100; // Max milestone
      }
    } catch (e) {
      return 7;
    }
  }

  /// Check if streak reached a milestone
  static Future<bool> hasReachedMilestone(int streak) async {
    return streak == 7 || streak == 30 || streak == 100;
  }

  /// Check if a new milestone was reached and mark it
  /// Returns the milestone value if reached, null otherwise
  static Future<int?> checkForNewMilestone() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentStreak = await getCurrentStreak();
      final lastMilestone = prefs.getInt(_keyLastMilestone) ?? 0;

      if (currentStreak >= 7 && lastMilestone < 7) {
        await prefs.setInt(_keyLastMilestone, 7);
        return 7;
      } else if (currentStreak >= 30 && lastMilestone < 30) {
        await prefs.setInt(_keyLastMilestone, 30);
        return 30;
      } else if (currentStreak >= 100 && lastMilestone < 100) {
        await prefs.setInt(_keyLastMilestone, 100);
        return 100;
      }

      return null;
    } catch (e) {
      print('❌ [StreakService] Error checking milestone: $e');
      return null;
    }
  }

  /// Reset streak (for testing or user request)
  static Future<void> resetStreak() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyLastActivityDate);
      await prefs.setInt(_keyCurrentStreak, 0);
    } catch (e) {
      print('❌ [StreakService] Error resetting streak: $e');
    }
  }

  /// Get milestone progress (0.0 to 1.0)
  static Future<double> getMilestoneProgress() async {
    try {
      final currentStreak = await getCurrentStreak();
      final nextMilestone = await getNextMilestone();

      if (currentStreak >= nextMilestone) {
        return 1.0;
      }

      if (nextMilestone == 7) {
        return currentStreak / 7.0;
      } else if (nextMilestone == 30) {
        return currentStreak / 30.0;
      } else {
        return currentStreak / 100.0;
      }
    } catch (e) {
      return 0.0;
    }
  }
}

