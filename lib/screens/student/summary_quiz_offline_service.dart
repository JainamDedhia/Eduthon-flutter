// FILE: lib/screens/student/summary_quiz_offline_service.dart
import 'package:flutter/material.dart';
import '../../services/summary_generator.dart';
import '../../services/mind_map_generator.dart';
import '../../models/models.dart';
import '../../services/llm_summary_service.dart';
import '../../services/offline_db.dart';

class SummaryQuizOfflineService {
  static Future<void> generateOfflineMode({
    required BuildContext context,
    required FileRecord file,
    required Function(String?) setProcessingFile,
    required Function(double) setProgress,
    required VoidCallback onSuccess,
    required Function(Exception) onError,
  }) async {
    final modelAvailable = await LLMSummaryService.isModelAvailable();

    String? selectedLanguage;
    double selectedGrade = 5.0; // Default Grade 5

    // Always ask for Grade Level preference
    final double? grade = await showDialog<double>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        double currentGrade = 5.0;
        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: const Text('🎓 Student Level'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Select target grade level (1-10):'),
                const SizedBox(height: 10),
                Text(
                  'Grade ${currentGrade.round()}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                Slider(
                  value: currentGrade,
                  min: 1,
                  max: 10,
                  divisions: 9,
                  label: 'Grade ${currentGrade.round()}',
                  onChanged: (val) => setState(() => currentGrade = val),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, currentGrade),
                child: const Text('Continue'),
              ),
            ],
          ),
        );
      },
    );

    if (grade == null) return; // Cancelled
    selectedGrade = grade;

    if (modelAvailable) {
      selectedLanguage = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.language, color: Color(0xFF4A90E2)),
              SizedBox(width: 8),
              Text('Select Language'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '🤖 Local AI Model detected!\nChoose summary language:',
                style: TextStyle(fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              _buildLanguageOption(context, 'English', 'en', '🇬🇧'),
              const SizedBox(height: 12),
              _buildLanguageOption(context, 'हिंदी (Hindi)', 'hi', '🇮🇳'),
              const SizedBox(height: 12),
              _buildLanguageOption(context, 'मराठी (Marathi)', 'mr', '🇮🇳'),
            ],
          ),
        ),
      );

      if (selectedLanguage == null) return;
    }

    setProcessingFile(file.name);
    setProgress(0.0);

    try {
      print('🔄 Starting offline generation for: ${file.name}');

      setProgress(0.15);
      final rawText = await SummaryGenerator.extractTextFromPDF(file.localPath);

      if (rawText.isEmpty) {
        throw Exception('Could not extract text from PDF');
      }

      print('🧹 Cleaning text...');
      final text = SummaryGenerator.cleanText(rawText);

      final subject = SummaryGenerator.detectSubject(text);
      print('📚 Detected Subject: $subject');

      final estimatedGrade = SummaryGenerator.estimateGradeLevel(text);
      print('📊 Estimated Text Complexity: Grade ${estimatedGrade.toStringAsFixed(1)}');

      String summary;
      List<Map<String, dynamic>> quiz;

      // SUMMARY: Use LLM if available, otherwise rule-based
      if (modelAvailable && selectedLanguage != null) {
        print('🤖 Using local LLM for summary');
        setProgress(0.4);
        
        final rawSummary = await LLMSummaryService.generateSummaryWithLLM(
          text: text,
          language: selectedLanguage,
        );
        summary = SummaryGenerator.cleanText(rawSummary);
      } else {
        print('📝 Using rule-based summary (Grade ${selectedGrade.round()})');
        setProgress(0.4);
        
        summary = await SummaryGenerator.generateSummary(
          text,
          gradeLevel: selectedGrade,
        );
      }

      // 🎯 QUIZ: ALWAYS USE RULE-BASED (More reliable than LLM)
      print('📝 Using rule-based quiz generation');
      setProgress(0.65);
      
      quiz = await SummaryGenerator.generateQuiz(
        summary,
        gradeLevel: selectedGrade,
        numQuestions: 10,
      );

      print('✅ Generated ${quiz.length} quiz questions using rule-based method');

      // MIND MAP: Always rule-based
      setProgress(0.85);
      print('🧠 Generating mind map...');

      final mindMap = await MindMapGenerator.generateMindMap(
        summary: summary,
        quiz: quiz,
        fileName: file.name,
      );

      setProgress(1.0);

      await OfflineDB.saveSummaryAndQuiz(
        file.classCode,
        file.name,
        summary,
        quiz,
      );

      await OfflineDB.saveMindMap(file.classCode, file.name, mindMap.toJson());

      print('✅ Summary, Quiz, and Mind Map saved');

      if (context.mounted) {
        final mode = modelAvailable ? 'Local AI Summary + Rule-Based Quiz' : 'Rule-Based';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Generated with $mode!'),
            backgroundColor: Colors.green,
          ),
        );
      }

      onSuccess();
    } catch (e) {
      print('❌ Error: $e');
      onError(e as Exception);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setProcessingFile(null);
      setProgress(0.0);
    }
  }

  static Widget _buildLanguageOption(
    BuildContext context,
    String name,
    String code,
    String flag,
  ) {
    return InkWell(
      onTap: () => Navigator.pop(context, code),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFE3F2FD),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF4A90E2)),
        ),
        child: Row(
          children: [
            Text(flag, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 12),
            Text(
              name,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}