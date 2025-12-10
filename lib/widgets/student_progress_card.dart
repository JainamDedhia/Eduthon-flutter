import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/models.dart';
import 'dart:math';

class StudentProgressCard extends StatefulWidget {
  final String classCode;
  final int enrolledStudentsCount;

  const StudentProgressCard({
    super.key,
    required this.classCode,
    required this.enrolledStudentsCount,
  });

  @override
  State<StudentProgressCard> createState() => _StudentProgressCardState();
}

class _StudentProgressCardState extends State<StudentProgressCard>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late ClassAnalytics _analytics;
  int _touchedIndex = -1;

  @override
  void initState() {
    super.initState();
    _analytics = _generateMockData();
  }

  // Generate realistic mock data for demonstration
  ClassAnalytics _generateMockData() {
    final random = Random(widget.classCode.hashCode);
    final studentCount = widget.enrolledStudentsCount > 0 
        ? widget.enrolledStudentsCount 
        : random.nextInt(15) + 5;

    final firstNames = [
      'Aarav', 'Vivaan', 'Aditya', 'Arjun', 'Sai', 'Krishna',
      'Diya', 'Ananya', 'Saanvi', 'Aadhya', 'Kavya', 'Sara',
      'Rohan', 'Ishaan', 'Advait', 'Reyansh', 'Priya', 'Riya',
      'Ayaan', 'Atharv', 'Kiara', 'Ira', 'Myra', 'Navya'
    ];
    
    final lastNames = [
      'Sharma', 'Verma', 'Patel', 'Kumar', 'Singh', 'Reddy',
      'Gupta', 'Iyer', 'Nair', 'Menon', 'Joshi', 'Desai',
      'Mehta', 'Shah', 'Agarwal', 'Chopra', 'Kapoor', 'Malhotra'
    ];

    final students = List.generate(studentCount, (index) {
      final firstName = firstNames[random.nextInt(firstNames.length)];
      final lastName = lastNames[random.nextInt(lastNames.length)];
      final name = '$firstName $lastName';
      final email = '${firstName.toLowerCase()}.${lastName.toLowerCase()}@student.edu';
      
      // Some students haven't taken quizzes
      final hasTakenQuiz = random.nextDouble() > 0.2;
      final quizzesTaken = hasTakenQuiz ? random.nextInt(8) + 1 : 0;
      
      // Score varies realistically
      double score = 0;
      if (hasTakenQuiz) {
        // Generate scores with normal distribution around 75%
        score = 75 + (random.nextDouble() - 0.5) * 40;
        score = score.clamp(35.0, 100.0);
      }
      
      // Activity within last 30 days for active students
      final daysAgo = random.nextInt(45);
      final isActive = daysAgo < 14;
      final lastActivity = DateTime.now().subtract(Duration(days: daysAgo));

      return StudentProgressModel(
        studentId: 'student_$index',
        name: name,
        email: email,
        quizzesTaken: quizzesTaken,
        averageScore: score,
        lastActivityDate: lastActivity,
        isActive: isActive,
      );
    });

    return ClassAnalytics.fromStudents(students);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(top: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300, width: 1),
      ),
      child: Column(
        children: [
          // Header - Expandable Toggle
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    Icons.analytics_outlined,
                    color: const Color(0xFF4A90E2),
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Student Progress Analytics',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF4A90E2),
                    ),
                  ),
                  const Spacer(),
                  AnimatedRotation(
                    duration: const Duration(milliseconds: 200),
                    turns: _isExpanded ? 0.5 : 0,
                    child: Icon(
                      Icons.keyboard_arrow_down,
                      color: const Color(0xFF4A90E2),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Expandable Content
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 300),
            crossFadeState: _isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox.shrink(),
            secondChild: _analytics.totalStudents == 0
                ? _buildEmptyState()
                : _buildAnalyticsContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Icon(
            Icons.people_outline,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No Students Enrolled Yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Share the class code with students to get started',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsContent() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary Statistics
          _buildSummaryStats(),
          
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),
          
          // Bar Chart
          _buildChartSection(),
          
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),
          
          // Student List
          _buildStudentList(),
        ],
      ),
    );
  }

  Widget _buildSummaryStats() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Total Students',
            '${_analytics.totalStudents}',
            Icons.people,
            Colors.blue,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildStatCard(
            'Avg Score',
            '${_analytics.averageClassScore.toStringAsFixed(1)}%',
            Icons.trending_up,
            Colors.green,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildStatCard(
            'Completion',
            '${_analytics.completionRate.toStringAsFixed(0)}%',
            Icons.check_circle,
            Colors.orange,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildStatCard(
            'Active',
            '${_analytics.activeStudents}',
            Icons.person_outline,
            Colors.purple,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade700,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildChartSection() {
    // Get top 10 students by score
    final topStudents = List<StudentProgressModel>.from(_analytics.students)
      ..sort((a, b) => b.averageScore.compareTo(a.averageScore));
    
    final chartStudents = topStudents
        .where((s) => s.quizzesTaken > 0)
        .take(10)
        .toList();

    if (chartStudents.isEmpty) {
      return Container(
        height: 200,
        alignment: Alignment.center,
        child: Text(
          'No quiz data available yet',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Top Student Performance',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 280,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: 100,
              barTouchData: BarTouchData(
                enabled: true,
                touchCallback: (FlTouchEvent event, barTouchResponse) {
                  setState(() {
                    if (!event.isInterestedForInteractions ||
                        barTouchResponse == null ||
                        barTouchResponse.spot == null) {
                      _touchedIndex = -1;
                      return;
                    }
                    _touchedIndex = barTouchResponse.spot!.touchedBarGroupIndex;
                  });
                },
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (group) => Colors.black87,
                  tooltipPadding: const EdgeInsets.all(8),
                  tooltipMargin: 8,
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final student = chartStudents[groupIndex];
                    return BarTooltipItem(
                      '${student.name}\n',
                      const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                      children: [
                        TextSpan(
                          text: 'Score: ${student.averageScore.toStringAsFixed(1)}%\n',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.normal,
                          ),
                        ),
                        TextSpan(
                          text: 'Quizzes: ${student.quizzesTaken}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.normal,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              titlesData: FlTitlesData(
                show: true,
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      if (value.toInt() >= chartStudents.length) {
                        return const SizedBox.shrink();
                      }
                      final student = chartStudents[value.toInt()];
                      final firstName = student.name.split(' ').first;
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          firstName,
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 10,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    },
                    reservedSize: 32,
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      return Text(
                        '${value.toInt()}%',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 10,
                        ),
                      );
                    },
                    reservedSize: 40,
                  ),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
              ),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: 20,
                getDrawingHorizontalLine: (value) {
                  return FlLine(
                    color: Colors.grey.shade300,
                    strokeWidth: 1,
                  );
                },
              ),
              borderData: FlBorderData(
                show: true,
                border: Border(
                  bottom: BorderSide(color: Colors.grey.shade400),
                  left: BorderSide(color: Colors.grey.shade400),
                ),
              ),
              barGroups: chartStudents.asMap().entries.map((entry) {
                final index = entry.key;
                final student = entry.value;
                return BarChartGroupData(
                  x: index,
                  barRods: [
                    BarChartRodData(
                      toY: student.averageScore,
                      color: _getScoreColor(student.averageScore),
                      width: 16,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(4),
                      ),
                      backDrawRodData: BackgroundBarChartRodData(
                        show: true,
                        toY: 100,
                        color: Colors.grey.shade200,
                      ),
                    ),
                  ],
                  showingTooltipIndicators: _touchedIndex == index ? [0] : [],
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 12),
        _buildChartLegend(),
      ],
    );
  }

  Widget _buildChartLegend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildLegendItem('Excellent (>80%)', Colors.green),
        const SizedBox(width: 16),
        _buildLegendItem('Good (60-80%)', Colors.orange),
        const SizedBox(width: 16),
        _buildLegendItem('Needs Help (<60%)', Colors.red),
      ],
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade700,
          ),
        ),
      ],
    );
  }

  Color _getScoreColor(double score) {
    if (score >= 80) return Colors.green;
    if (score >= 60) return Colors.orange;
    return Colors.red;
  }

  Widget _buildStudentList() {
    final sortedStudents = List<StudentProgressModel>.from(_analytics.students)
      ..sort((a, b) => b.averageScore.compareTo(a.averageScore));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'All Students',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '${sortedStudents.length} total',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              // Table Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF4A90E2).withOpacity(0.1),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(7),
                  ),
                ),
                child: Row(
                  children: [
                    const Expanded(
                      flex: 3,
                      child: Text(
                        'Student',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const Expanded(
                      flex: 2,
                      child: Text(
                        'Quizzes',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const Expanded(
                      flex: 2,
                      child: Text(
                        'Avg Score',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const Expanded(
                      flex: 2,
                      child: Text(
                        'Last Active',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const Expanded(
                      flex: 1,
                      child: Text(
                        'Status',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Student Rows (Scrollable)
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 300),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: sortedStudents.length,
                  itemBuilder: (context, index) {
                    final student = sortedStudents[index];
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: index.isOdd
                            ? Colors.grey.shade50
                            : Colors.white,
                        border: Border(
                          bottom: BorderSide(
                            color: Colors.grey.shade200,
                            width: 0.5,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  student.name,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  student.email,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              '${student.quizzesTaken}',
                              style: const TextStyle(fontSize: 13),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: student.quizzesTaken > 0
                                    ? _getScoreColor(student.averageScore)
                                        .withOpacity(0.15)
                                    : Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                student.quizzesTaken > 0
                                    ? '${student.averageScore.toStringAsFixed(1)}%'
                                    : 'N/A',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: student.quizzesTaken > 0
                                      ? _getScoreColor(student.averageScore)
                                      : Colors.grey.shade600,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              student.lastActivityText,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade700,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          Expanded(
                            flex: 1,
                            child: Icon(
                              student.isActive
                                  ? Icons.check_circle
                                  : Icons.circle_outlined,
                              size: 16,
                              color: student.isActive
                                  ? Colors.green
                                  : Colors.grey.shade400,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

