import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/models.dart';

class StudentProgressWidget extends StatefulWidget {
  final String classCode;

  const StudentProgressWidget({
    super.key,
    required this.classCode,
  });

  @override
  State<StudentProgressWidget> createState() => _StudentProgressWidgetState();
}

class _StudentProgressWidgetState extends State<StudentProgressWidget> {
  int _selectedTab = 0; // 0: Table, 1: Graph 1, 2: Graph 2

  // Hardcoded mock data
  List<StudentProgress> get _mockStudentData => [
        StudentProgress(
          studentId: 'std001',
          studentName: 'Rahul Sharma',
          quizAttempts: 8,
          averageScore: 85.5,
          bestScore: 95,
          latestAttempt: '2024-11-28',
          materialScores: {
            'Physics_Ch1.pdf': 88.0,
            'Math_Algebra.pdf': 83.0,
          },
        ),
        StudentProgress(
          studentId: 'std002',
          studentName: 'Priya Patel',
          quizAttempts: 12,
          averageScore: 92.3,
          bestScore: 100,
          latestAttempt: '2024-11-29',
          materialScores: {
            'Physics_Ch1.pdf': 95.0,
            'Math_Algebra.pdf': 89.5,
          },
        ),
        StudentProgress(
          studentId: 'std003',
          studentName: 'Amit Kumar',
          quizAttempts: 5,
          averageScore: 68.4,
          bestScore: 78,
          latestAttempt: '2024-11-27',
          materialScores: {
            'Physics_Ch1.pdf': 72.0,
            'Math_Algebra.pdf': 64.8,
          },
        ),
        StudentProgress(
          studentId: 'std004',
          studentName: 'Sneha Reddy',
          quizAttempts: 10,
          averageScore: 78.9,
          bestScore: 88,
          latestAttempt: '2024-11-29',
          materialScores: {
            'Physics_Ch1.pdf': 80.0,
            'Math_Algebra.pdf': 77.8,
          },
        ),
        StudentProgress(
          studentId: 'std005',
          studentName: 'Vikram Singh',
          quizAttempts: 6,
          averageScore: 73.2,
          bestScore: 82,
          latestAttempt: '2024-11-26',
          materialScores: {
            'Physics_Ch1.pdf': 75.0,
            'Math_Algebra.pdf': 71.4,
          },
        ),
      ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Tab selector
          _buildTabSelector(),
          const SizedBox(height: 16),
          
          // Content based on selected tab
          _buildContent(),
        ],
      ),
    );
  }

  Widget _buildTabSelector() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        children: [
          _buildTab(0, Icons.table_chart, 'Table'),
          _buildTab(1, Icons.bar_chart, 'Avg Score'),
          _buildTab(2, Icons.bar_chart, 'Attempts'),
        ],
      ),
    );
  }

  Widget _buildTab(int index, IconData icon, String label) {
    final isSelected = _selectedTab == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF4A90E2) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected ? Colors.white : Colors.grey[700],
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? Colors.white : Colors.grey[700],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    switch (_selectedTab) {
      case 0:
        return _buildTableView();
      case 1:
        return _buildAverageScoreGraph();
      case 2:
        return _buildAttemptsGraph();
      default:
        return _buildTableView();
    }
  }

  // TABLE VIEW
  Widget _buildTableView() {
    if (_mockStudentData.isEmpty) {
      return _buildEmptyState();
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: MaterialStateProperty.all(const Color(0xFFE3F2FD)),
        border: TableBorder.all(color: Colors.grey[300]!),
        columns: const [
          DataColumn(
            label: Text(
              'Student Name',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          DataColumn(
            label: Text(
              'Quiz\nAttempts',
              style: TextStyle(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ),
          DataColumn(
            label: Text(
              'Avg Score\n(%)',
              style: TextStyle(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ),
          DataColumn(
            label: Text(
              'Best\nScore',
              style: TextStyle(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ),
          DataColumn(
            label: Text(
              'Latest\nAttempt',
              style: TextStyle(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ),
          DataColumn(
            label: Text(
              'Performance',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
        rows: _mockStudentData.map((student) {
          return DataRow(
            cells: [
              DataCell(
                Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: _getScoreColor(student.averageScore),
                      child: Text(
                        student.studentName[0],
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(student.studentName),
                  ],
                ),
              ),
              DataCell(
                Center(
                  child: Text(
                    '${student.quizAttempts}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              DataCell(
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getScoreColor(student.averageScore).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      student.averageScore.toStringAsFixed(1),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _getScoreColor(student.averageScore),
                      ),
                    ),
                  ),
                ),
              ),
              DataCell(
                Center(
                  child: Text(
                    '${student.bestScore}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.green,
                    ),
                  ),
                ),
              ),
              DataCell(
                Center(
                  child: Text(
                    student.latestAttempt,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[700],
                    ),
                  ),
                ),
              ),
              DataCell(
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getScoreColor(student.averageScore).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: _getScoreColor(student.averageScore),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    student.performanceLevel,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: _getScoreColor(student.averageScore),
                    ),
                  ),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  // BAR GRAPH 1: Average Score
  Widget _buildAverageScoreGraph() {
    if (_mockStudentData.isEmpty) {
      return _buildEmptyState();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Average Quiz Score by Student',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Shows each student\'s average performance across all quizzes',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          height: 300,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: 100,
              minY: 0,
              barTouchData: BarTouchData(
                enabled: true,
                touchTooltipData: BarTouchTooltipData(
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    return BarTooltipItem(
                      '${_mockStudentData[groupIndex].studentName}\n${rod.toY.toStringAsFixed(1)}%',
                      const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
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
                      if (value.toInt() >= 0 && value.toInt() < _mockStudentData.length) {
                        final student = _mockStudentData[value.toInt()];
                        final firstName = student.studentName.split(' ')[0];
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            firstName,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      }
                      return const Text('');
                    },
                    reservedSize: 40,
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: 20,
                    getTitlesWidget: (value, meta) {
                      return Text(
                        '${value.toInt()}%',
                        style: const TextStyle(fontSize: 11),
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
                    color: Colors.grey[300]!,
                    strokeWidth: 1,
                  );
                },
              ),
              borderData: FlBorderData(
                show: true,
                border: Border(
                  left: BorderSide(color: Colors.grey[400]!),
                  bottom: BorderSide(color: Colors.grey[400]!),
                ),
              ),
              barGroups: _mockStudentData.asMap().entries.map((entry) {
                final index = entry.key;
                final student = entry.value;
                return BarChartGroupData(
                  x: index,
                  barRods: [
                    BarChartRodData(
                      toY: student.averageScore,
                      color: _getScoreColor(student.averageScore),
                      width: 30,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(6),
                      ),
                      backDrawRodData: BackgroundBarChartRodData(
                        show: true,
                        toY: 100,
                        color: Colors.grey[200],
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 16),
        _buildLegend(),
      ],
    );
  }

  // BAR GRAPH 2: Quiz Attempts
  Widget _buildAttemptsGraph() {
    if (_mockStudentData.isEmpty) {
      return _buildEmptyState();
    }

    final maxAttempts = _mockStudentData
        .map((s) => s.quizAttempts)
        .reduce((a, b) => a > b ? a : b)
        .toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quiz Attempts by Student',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Shows student engagement - number of quizzes attempted',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          height: 300,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: (maxAttempts + 2).ceilToDouble(),
              minY: 0,
              barTouchData: BarTouchData(
                enabled: true,
                touchTooltipData: BarTouchTooltipData(
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    return BarTooltipItem(
                      '${_mockStudentData[groupIndex].studentName}\n${rod.toY.toInt()} attempts',
                      const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
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
                      if (value.toInt() >= 0 && value.toInt() < _mockStudentData.length) {
                        final student = _mockStudentData[value.toInt()];
                        final firstName = student.studentName.split(' ')[0];
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            firstName,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      }
                      return const Text('');
                    },
                    reservedSize: 40,
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      return Text(
                        value.toInt().toString(),
                        style: const TextStyle(fontSize: 11),
                      );
                    },
                    reservedSize: 30,
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
                getDrawingHorizontalLine: (value) {
                  return FlLine(
                    color: Colors.grey[300]!,
                    strokeWidth: 1,
                  );
                },
              ),
              borderData: FlBorderData(
                show: true,
                border: Border(
                  left: BorderSide(color: Colors.grey[400]!),
                  bottom: BorderSide(color: Colors.grey[400]!),
                ),
              ),
              barGroups: _mockStudentData.asMap().entries.map((entry) {
                final index = entry.key;
                final student = entry.value;
                return BarChartGroupData(
                  x: index,
                  barRods: [
                    BarChartRodData(
                      toY: student.quizAttempts.toDouble(),
                      color: const Color(0xFF4A90E2),
                      width: 30,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(6),
                      ),
                      backDrawRodData: BackgroundBarChartRodData(
                        show: true,
                        toY: (maxAttempts + 2).ceilToDouble(),
                        color: Colors.grey[200],
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 16),
        _buildEngagementSummary(),
      ],
    );
  }

  Widget _buildLegend() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildLegendItem('Excellent', Colors.green, '≥80%'),
          _buildLegendItem('Good', Colors.orange, '60-79%'),
          _buildLegendItem('Average', Colors.deepOrange, '40-59%'),
          _buildLegendItem('Needs Help', Colors.red, '<40%'),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color, String range) {
    return Column(
      children: [
        Row(
          children: [
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        Text(
          range,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildEngagementSummary() {
    final totalAttempts = _mockStudentData.fold<int>(
      0,
      (sum, student) => sum + student.quizAttempts,
    );
    final avgAttempts = totalAttempts / _mockStudentData.length;
    final mostActiveStudent = _mockStudentData.reduce(
      (a, b) => a.quizAttempts > b.quizAttempts ? a : b,
    );

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildSummaryItem(
            'Total Attempts',
            totalAttempts.toString(),
            Icons.quiz,
            const Color(0xFF4A90E2),
          ),
          _buildSummaryItem(
            'Average',
            avgAttempts.toStringAsFixed(1),
            Icons.analytics,
            Colors.orange,
          ),
          _buildSummaryItem(
            'Most Active',
            mostActiveStudent.studentName.split(' ')[0],
            Icons.star,
            Colors.green,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.assessment_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No Quiz Attempts Yet',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Students haven\'t taken any quizzes yet.\nData will appear here once they start.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getScoreColor(double score) {
    if (score >= 80) return Colors.green;
    if (score >= 60) return Colors.orange;
    if (score >= 40) return Colors.deepOrange;
    return Colors.red;
  }
}

