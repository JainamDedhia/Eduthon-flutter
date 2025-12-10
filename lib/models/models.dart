// User Model
class UserModel {
  final String uid;
  final String email;
  final String name;
  final String role; // 'teacher' or 'student'
  final String createdAt;

  UserModel({
    required this.uid,
    required this.email,
    required this.name,
    required this.role,
    required this.createdAt,
  });

  factory UserModel.fromFirestore(Map<String, dynamic> data, String uid) {
    return UserModel(
      uid: uid,
      email: data['email'] ?? '',
      name: data['name'] ?? '',
      role: data['role'] ?? '',
      createdAt: data['createdAt'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'name': name,
      'role': role,
      'createdAt': createdAt,
    };
  }
}

// Class Material Model
class ClassMaterial {
  final String name;
  final String url;
  final String? uploadedAt;

  ClassMaterial({
    required this.name,
    required this.url,
    this.uploadedAt,
  });

  factory ClassMaterial.fromMap(Map<String, dynamic> data) {
    return ClassMaterial(
      name: data['name'] ?? '',
      url: data['url'] ?? '',
      uploadedAt: data['uploadedAt'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'url': url,
      'uploadedAt': uploadedAt ?? DateTime.now().toIso8601String(),
    };
  }
}

// Class Model
class ClassModel {
  final String id;
  final String className;
  final String description;
  final String classCode;
  final String teacherId;
  final List<String> students;
  final List<ClassMaterial> materials;
  final String createdAt;

  ClassModel({
    required this.id,
    required this.className,
    required this.description,
    required this.classCode,
    required this.teacherId,
    required this.students,
    required this.materials,
    required this.createdAt,
  });

  factory ClassModel.fromFirestore(Map<String, dynamic> data, String id) {
    return ClassModel(
      id: id,
      className: data['className'] ?? '',
      description: data['description'] ?? '',
      classCode: data['classCode'] ?? '',
      teacherId: data['teacherId'] ?? '',
      students: List<String>.from(data['students'] ?? []),
      materials: (data['materials'] as List<dynamic>?)
              ?.map((m) => ClassMaterial.fromMap(m as Map<String, dynamic>))
              .toList() ??
          [],
      createdAt: data['createdAt'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'className': className,
      'description': description,
      'classCode': classCode,
      'teacherId': teacherId,
      'students': students,
      'materials': materials.map((m) => m.toMap()).toList(),
      'createdAt': createdAt,
    };
  }
}

// File Record Model (for offline storage)
class FileRecord {
  final String classCode;
  final String name;
  final String localPath;
  final String? url;
  final int? compressedSize;
  final int? originalSize;
  final bool isCompressed;
  final String savedAt;

  FileRecord({
    required this.classCode,
    required this.name,
    required this.localPath,
    this.url,
    this.compressedSize,
    this.originalSize,
    this.isCompressed = false,
    required this.savedAt,
  });

  factory FileRecord.fromJson(Map<String, dynamic> json) {
    return FileRecord(
      classCode: json['classCode'] ?? '',
      name: json['name'] ?? '',
      localPath: json['localPath'] ?? '',
      url: json['url'],
      compressedSize: json['compressedSize'],
      originalSize: json['originalSize'],
      isCompressed: json['isCompressed'] ?? false,
      savedAt: json['savedAt'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'classCode': classCode,
      'name': name,
      'localPath': localPath,
      'url': url,
      'compressedSize': compressedSize,
      'originalSize': originalSize,
      'isCompressed': isCompressed,
      'savedAt': savedAt,
    };
  }

  String get spaceSavedText {
    if (isCompressed && compressedSize != null && originalSize != null) {
      final savedMB = (originalSize! - compressedSize!) / 1024 / 1024;
      final ratio =
          ((originalSize! - compressedSize!) / originalSize! * 100).toStringAsFixed(0);
      return ' • Saved ${savedMB.toStringAsFixed(1)}MB ($ratio%)';
    }
    return '';
  }
}

// Storage Stats Model
class StorageStats {
  final int totalFiles;
  final int compressedFiles;
  final int totalSpaceUsed;
  final int spaceSaved;

