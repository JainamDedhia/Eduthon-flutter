import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common/rounded_card.dart';

class PerformanceReportScreen extends StatelessWidget {
  const PerformanceReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Mock data - replace with real data from Firestore
    final quizScores = [
      {'subject': 'Math', 'score': 85, 'date': '2024-01-15'},
      {'subject': 'Physics', 'score': 92, 'date': '2024-01-20'},
      {'subject': 'Chemistry', 'score': 78, 'date': '2024-01-25'},
      {'subject': 'Math', 'score': 90, 'date': '2024-02-01'},
      {'subject': 'Physics', 'score': 88, 'date': '2024-02-05'},
    ];

    final averageScore = quizScores.map((q) => q['score'] as int).reduce((a, b) => a + b) / quizScores.length;
    final totalQuizzes = quizScores.length;
    final highestScore = quizScores.map((q) => q['score'] as int).reduce((a, b) => a > b ? a : b);

    return Scaffold(
      backgroundColor: AppTheme.lightGrey,
      appBar: AppBar(
        title: const Text('Performance Report'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Summary Cards
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Average Score',
                    averageScore.toStringAsFixed(0),
                    '%',
                    AppTheme.primaryBlue,
                    Icons.trending_up,
                  ),
                ),
                const SizedBox(width: AppTheme.spacingM),
                Expanded(
                  child: _buildStatCard(
                    'Total Quizzes',
                    totalQuizzes.toString(),
                    '',
                    AppTheme.successGreen,
                    Icons.quiz,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingM),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Highest Score',
                    highestScore.toString(),
                    '%',
                    Colors.orange,
                    Icons.star,
                  ),
                ),
                const SizedBox(width: AppTheme.spacingM),
                Expanded(
                  child: _buildStatCard(
                    'Improvement',
                    '+5',
                    '%',
                    AppTheme.successGreen,
                    Icons.arrow_upward,
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppTheme.spacingXL),

            // Score Trend Chart
            RoundedCard(
              padding: const EdgeInsets.all(AppTheme.spacingL),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Score Trend',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                      fontFamily: 'Roboto',
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingL),
                  SizedBox(
                    height: 200,
                    child: LineChart(
                      LineChartData(
                        gridData: FlGridData(show: false),
                        titlesData: FlTitlesData(show: false),
                        borderData: FlBorderData(show: false),
                        lineBarsData: [
                          LineChartBarData(
                            spots: quizScores.asMap().entries.map((entry) {
                              return FlSpot(entry.key.toDouble(), (entry.value['score'] as int).toDouble());
                            }).toList(),
                            isCurved: true,
                            color: AppTheme.primaryBlue,
                            barWidth: 3,
                            dotData: FlDotData(show: true),
                            belowBarData: BarAreaData(
                              show: true,
                              color: AppTheme.primaryBlue.withOpacity(0.1),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppTheme.spacingXL),

            // Recent Quiz Results
            const Text(
              'Recent Quiz Results',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
                fontFamily: 'Roboto',
              ),
            ),
            const SizedBox(height: AppTheme.spacingM),
            ...quizScores.map((quiz) => Padding(
              padding: const EdgeInsets.only(bottom: AppTheme.spacingM),
              child: _buildQuizResultCard(
                subject: quiz['subject'] as String,
                score: quiz['score'] as int,
                date: quiz['date'] as String,
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, String unit, Color color, IconData icon) {
    return RoundedCard(
      padding: const EdgeInsets.all(AppTheme.spacingM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 24),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacingS,
                  vertical: AppTheme.spacingXS,
                ),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusS),
                ),
                child: Text(
                  '$value$unit',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                    fontFamily: 'Roboto',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingS),
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: AppTheme.textSecondary,
              fontFamily: 'Roboto',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuizResultCard({required String subject, required int score, required String date}) {
    Color scoreColor;
    if (score >= 90) {
      scoreColor = AppTheme.successGreen;
    } else if (score >= 70) {
      scoreColor = Colors.orange;
    } else {
      scoreColor = AppTheme.errorRed;
    }

    return RoundedCard(
      padding: const EdgeInsets.all(AppTheme.spacingM),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppTheme.spacingM),
            decoration: BoxDecoration(
              color: scoreColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppTheme.radiusM),
            ),
            child: Icon(Icons.quiz, color: scoreColor, size: 24),
          ),
          const SizedBox(width: AppTheme.spacingM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  subject,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                    fontFamily: 'Roboto',
                  ),
                ),
                const SizedBox(height: AppTheme.spacingXS),
                Text(
                  date,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                    fontFamily: 'Roboto',
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacingM,
              vertical: AppTheme.spacingS,
            ),
            decoration: BoxDecoration(
              color: scoreColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppTheme.radiusM),
            ),
            child: Text(
              '$score%',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: scoreColor,
                fontFamily: 'Roboto',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

