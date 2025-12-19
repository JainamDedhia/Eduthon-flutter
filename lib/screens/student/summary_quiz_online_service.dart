// FILE: lib/screens/student/summary_quiz_online_service.dart
import 'package:flutter/material.dart';
import '../../services/summary_generator.dart';
import '../../services/mind_map_generator.dart';
import '../../models/models.dart';
import '../../services/server_api_service.dart';
import '../../services/offline_db.dart';
import '../../services/explanation_parser.dart';
import '../../widgets/model_selection_dialog.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../theme/app_theme.dart';

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
        builder: (context) => ModelSelectionDialog(
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

      // Step 1: Extract text from PDF
      setProgress(0.15);
      final text = await SummaryGenerator.extractTextFromPDF(file.localPath);
      
      if (text.isEmpty) {
        throw Exception('Could not extract text from PDF');
      }

      print('📄 [SummaryQuiz] Extracted ${text.length} characters');

      // Step 2: Generate Summary using Server API
      setProgress(0.3);
      print('🔄 [SummaryQuiz] Calling server API for summary...');
      
      final summary = await ServerAPIService.generateSummary(
        text: text,
        model: selectedModel,
        maxLength: 500,
      );

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

      // Step 3.5: Parse explanations for quiz questions
      setProgress(0.7);
      print('🔍 [SummaryQuiz] Parsing explanations from source text...');
      
      try {
        // Use the original PDF text for better explanation extraction
        final explanations = ExplanationParser.parseExplanationsForQuiz(quiz, text);
        
        // Add explanations to quiz questions
        for (int i = 0; i < quiz.length; i++) {
          if (explanations.containsKey(i) && explanations[i] != null) {
            quiz[i]['explanation'] = explanations[i];
            print('✅ [SummaryQuiz] Explanation found for question ${i + 1}');
          } else {
            print('⚠️ [SummaryQuiz] No explanation found for question ${i + 1}');
          }
        }
      } catch (e) {
        print('⚠️ [SummaryQuiz] Error parsing explanations: $e');
        // Continue without explanations if parsing fails
      }

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

      await OfflineDB.saveMindMap(
        file.classCode,
        file.name,
        mindMap.toJson(),
      );

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
          builder: (context) => AlertDialog(
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
                  backgroundColor: AppTheme.primaryBlue,
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