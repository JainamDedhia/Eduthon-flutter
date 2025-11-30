import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../config/firebase_config.dart';
import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/student_progress_widget.dart';
import '../../widgets/student_progress_card.dart';

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
              color: Colors.white,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Welcome, Teacher!',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        authProvider.user?.email ?? '',
                        style: const TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.logout, color: Colors.red),
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
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${_classes.length} classes',
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),

            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _classes.isEmpty
                      ? const Center(
                          child: Text(
                            'No classes yet. Create your first class!',
                            style: TextStyle(fontSize: 16, color: Colors.grey),
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
        backgroundColor: const Color(0xFF4A90E2),
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
                  ? const Color(0xFF4A90E2).withOpacity(0.1)
                  : Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.analytics,
                      color: const Color(0xFF4A90E2),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Student Progress Report',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isExpanded 
                            ? const Color(0xFF4A90E2)
                            : Colors.grey[800],
                      ),
                    ),
                  ],
                ),
                Icon(
                  isExpanded 
                      ? Icons.expand_less 
                      : Icons.expand_more,
                  color: const Color(0xFF4A90E2),
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
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFF4A90E2), width: 4),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              classModel.className,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (classModel.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                classModel.description,
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Code: ${classModel.classCode}',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF4A90E2),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${classModel.students.length} students',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
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
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4A90E2),
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
