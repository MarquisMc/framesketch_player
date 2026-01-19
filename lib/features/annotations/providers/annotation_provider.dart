import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/stroke.dart';
import '../../../core/models/annotation_data.dart';
import '../../../core/services/annotation_storage_service.dart';
import '../../player/providers/player_provider.dart';

/// Annotation state
class AnnotationState {
  final AnnotationData? annotationData;
  final List<Stroke> undoStack;
  final List<Stroke> redoStack;
  final DrawingTool currentTool;
  final Color currentColor;
  final double currentStrokeWidth;
  final Stroke? currentStroke;
  final bool isDrawing;
  final bool hasUnsavedChanges;

  const AnnotationState({
    this.annotationData,
    this.undoStack = const [],
    this.redoStack = const [],
    this.currentTool = DrawingTool.pen,
    this.currentColor = Colors.red,
    this.currentStrokeWidth = 3.0,
    this.currentStroke,
    this.isDrawing = false,
    this.hasUnsavedChanges = false,
  });

  AnnotationState copyWith({
    AnnotationData? annotationData,
    List<Stroke>? undoStack,
    List<Stroke>? redoStack,
    DrawingTool? currentTool,
    Color? currentColor,
    double? currentStrokeWidth,
    Stroke? currentStroke,
    bool? isDrawing,
    bool? hasUnsavedChanges,
  }) {
    return AnnotationState(
      annotationData: annotationData ?? this.annotationData,
      undoStack: undoStack ?? this.undoStack,
      redoStack: redoStack ?? this.redoStack,
      currentTool: currentTool ?? this.currentTool,
      currentColor: currentColor ?? this.currentColor,
      currentStrokeWidth: currentStrokeWidth ?? this.currentStrokeWidth,
      currentStroke: currentStroke,
      isDrawing: isDrawing ?? this.isDrawing,
      hasUnsavedChanges: hasUnsavedChanges ?? this.hasUnsavedChanges,
    );
  }

  List<Stroke> get allStrokes {
    return annotationData?.strokes ?? [];
  }
}

/// Annotation notifier
class AnnotationNotifier extends StateNotifier<AnnotationState> {
  final AnnotationStorageService _storageService;
  final Ref ref;
  final _uuid = const Uuid();

  AnnotationNotifier(this._storageService, this.ref)
      : super(const AnnotationState());

  /// Initialize annotations for a video
  Future<void> initializeForVideo(String videoPath, double fps) async {
    // Try to load existing annotations
    final existingData = await _storageService.loadAnnotations(videoPath);

    if (existingData != null) {
      state = state.copyWith(
        annotationData: existingData,
        hasUnsavedChanges: false,
      );
    } else {
      // Create new annotation data
      final videoId = _storageService.generateVideoId(videoPath);
      final newData = AnnotationData(
        videoId: videoId,
        videoPath: videoPath,
        fps: fps,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      state = state.copyWith(
        annotationData: newData,
        hasUnsavedChanges: false,
      );
    }
  }

  /// Set current drawing tool
  void setTool(DrawingTool tool) {
    state = state.copyWith(currentTool: tool);
  }

  /// Set current color
  void setColor(Color color) {
    state = state.copyWith(currentColor: color);
  }

  /// Set stroke width
  void setStrokeWidth(double width) {
    state = state.copyWith(currentStrokeWidth: width);
  }

  /// Start drawing a new stroke
  void startStroke(StrokePoint point) {
    final currentTimeMs = ref.read(playerProvider).position.inMilliseconds;

    final newStroke = Stroke(
      id: _uuid.v4(),
      tool: state.currentTool,
      color: state.currentColor,
      strokeWidth: state.currentStrokeWidth,
      points: [point],
      startTimeMs: currentTimeMs,
      endTimeMs: currentTimeMs,
    );

    state = state.copyWith(
      currentStroke: newStroke,
      isDrawing: true,
    );
  }

  /// Add point to current stroke
  void addPointToStroke(StrokePoint point) {
    if (state.currentStroke == null) return;

    final currentTimeMs = ref.read(playerProvider).position.inMilliseconds;

    final updatedPoints = [...state.currentStroke!.points, point];
    final updatedStroke = state.currentStroke!.copyWith(
      points: updatedPoints,
      endTimeMs: currentTimeMs,
    );

    state = state.copyWith(currentStroke: updatedStroke);
  }

  /// Finish current stroke
  void finishStroke() {
    if (state.currentStroke == null) return;

    // Add stroke to annotation data
    final updatedStrokes = [...state.allStrokes, state.currentStroke!];
    final updatedData = state.annotationData!.copyWith(
      strokes: updatedStrokes,
      updatedAt: DateTime.now(),
    );

    state = state.copyWith(
      annotationData: updatedData,
      currentStroke: null,
      isDrawing: false,
      hasUnsavedChanges: true,
      redoStack: [], // Clear redo stack when new action is performed
    );
  }

  /// Cancel current stroke
  void cancelStroke() {
    state = state.copyWith(
      currentStroke: null,
      isDrawing: false,
    );
  }

  /// Undo last stroke
  void undo() {
    if (state.allStrokes.isEmpty) return;

    final strokes = List<Stroke>.from(state.allStrokes);
    final lastStroke = strokes.removeLast();

    final updatedData = state.annotationData!.copyWith(
      strokes: strokes,
      updatedAt: DateTime.now(),
    );

    state = state.copyWith(
      annotationData: updatedData,
      undoStack: [...state.undoStack, lastStroke],
      hasUnsavedChanges: true,
    );
  }

  /// Redo last undone stroke
  void redo() {
    if (state.undoStack.isEmpty) return;

    final undoStack = List<Stroke>.from(state.undoStack);
    final strokeToRedo = undoStack.removeLast();

    final updatedStrokes = [...state.allStrokes, strokeToRedo];
    final updatedData = state.annotationData!.copyWith(
      strokes: updatedStrokes,
      updatedAt: DateTime.now(),
    );

    state = state.copyWith(
      annotationData: updatedData,
      undoStack: undoStack,
      hasUnsavedChanges: true,
    );
  }

  /// Clear all annotations
  void clearAll() {
    final updatedData = state.annotationData!.copyWith(
      strokes: [],
      updatedAt: DateTime.now(),
    );

    state = state.copyWith(
      annotationData: updatedData,
      undoStack: [],
      redoStack: [],
      hasUnsavedChanges: true,
    );
  }

  /// Save annotations to file
  Future<bool> saveAnnotations() async {
    if (state.annotationData == null) return false;

    final success = await _storageService.saveAnnotations(state.annotationData!);

    if (success) {
      state = state.copyWith(hasUnsavedChanges: false);
    }

    return success;
  }

  /// Check if can undo
  bool get canUndo => state.allStrokes.isNotEmpty;

  /// Check if can redo
  bool get canRedo => state.undoStack.isNotEmpty;
}

/// Annotation provider instance
final annotationProvider =
    StateNotifierProvider<AnnotationNotifier, AnnotationState>((ref) {
  return AnnotationNotifier(AnnotationStorageService(), ref);
});
