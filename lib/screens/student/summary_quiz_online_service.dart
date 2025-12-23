// FILE: lib/screens/student/summary_quiz_online_service.dart
import 'package:flutter/material.dart';
import '../../services/summary_generator.dart';
import '../../services/mind_map_generator.dart';
import '../../models/models.dart';
import '../../services/server_api_service.dart';
import '../../services/offline_db.dart';
import '../../widgets/model_selection_dialog.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class SummaryQuizOnlineService {
  static Future<void> generateWithServerAPI({
    required BuildContext context,
    required FileRecord file,
    required Function(String?) setProcessingFile,
    required Function(double) setProgress,
    required VoidCallback onSuccess,
    required Function(Exception) onError,
    required Function() onFallbackToOffline,
  }) async {
    try {
      // Show model selection dialog
      final selectedModel = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder:
            (context) => ModelSelectionDialog(
              title: '🤖 Choose AI Model',
              description: 'Select model for generating summary & quiz',
            ),
      );

      if (selectedModel == null) {
        print('⚠️ [SummaryQuiz] Model selection cancelled');
        return;
      }

      print('✅ [SummaryQuiz] Selected model: $selectedModel');

      setProcessingFile(file.name);
      setProgress(0.0);
      String summary;

      // Step 1: Extract text from PDF
      setProgress(0.15);
      final rawText = await SummaryGenerator.extractTextFromPDF(file.localPath);

      if (rawText.isEmpty) {
        throw Exception('Could not extract text from PDF');
      }

      // Clean the text dynamically using our new WordJoiner and other rules
      print('🧹 Cleaning text...');
      final text = SummaryGenerator.cleanText(rawText);

      print(
        '📄 [SummaryQuiz] Cleaned text: ${text.length} characters (Original: ${rawText.length})',
      );

      // Step 2: Generate Summary using Server API
      setProgress(0.3);
      print('🔄 [SummaryQuiz] Calling server API for summary...');

      final rawSummary = await ServerAPIService.generateSummary(
        text: text,
        model: selectedModel,
        maxLength: 500,
      );
      summary = SummaryGenerator.cleanText(rawSummary);

      print('✅ [SummaryQuiz] Summary received: ${summary.length} chars');

      // Step 3: Generate Quiz using Server API
      setProgress(0.6);
      print('🔄 [SummaryQuiz] Calling server API for quiz...');

      final quiz = await ServerAPIService.generateQuiz(
        text: summary, // Use summary as context for quiz
        model: selectedModel,
        numQuestions: 5,
      );

      print('✅ [SummaryQuiz] Quiz received: ${quiz.length} questions');

      // Step 4: Generate Mind Map (use local generation)
      setProgress(0.85);
      print('🧠 [SummaryQuiz] Generating mind map locally...');

      final mindMap = await MindMapGenerator.generateMindMap(
        summary: summary,
        quiz: quiz,
        fileName: file.name,
      );

      print('✅ [SummaryQuiz] Mind map generated');

      // Step 5: Save to local database
      setProgress(0.95);

      await OfflineDB.saveSummaryAndQuiz(
        file.classCode,
        file.name,
        summary,
        quiz,
      );

      await OfflineDB.saveMindMap(file.classCode, file.name, mindMap.toJson());

      setProgress(1.0);

      print('✅ [SummaryQuiz] All data saved successfully');

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '✅ Generated with ${ServerAPIService.getModelDisplayName(selectedModel)}!',
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }

      onSuccess();
    } catch (e) {
      print('❌ [SummaryQuiz] Server generation failed: $e');
      onError(e as Exception);

      if (context.mounted) {
        // Show error with fallback option
        final retry = await showDialog<bool>(
          context: context,
          builder:
              (context) => AlertDialog(
                title: Row(
                  children: [
                    Icon(Icons.error, color: Colors.orange),
                    SizedBox(width: 8),
                    Text('Server Error'),
                  ],
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Failed to generate using server:'),
                    SizedBox(height: 8),
                    Text(
                      e.toString(),
                      style: TextStyle(fontSize: 12, color: Colors.red),
                    ),
                    SizedBox(height: 16),
                    Text('Would you like to use offline mode instead?'),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF4A90E2),
                    ),
                    child: Text('Use Offline Mode'),
                  ),
                ],
              ),
        );

        if (retry == true) {
          onFallbackToOffline();
        }
      }
    } finally {
      setProcessingFile(null);
      setProgress(0.0);
    }
  }

  static Future<bool> checkConnectivity() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    return connectivityResult != ConnectivityResult.none;
  }
}
