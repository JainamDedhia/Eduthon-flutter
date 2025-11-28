// FILE: lib/services/quiz_sync_service.dart
import 'package:connectivity_plus/connectivity_plus.dart';
import '../config/firebase_config.dart';
import 'offline_db.dart';

class QuizResult {
  final String studentId;
  final String classCode;
  final String fileName;
  final int score;
  final int totalQuestions;
  final int correctAnswers;
  final Map<int, String> userAnswers;
  final List<Map<String, dynamic>> quiz;
  final String completedAt;
  final bool synced;

  QuizResult({
    required this.studentId,
    required this.classCode,
    required this.fileName,
    required this.score,
    required this.totalQuestions,
    required this.correctAnswers,
    required this.userAnswers,
    required this.quiz,
    required this.completedAt,
    this.synced = false,
  });

  Map<String, dynamic> toJson() => {
    'studentId': studentId,
    'classCode': classCode,
    'fileName': fileName,
    'score': score,
    'totalQuestions': totalQuestions,
    'correctAnswers': correctAnswers,
    'userAnswers': userAnswers.map((k, v) => MapEntry(k.toString(), v)),
    'quiz': quiz,
    'completedAt': completedAt,
    'synced': synced,
  };

  factory QuizResult.fromJson(Map<String, dynamic> json) => QuizResult(
    studentId: json['studentId'] ?? '',
    classCode: json['classCode'] ?? '',
    fileName: json['fileName'] ?? '',
    score: json['score'] ?? 0,
    totalQuestions: json['totalQuestions'] ?? 0,
    correctAnswers: json['correctAnswers'] ?? 0,
    userAnswers: (json['userAnswers'] as Map<String, dynamic>?)
        ?.map((k, v) => MapEntry(int.parse(k), v as String)) ?? {},
    quiz: (json['quiz'] as List?)?.cast<Map<String, dynamic>>() ?? [],
    completedAt: json['completedAt'] ?? '',
    synced: json['synced'] ?? false,
  );

  Map<String, dynamic> toFirestore() => {
    'studentId': studentId,
    'classCode': classCode,
    'fileName': fileName,
    'score': score,
    'totalQuestions': totalQuestions,
    'correctAnswers': correctAnswers,
    'percentage': ((correctAnswers / totalQuestions) * 100).toInt(),
    'completedAt': completedAt,
    'syncedAt': DateTime.now().toIso8601String(),
  };
}

class QuizSyncService {
  // Save quiz result locally
  static Future<void> saveQuizResultLocally(QuizResult result) async {
    try {
      print('💾 [QuizSync] Saving quiz result locally: ${result.fileName}');
      await OfflineDB.saveQuizResult(result);
      print('✅ [QuizSync] Quiz result saved locally');
      
      // Try to sync immediately if online
      await syncPendingResults();
    } catch (e) {
      print('❌ [QuizSync] Failed to save quiz result: $e');
      rethrow;
    }
  }

  // Sync all pending results to Firebase
  static Future<void> syncPendingResults() async {
    try {
      // Check connectivity
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        print('📴 [QuizSync] Offline - skipping sync');
        return;
      }

      print('🌐 [QuizSync] Online - syncing pending results...');

      final pendingResults = await OfflineDB.getPendingQuizResults();
      if (pendingResults.isEmpty) {
        print('✅ [QuizSync] No pending results to sync');
        return;
      }

      print('📊 [QuizSync] Found ${pendingResults.length} pending results');

      int synced = 0;
      for (final result in pendingResults) {
        try {
          await _syncResultToFirebase(result);
          await OfflineDB.markQuizResultAsSynced(result);
          synced++;
          print('✅ [QuizSync] Synced: ${result.fileName}');
        } catch (e) {
          print('⚠️ [QuizSync] Failed to sync ${result.fileName}: $e');
          // Continue with other results
        }
      }

      print('✅ [QuizSync] Successfully synced $synced/${pendingResults.length} results');
    } catch (e) {
      print('❌ [QuizSync] Sync failed: $e');
    }
  }

  // Sync single result to Firebase
  static Future<void> _syncResultToFirebase(QuizResult result) async {
    try {
      // Upload to Firebase: /quiz_results/{studentId}/{classCode}_{fileName}_{timestamp}
      final docId = '${result.classCode}_${result.fileName}_${result.completedAt.replaceAll(RegExp(r'[^0-9]'), '')}';
      
      await FirebaseConfig.firestore
          .collection('quiz_results')
          .doc(result.studentId)
          .collection('results')
          .doc(docId)
          .set(result.toFirestore());

      print('🔥 [QuizSync] Uploaded to Firebase: $docId');
    } catch (e) {
      print('❌ [QuizSync] Firebase upload failed: $e');
      rethrow;
    }
  }

  // Get student's quiz history (online only)
  static Future<List<Map<String, dynamic>>> getStudentQuizHistory(String studentId) async {
    try {
      final snapshot = await FirebaseConfig.firestore
          .collection('quiz_results')
          .doc(studentId)
          .collection('results')
          .orderBy('completedAt', descending: true)
          .limit(50)
          .get();

      return snapshot.docs.map((doc) => {
        ...doc.data(),
        'id': doc.id,
      }).toList();
    } catch (e) {
      print('❌ [QuizSync] Failed to fetch history: $e');
      return [];
    }
  }

  // Get analytics for a class (teacher view)
  static Future<Map<String, dynamic>> getClassAnalytics(String classCode) async {
    try {
      final snapshot = await FirebaseConfig.firestore
          .collectionGroup('results')
          .where('classCode', isEqualTo: classCode)
          .get();

      if (snapshot.docs.isEmpty) {
        return {
          'totalAttempts': 0,
          'averageScore': 0.0,
          'studentsCompleted': 0,
        };
      }

      final results = snapshot.docs.map((doc) => doc.data()).toList();
      final totalAttempts = results.length;
      final totalScore = results.fold<double>(0, (sum, r) => sum + (r['percentage'] ?? 0));
      final averageScore = totalScore / totalAttempts;
      final uniqueStudents = results.map((r) => r['studentId']).toSet().length;

      return {
        'totalAttempts': totalAttempts,
        'averageScore': averageScore.toStringAsFixed(1),
        'studentsCompleted': uniqueStudents,
        'results': results,
      };
    } catch (e) {
      print('❌ [QuizSync] Failed to fetch analytics: $e');
      return {
        'totalAttempts': 0,
        'averageScore': '0.0',
        'studentsCompleted': 0,
      };
    }
  }
}