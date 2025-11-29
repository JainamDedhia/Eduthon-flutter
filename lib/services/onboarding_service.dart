// FILE: lib/services/onboarding_service.dart
import 'package:shared_preferences/shared_preferences.dart';

class OnboardingService {
  static const String _studentDashboardKey = 'onboarding_student_dashboard_completed';
  static const String _teacherDashboardKey = 'onboarding_teacher_dashboard_completed';
  static const String _summaryQuizKey = 'onboarding_summary_quiz_completed';
  static const String _modelDownloadKey = 'onboarding_model_download_completed';
  static const String _joinClassKey = 'onboarding_join_class_completed';

  // Check if student dashboard onboarding is completed
  static Future<bool> isStudentDashboardCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_studentDashboardKey) ?? false;
  }

  // Mark student dashboard onboarding as completed
  static Future<void> markStudentDashboardCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_studentDashboardKey, true);
    print('✅ [Onboarding] Student dashboard onboarding completed');
  }

  // Check if teacher dashboard onboarding is completed
  static Future<bool> isTeacherDashboardCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_teacherDashboardKey) ?? false;
  }

  // Mark teacher dashboard onboarding as completed
  static Future<void> markTeacherDashboardCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_teacherDashboardKey, true);
    print('✅ [Onboarding] Teacher dashboard onboarding completed');
  }

  // Check if summary/quiz onboarding is completed
  static Future<bool> isSummaryQuizCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_summaryQuizKey) ?? false;
  }

  // Mark summary/quiz onboarding as completed
  static Future<void> markSummaryQuizCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_summaryQuizKey, true);
    print('✅ [Onboarding] Summary/Quiz onboarding completed');
  }

  // Check if model download onboarding is completed
  static Future<bool> isModelDownloadCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_modelDownloadKey) ?? false;
  }

  // Mark model download onboarding as completed
  static Future<void> markModelDownloadCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_modelDownloadKey, true);
    print('✅ [Onboarding] Model download onboarding completed');
  }

// Add to lib/services/onboarding_service.dart
static Future<bool> isResultScreenCompleted() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool('result_screen_onboarding_completed') ?? false;
}

static Future<void> markResultScreenCompleted() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool('result_screen_onboarding_completed', true);
}
  // Check if join class onboarding is completed
  static Future<bool> isJoinClassCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_joinClassKey) ?? false;
  }

  // Mark join class onboarding as completed
  static Future<void> markJoinClassCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_joinClassKey, true);
    print('✅ [Onboarding] Join class onboarding completed');
  }

  // Reset all onboarding (for testing)
  static Future<void> resetAllOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_studentDashboardKey);
    await prefs.remove(_teacherDashboardKey);
    await prefs.remove(_summaryQuizKey);
    await prefs.remove(_modelDownloadKey);
    await prefs.remove(_joinClassKey);
    print('🔄 [Onboarding] All onboarding reset');
  }

  // Check if ANY onboarding is needed
  static Future<bool> needsAnyOnboarding(String userRole) async {
    if (userRole == 'student') {
      return !(await isStudentDashboardCompleted());
    } else if (userRole == 'teacher') {
      return !(await isTeacherDashboardCompleted());
    }
    return false;
  }
}