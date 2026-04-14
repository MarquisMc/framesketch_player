import 'package:equatable/equatable.dart';

class ProjectLibraryEntry extends Equatable {
  final String id;
  final String title;
  final String sourcePath;
  final String sourceLabel;
  final String? originalTitle;
  final String? originalSourcePath;
  final String? originalSourceLabel;
  final String? youtubeUrl;
  final String? thumbnailPath;
  final String? thumbnailUrl;
  final DateTime lastOpenedAt;
  final DateTime updatedAt;
  final bool isPinned;
  final DateTime? pinnedAt;

  const ProjectLibraryEntry({
    required this.id,
    required this.title,
    required this.sourcePath,
    required this.sourceLabel,
    this.originalTitle,
    this.originalSourcePath,
    this.originalSourceLabel,
    required this.lastOpenedAt,
    required this.updatedAt,
    this.youtubeUrl,
    this.thumbnailPath,
    this.thumbnailUrl,
    this.isPinned = false,
    this.pinnedAt,
  });

  bool get isYouTubeProject =>
      youtubeUrl != null && youtubeUrl!.trim().isNotEmpty;

  bool get isLocalFileProject => !isYouTubeProject;

  bool get canRevertToOriginalName {
    if (!isLocalFileProject) return false;
    final originalPath = originalSourcePath?.trim();
    final originalName = originalTitle?.trim();
    final trimmedSourcePath = sourcePath.trim();
    final trimmedTitle = title.trim();
    if (originalPath == null || originalPath.isEmpty) return false;
    if (originalName == null || originalName.isEmpty) return false;
    return originalPath != trimmedSourcePath || originalName != trimmedTitle;
  }

  ProjectLibraryEntry copyWith({
    String? id,
    String? title,
    String? sourcePath,
    String? sourceLabel,
    String? originalTitle,
    String? originalSourcePath,
    String? originalSourceLabel,
    String? youtubeUrl,
    String? thumbnailPath,
    String? thumbnailUrl,
    DateTime? lastOpenedAt,
    DateTime? updatedAt,
    bool? isPinned,
    DateTime? pinnedAt,
    bool clearPinnedAt = false,
  }) {
    return ProjectLibraryEntry(
      id: id ?? this.id,
      title: title ?? this.title,
      sourcePath: sourcePath ?? this.sourcePath,
      sourceLabel: sourceLabel ?? this.sourceLabel,
      originalTitle: originalTitle ?? this.originalTitle,
      originalSourcePath: originalSourcePath ?? this.originalSourcePath,
      originalSourceLabel: originalSourceLabel ?? this.originalSourceLabel,
      youtubeUrl: youtubeUrl ?? this.youtubeUrl,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      lastOpenedAt: lastOpenedAt ?? this.lastOpenedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isPinned: isPinned ?? this.isPinned,
      pinnedAt: clearPinnedAt ? null : (pinnedAt ?? this.pinnedAt),
    );
  }

  factory ProjectLibraryEntry.fromJson(Map<String, dynamic> json) {
    final fallbackDate = DateTime.fromMillisecondsSinceEpoch(0);
    return ProjectLibraryEntry(
      id: json['id'] as String,
      title: json['title'] as String,
      sourcePath: json['sourcePath'] as String,
      sourceLabel: json['sourceLabel'] as String? ?? '',
      originalTitle:
          json['originalTitle'] as String? ?? json['title'] as String?,
      originalSourcePath:
          json['originalSourcePath'] as String? ??
          json['sourcePath'] as String?,
      originalSourceLabel:
          json['originalSourceLabel'] as String? ??
          json['sourceLabel'] as String? ??
          '',
      youtubeUrl: json['youtubeUrl'] as String?,
      thumbnailPath: json['thumbnailPath'] as String?,
      thumbnailUrl: json['thumbnailUrl'] as String?,
      lastOpenedAt:
          DateTime.tryParse(json['lastOpenedAt'] as String? ?? '') ??
          fallbackDate,
      updatedAt:
          DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? fallbackDate,
      isPinned: json['isPinned'] as bool? ?? false,
      pinnedAt: DateTime.tryParse(json['pinnedAt'] as String? ?? ''),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'title': title,
      'sourcePath': sourcePath,
      'sourceLabel': sourceLabel,
      'originalTitle': originalTitle,
      'originalSourcePath': originalSourcePath,
      'originalSourceLabel': originalSourceLabel,
      'youtubeUrl': youtubeUrl,
      'thumbnailPath': thumbnailPath,
      'thumbnailUrl': thumbnailUrl,
      'lastOpenedAt': lastOpenedAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'isPinned': isPinned,
      'pinnedAt': pinnedAt?.toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [
    id,
    title,
    sourcePath,
    sourceLabel,
    originalTitle,
    originalSourcePath,
    originalSourceLabel,
    youtubeUrl,
    thumbnailPath,
    thumbnailUrl,
    lastOpenedAt,
    updatedAt,
    isPinned,
    pinnedAt,
  ];

  @override
  bool get stringify => true;
}
