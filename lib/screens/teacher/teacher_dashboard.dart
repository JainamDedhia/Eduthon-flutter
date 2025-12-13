import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../config/firebase_config.dart';
import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/student_progress_widget.dart';
import '../../widgets/student_progress_card.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

class TeacherDashboard extends StatefulWidget {
  const TeacherDashboard({super.key});

  @override
  State<TeacherDashboard> createState() => _TeacherDashboardState();
}

class _TeacherDashboardState extends State<TeacherDashboard> {
  List<ClassModel> _classes = [];
  bool _loading = true;
  String? _expandedClassId; // Track which class card is expanded

  @override
  void initState() {
    super.initState();
    _listenToClasses();
  }

  void _listenToClasses() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.user?.uid;

    if (userId == null) {
      setState(() => _loading = false);
      return;
    }

    FirebaseConfig.firestore
        .collection('classes')
        .where('teacherId', isEqualTo: userId)
        .snapshots()
        .listen((snapshot) {
      setState(() {
        _classes = snapshot.docs
            .map((doc) => ClassModel.fromFirestore(doc.data(), doc.id))
            .toList();
        _loading = false;
      });
    });
  }

  Future<void> _handleLogout() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              final authProvider =
                  Provider.of<AuthProvider>(context, listen: false);
              await authProvider.logout();
              if (mounted) {
                Navigator.pushNamedAndRemoveUntil(
                    context, '/home', (route) => false);
              }
            },
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryDark],
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Welcome, Teacher!',
                        style: AppTextStyles.headline.copyWith(color: Colors.white),
                      ),
                      Text(
                        authProvider.user?.email ?? '',
                        style: AppTextStyles.body.copyWith(color: Colors.white70),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.logout, color: Colors.white),
                    onPressed: _handleLogout,
                  ),
                ],
              ),
            ),

            // Classes Section
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'My Classes',
                    style: AppTextStyles.title,
                  ),
                  Text(
                    '${_classes.length} classes',
                    style: AppTextStyles.body.copyWith(color: AppColors.textMuted),
                  ),
                ],
              ),
            ),

            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _classes.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.class_, size: 64, color: AppColors.outline),
                              SizedBox(height: 10),
                              Text(
                                'No classes yet. Create your first class!',
                                style: AppTextStyles.body,
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: _classes.length,
                          itemBuilder: (context, index) =>
                              _buildClassCard(_classes[index]),
                        ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.pushNamed(context, '/teacher/create-class'),
        icon: const Icon(Icons.add),
        label: const Text('Create New Class'),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  Widget _buildProgressSection(ClassModel classModel) {
    final isExpanded = _expandedClassId == classModel.id;
    
    return Column(
      children: [
        InkWell(
          onTap: () {
            setState(() {
              _expandedClassId = isExpanded ? null : classModel.id;
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(
              color: isExpanded 
                  ? AppColors.primary.withOpacity(0.12)
                  : AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.analytics,
                      color: AppColors.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Student Progress Report',
                      style: AppTextStyles.body.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isExpanded ? AppColors.primary : AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                Icon(
                  isExpanded 
                      ? Icons.expand_less 
                      : Icons.expand_more,
                  color: AppColors.primary,
                ),
              ],
            ),
          ),
        ),
        
        // Progress Widget (shown when expanded)
        if (isExpanded) ...[
          const SizedBox(height: 16),
          StudentProgressWidget(classCode: classModel.classCode),
        ],
      ],
    );
  }

  Widget _buildClassCard(ClassModel classModel) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.outline),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              classModel.className,
              style: AppTextStyles.title,
            ),
            if (classModel.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                classModel.description,
                style: AppTextStyles.body,
              ),
            ],
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Code: ${classModel.classCode}',
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '${classModel.students.length} students',
                  style: AppTextStyles.caption,
                ),
              ],
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => Navigator.pushNamed(
                context,
                '/teacher/upload-material',
                arguments: classModel.classCode,
              ),
              child: const Text('Upload Material'),
            ),
            
            // Divider before progress section
            const Divider(height: 24),
            
            // Expandable Student Progress Section
            _buildProgressSection(classModel),
          ],
        ),
      ),
    );
  }
}
