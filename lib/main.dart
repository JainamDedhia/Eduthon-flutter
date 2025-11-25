import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'config/firebase_config.dart';
import 'providers/auth_provider.dart';
import 'services/offline_db.dart';
import 'screens/splash_screen.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/role_select_screen.dart';
import 'screens/student/student_dashboard.dart';
import 'screens/student/join_class_screen.dart';
import 'screens/teacher/teacher_dashboard.dart';
import 'screens/teacher/create_class_screen.dart';
import 'screens/teacher/upload_material_screen.dart';
import 'screens/student/summary_quiz_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await FirebaseConfig.initialize();
  
  // Initialize Offline DB
  await OfflineDB.init();
  
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
        title: 'GyaanSetu',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primarySwatch: Colors.blue,
          scaffoldBackgroundColor: const Color(0xFFF5F5F5),
          useMaterial3: true,
        ),
        initialRoute: '/',
        routes: {
  '/': (context) => const SplashScreen(),
  '/home': (context) => const HomeScreen(),
  '/login': (context) => const LoginScreen(),
  '/register': (context) => const RegisterScreen(),
  '/role-select': (context) => const RoleSelectScreen(),
  '/student/dashboard': (context) => const StudentDashboard(),
  '/student/join-class': (context) => const JoinClassScreen(),
  '/student/summary-quiz': (context) => const SummaryQuizScreen(),  // NEW!
  '/teacher/dashboard': (context) => const TeacherDashboard(),
  '/teacher/create-class': (context) => const CreateClassScreen(),
  '/teacher/upload-material': (context) => const UploadMaterialScreen(),
},
      ),
    );
  }
}