  StorageStats({
    required this.totalFiles,
    required this.compressedFiles,
    required this.totalSpaceUsed,
    required this.spaceSaved,
  });

  factory StorageStats.empty() {
    return StorageStats(
      totalFiles: 0,
      compressedFiles: 0,
      totalSpaceUsed: 0,
      spaceSaved: 0,
    );
  }
}

// Student Progress Model
class StudentProgress {
  final String studentId;
  final String studentName;
  final int quizAttempts;
  final double averageScore;
  final int bestScore;
  final String latestAttempt;
  final Map<String, double> materialScores;

  StudentProgress({
    required this.studentId,
    required this.studentName,
    required this.quizAttempts,
    required this.averageScore,
    required this.bestScore,
    required this.latestAttempt,
    required this.materialScores,
  });

  // Get color based on average score
  String get performanceLevel {
    if (averageScore >= 80) return 'Excellent';
    if (averageScore >= 60) return 'Good';
    if (averageScore >= 40) return 'Average';
    return 'Needs Improvement';
  }
}

// Student Progress Model
class StudentProgressModel {
  final String studentId;
  final String name;
  final String email;
  final int quizzesTaken;
  final double averageScore; // percentage (0-100)
  final DateTime lastActivityDate;
  final bool isActive;

  StudentProgressModel({
    required this.studentId,
    required this.name,
    required this.email,
    required this.quizzesTaken,
    required this.averageScore,
    required this.lastActivityDate,
    required this.isActive,
  });

  factory StudentProgressModel.fromMap(Map<String, dynamic> data) {
    return StudentProgressModel(
      studentId: data['studentId'] ?? '',
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      quizzesTaken: data['quizzesTaken'] ?? 0,
      averageScore: (data['averageScore'] ?? 0).toDouble(),
      lastActivityDate: data['lastActivityDate'] != null
          ? DateTime.parse(data['lastActivityDate'])
          : DateTime.now(),
      isActive: data['isActive'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'studentId': studentId,
      'name': name,
      'email': email,
      'quizzesTaken': quizzesTaken,
      'averageScore': averageScore,
      'lastActivityDate': lastActivityDate.toIso8601String(),
      'isActive': isActive,
    };
  }

  String get statusText => isActive ? 'Active' : 'Inactive';
  
  String get lastActivityText {
    final now = DateTime.now();
    final difference = now.difference(lastActivityDate);
    
    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else if (difference.inDays < 30) {
      return '${(difference.inDays / 7).floor()} weeks ago';
    } else {
      return '${(difference.inDays / 30).floor()} months ago';
    }
  }
}

// Class Analytics Model
class ClassAnalytics {
  final int totalStudents;
  final double averageClassScore;
  final double completionRate; // percentage (0-100)
  final int activeStudents;
  final int inactiveStudents;
  final List<StudentProgressModel> students;

  ClassAnalytics({
    required this.totalStudents,
    required this.averageClassScore,
    required this.completionRate,
    required this.activeStudents,
    required this.inactiveStudents,
    required this.students,
  });

  factory ClassAnalytics.fromStudents(List<StudentProgressModel> students) {
    final totalStudents = students.length;
    final activeStudents = students.where((s) => s.isActive).length;
    final studentsWithQuizzes = students.where((s) => s.quizzesTaken > 0).toList();
    
    final averageScore = studentsWithQuizzes.isEmpty
        ? 0.0
        : studentsWithQuizzes.map((s) => s.averageScore).reduce((a, b) => a + b) /
            studentsWithQuizzes.length;
    
    final completionRate = totalStudents == 0
        ? 0.0
        : (studentsWithQuizzes.length / totalStudents) * 100;

    return ClassAnalytics(
      totalStudents: totalStudents,
      averageClassScore: averageScore,
      completionRate: completionRate,
      activeStudents: activeStudents,
      inactiveStudents: totalStudents - activeStudents,
      students: students,
    );
  }

  factory ClassAnalytics.empty() {
    return ClassAnalytics(
      totalStudents: 0,
      averageClassScore: 0.0,
      completionRate: 0.0,
      activeStudents: 0,
      inactiveStudents: 0,
      students: [],
    );
  }
}