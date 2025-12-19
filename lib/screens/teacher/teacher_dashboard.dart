import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../config/firebase_config.dart';
import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common/rounded_card.dart';
import '../../widgets/common/empty_state.dart';
import '../../widgets/common/loading_indicator.dart';
import '../../widgets/student_progress_widget.dart';
import '../common/notifications_screen.dart';
import '../common/profile_screen.dart';

class TeacherDashboard extends StatefulWidget {
  const TeacherDashboard({super.key});

  @override
  State<TeacherDashboard> createState() => _TeacherDashboardState();
}

class _TeacherDashboardState extends State<TeacherDashboard> {
  List<ClassModel> _classes = [];
  bool _loading = true;
  String? _expandedClassId;
  int _currentTab = 0; // 0: Dashboard, 1: Notifications, 2: Profile

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
      if (mounted) {
        setState(() {
          _classes = snapshot.docs
              .map((doc) => ClassModel.fromFirestore(doc.data(), doc.id))
              .toList();
          _loading = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    if (authProvider.user == null || authProvider.userRole != 'teacher') {
      return const Scaffold(
        body: LoadingIndicator(),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.lightGrey,
      body: _buildBody(),
      bottomNavigationBar: _buildBottomNav(),
      floatingActionButton: _currentTab == 0
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.pushNamed(context, '/teacher/create-class'),
              icon: const Icon(Icons.add, size: 28),
              label: const Text(
                'Create Class',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              backgroundColor: AppTheme.primaryBlue,
            )
          : null,
    );
  }

  Widget _buildBody() {
    switch (_currentTab) {
      case 0:
        return _buildDashboardTab();
      case 1:
        return const NotificationsScreen();
      case 2:
        return const ProfileScreen();
      default:
        return _buildDashboardTab();
    }
  }

  // 🏠 TAB 1: DASHBOARD
  Widget _buildDashboardTab() {
    final totalStudents = _classes.fold(0, (sum, c) => sum + c.students.length);
    final totalMaterials = _classes.fold(0, (sum, c) => sum + c.materials.length);

    return SafeArea(
      child: CustomScrollView(
        slivers: [
          // Header
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.all(AppTheme.spacingL),
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.school_rounded, color: AppTheme.white, size: 32),
                      const SizedBox(width: AppTheme.spacingM),
                      const Expanded(
                        child: Text(
                          'Teacher Dashboard',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.white,
                            fontFamily: 'Roboto',
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Quick Stats
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spacingM),
              child: Row(
                children: [
                  Expanded(
                    child: RoundedCard(
                      padding: const EdgeInsets.all(AppTheme.spacingM),
                      child: Column(
                        children: [
                          const Icon(Icons.class_, color: AppTheme.primaryBlue, size: 32),
                          const SizedBox(height: AppTheme.spacingS),
                          Text(
                            '${_classes.length}',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                              fontFamily: 'Roboto',
                            ),
                          ),
                          const Text(
                            'Classes',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                              fontFamily: 'Roboto',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacingM),
                  Expanded(
                    child: RoundedCard(
                      padding: const EdgeInsets.all(AppTheme.spacingM),
                      child: Column(
                        children: [
                          const Icon(Icons.people, color: AppTheme.successGreen, size: 32),
                          const SizedBox(height: AppTheme.spacingS),
                          Text(
                            '$totalStudents',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                              fontFamily: 'Roboto',
                            ),
                          ),
                          const Text(
                            'Students',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                              fontFamily: 'Roboto',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacingM),
                  Expanded(
                    child: RoundedCard(
                      padding: const EdgeInsets.all(AppTheme.spacingM),
                      child: Column(
                        children: [
                          const Icon(Icons.insert_drive_file, color: Colors.orange, size: 32),
                          const SizedBox(height: AppTheme.spacingS),
                          Text(
                            '$totalMaterials',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                              fontFamily: 'Roboto',
                            ),
                          ),
                          const Text(
                            'Materials',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                              fontFamily: 'Roboto',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Classes Section
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spacingM),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'My Classes',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                      fontFamily: 'Roboto',
                    ),
                  ),
                  if (_classes.isNotEmpty)
                    Text(
                      '${_classes.length}',
                      style: const TextStyle(
                        fontSize: 16,
                        color: AppTheme.textSecondary,
                        fontFamily: 'Roboto',
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Classes List
          _loading
              ? const SliverFillRemaining(
                  child: LoadingIndicator(),
                )
              : _classes.isEmpty
                  ? SliverFillRemaining(
                      child: EmptyState(
                        icon: Icons.class_,
                        title: 'No Classes Yet',
                        message: 'Create your first class to get started!',
                        actionLabel: 'Create Class',
                        onAction: () => Navigator.pushNamed(context, '/teacher/create-class'),
                      ),
                    )
                  : SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppTheme.spacingM,
                            vertical: AppTheme.spacingS,
                          ),
                          child: _buildClassCard(_classes[index]),
                        ),
                        childCount: _classes.length,
                      ),
                    ),
        ],
      ),
    );
  }

  Widget _buildClassCard(ClassModel classModel) {
    return RoundedCard(
      padding: const EdgeInsets.all(AppTheme.spacingM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Class Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppTheme.spacingS),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusS),
                ),
                child: const Icon(Icons.class_, color: AppTheme.primaryBlue, size: 24),
              ),
              const SizedBox(width: AppTheme.spacingM),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      classModel.className,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                        fontFamily: 'Roboto',
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingXS),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.spacingS,
                        vertical: AppTheme.spacingXS,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryBlue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(AppTheme.radiusS),
                      ),
                      child: Text(
                        'Code: ${classModel.classCode}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryBlue,
                          fontFamily: 'Roboto',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (classModel.description.isNotEmpty) ...[
            const SizedBox(height: AppTheme.spacingM),
            Text(
              classModel.description,
              style: const TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondary,
                fontFamily: 'Roboto',
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],

          const SizedBox(height: AppTheme.spacingM),
          const Divider(),

          // Stats Row
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  Icons.people,
                  '${classModel.students.length}',
                  'Students',
                  AppTheme.successGreen,
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  Icons.insert_drive_file,
                  '${classModel.materials.length}',
                  'Materials',
                  AppTheme.primaryBlue,
                ),
              ),
            ],
          ),

          const SizedBox(height: AppTheme.spacingM),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.pushNamed(
                    context,
                    '/teacher/upload-material',
                    arguments: classModel.classCode,
                  ),
                  icon: const Icon(Icons.upload),
                  label: const Text('Upload Material'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primaryBlue,
                  ),
                ),
              ),
              const SizedBox(width: AppTheme.spacingM),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _expandedClassId = _expandedClassId == classModel.id
                          ? null
                          : classModel.id;
                    });
                  },
                  icon: Icon(
                    _expandedClassId == classModel.id
                        ? Icons.expand_less
                        : Icons.expand_more,
                  ),
                  label: const Text('Analytics'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlue,
                  ),
                ),
              ),
            ],
          ),

          // Student Progress (Expanded)
          if (_expandedClassId == classModel.id) ...[
            const SizedBox(height: AppTheme.spacingM),
            const Divider(),
            const SizedBox(height: AppTheme.spacingM),
            StudentProgressWidget(classCode: classModel.classCode),
          ],
        ],
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String value, String label, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: AppTheme.spacingXS),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
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
        ),
      ],
    );
  }

  // Bottom Navigation
  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        boxShadow: AppTheme.softShadow,
      ),
      child: BottomNavigationBar(
        currentIndex: _currentTab,
        onTap: (index) => setState(() => _currentTab = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppTheme.primaryBlue,
        unselectedItemColor: AppTheme.secondaryTextGrey,
        selectedFontSize: 12,
        unselectedFontSize: 12,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_rounded, size: 28),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications_outlined, size: 28),
            label: 'Notifications',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline, size: 28),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
