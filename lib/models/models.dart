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