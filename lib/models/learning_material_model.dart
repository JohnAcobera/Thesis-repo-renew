class LearningMaterialModel {
  const LearningMaterialModel({
    required this.id,
    required this.title,
    required this.sourceFile,
    required this.createdAt,
    required this.questionCount,
    this.folderId,
    this.folderName,
  });

  final String id;
  final String title;
  final String sourceFile;
  final DateTime createdAt;
  final int questionCount;
  final String? folderId;
  final String? folderName;

  factory LearningMaterialModel.fromJson(Map<String, dynamic> json) =>
      LearningMaterialModel(
        id: json['id'] as String,
        title: json['title'] as String,
        sourceFile: json['source_file'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
        questionCount: (json['question_count'] as num).toInt(),
        folderId: json['folder_id'] as String?,
        folderName: json['folder_name'] as String?,
      );
}

class LearningMaterialFolder {
  const LearningMaterialFolder({
    required this.id,
    required this.name,
    required this.createdAt,
  });

  final String id;
  final String name;
  final DateTime createdAt;

  factory LearningMaterialFolder.fromJson(Map<String, dynamic> json) =>
      LearningMaterialFolder(
        id: json['id'] as String,
        name: json['name'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}
