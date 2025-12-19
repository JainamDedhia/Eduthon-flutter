import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'config/firebase_config.dart';
import 'providers/auth_provider.dart';
import 'services/offline_db.dart';
import 'services/streak_service.dart';
import 'theme/app_theme.dart';
import 'screens/splash_screen.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/role_select_screen.dart';
import 'screens/student/student_dashboard.dart';
import 'screens/student/join_class_screen.dart';
import 'screens/student/summary_quiz_screen.dart';
import 'screens/student/model_download_screen.dart';
import 'screens/student/pdf_upload_screen.dart';
import 'screens/student/performance_report_screen.dart';
import 'screens/student/offline_content_screen.dart';
import 'screens/teacher/teacher_dashboard.dart';
import 'screens/teacher/create_class_screen.dart';
import 'screens/teacher/upload_material_screen.dart';
import 'screens/common/notifications_screen.dart';
import 'screens/common/profile_screen.dart';
import 'screens/common/settings_screen.dart';
import 'screens/common/privacy_notes_screen.dart';
import 'screens/common/help_support_screen.dart';
import 'package:claudetest/screens/student/chatbot_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await FirebaseConfig.initialize();
  
  // Initialize Offline DB
  await OfflineDB.init();
  
  // Check and update streak on app launch
  await StreakService.checkAndUpdateStreak();
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
      ],
      child: MaterialApp(
        title: 'GYAANSETU',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        initialRoute: '/',
        routes: {
          '/': (context) => const SplashScreen(),
          '/home': (context) => const HomeScreen(),
          '/login': (context) => const LoginScreen(),
          '/register': (context) => const RegisterScreen(),
          '/role-select': (context) => const RoleSelectScreen(),
          // Student routes
          '/student/dashboard': (context) => const StudentDashboard(),
          '/student/join-class': (context) => const JoinClassScreen(),
          '/student/summary-quiz': (context) => const SummaryQuizScreen(),
          '/student/model-download': (context) => const ModelDownloadScreen(),
          '/student/pdf-upload': (context) => const PdfUploadScreen(),
          '/student/performance-report': (context) => const PerformanceReportScreen(),
          '/student/offline-content': (context) => const OfflineContentScreen(),
          '/student/chatbot': (context) => const ChatbotScreen(),
          // Teacher routes
          '/teacher/dashboard': (context) => const TeacherDashboard(),
          '/teacher/create-class': (context) => const CreateClassScreen(),
          '/teacher/upload-material': (context) => const UploadMaterialScreen(),
          // Common routes
          '/privacy-notes': (context) => const PrivacyNotesScreen(),
          '/help-support': (context) => const HelpSupportScreen(),
        },
        onGenerateRoute: (settings) {
          // Custom page transitions
          return PageRouteBuilder(
            settings: settings,
            pageBuilder: (context, animation, secondaryAnimation) {
              switch (settings.name) {
                case '/':
                  return const SplashScreen();
                case '/home':
                  return const HomeScreen();
                case '/login':
                  return const LoginScreen();
                case '/register':
                  return const RegisterScreen();
                case '/role-select':
                  return const RoleSelectScreen();
                default:
                  return const SizedBox();
              }
            },
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(
                opacity: animation,
                child: child,
              );
            },
            transitionDuration: const Duration(milliseconds: 300),
          );
        },
      ),
    );
  }
}