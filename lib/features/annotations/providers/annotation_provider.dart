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
  final String? selectedStrokeId;
  final StrokePoint? dragStartPoint;

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
    this.selectedStrokeId,
    this.dragStartPoint,
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
    String? selectedStrokeId,
    StrokePoint? dragStartPoint,
    bool clearSelectedStroke = false,
    bool clearDragStartPoint = false,
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
      selectedStrokeId: clearSelectedStroke ? null : (selectedStrokeId ?? this.selectedStrokeId),
      dragStartPoint: clearDragStartPoint ? null : (dragStartPoint ?? this.dragStartPoint),
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

    // If eraser tool, start erasing strokes instead of drawing
    if (state.currentTool == DrawingTool.eraser) {
      _eraseStrokesAtPoint(point);
      state = state.copyWith(isDrawing: true);
      return;
    }

    // If select tool, try to select a stroke
    if (state.currentTool == DrawingTool.select) {
      final selectedStroke = _findStrokeAtPoint(point);
      state = state.copyWith(
        selectedStrokeId: selectedStroke?.id,
        dragStartPoint: point,
        isDrawing: true,
        clearSelectedStroke: selectedStroke == null,
      );
      return;
    }

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
    // If eraser tool, continue erasing
    if (state.currentTool == DrawingTool.eraser) {
      _eraseStrokesAtPoint(point);
      return;
    }

    // If select tool, move the selected stroke
    if (state.currentTool == DrawingTool.select) {
      if (state.selectedStrokeId != null && state.dragStartPoint != null) {
        _moveSelectedStroke(point);
      }
      return;
    }

    if (state.currentStroke == null) return;

    final currentTimeMs = ref.read(playerProvider).position.inMilliseconds;

    // For shape tools (rectangle, circle, line, arrow), keep only start and end points
    final isShapeTool = state.currentTool == DrawingTool.rectangle ||
        state.currentTool == DrawingTool.circle ||
        state.currentTool == DrawingTool.line ||
        state.currentTool == DrawingTool.arrow;

    final List<StrokePoint> updatedPoints;
    if (isShapeTool) {
      // Replace the last point for shapes (start point stays, end point updates)
      updatedPoints = [state.currentStroke!.points.first, point];
    } else {
      // Add all points for pen tool (freehand drawing)
      updatedPoints = [...state.currentStroke!.points, point];
    }

    final updatedStroke = state.currentStroke!.copyWith(
      points: updatedPoints,
      endTimeMs: currentTimeMs,
    );

    state = state.copyWith(currentStroke: updatedStroke);
  }

  /// Finish current stroke
  void finishStroke() {
    // If eraser tool, just stop erasing
    if (state.currentTool == DrawingTool.eraser) {
      state = state.copyWith(isDrawing: false);
      return;
    }

    // If select tool, just stop dragging (keep selection)
    if (state.currentTool == DrawingTool.select) {
      state = state.copyWith(isDrawing: false, clearDragStartPoint: true);
      return;
    }

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

  /// Erase parts of strokes at a given point (for eraser tool)
  void _eraseStrokesAtPoint(StrokePoint point) {
    if (state.annotationData == null) return;

    // Eraser radius (in normalized coordinates)
    const eraserRadius = 0.02;

    // Process each stroke and split/remove affected parts
    final updatedStrokes = <Stroke>[];
    bool hasChanges = false;

    for (final stroke in state.allStrokes) {
      final segments = _eraseFromStroke(stroke, point, eraserRadius);

      if (segments.isEmpty) {
        // Entire stroke was erased
        hasChanges = true;
      } else if (segments.length == 1 && segments[0].points.length == stroke.points.length) {
        // Stroke unchanged
        updatedStrokes.add(stroke);
      } else {
        // Stroke was split or partially erased
        updatedStrokes.addAll(segments);
        hasChanges = true;
      }
    }

    // If any changes occurred, update state
    if (hasChanges) {
      final updatedData = state.annotationData!.copyWith(
        strokes: updatedStrokes,
        updatedAt: DateTime.now(),
      );

      state = state.copyWith(
        annotationData: updatedData,
        hasUnsavedChanges: true,
      );
    }
  }

  /// Erase part of a stroke and return remaining segments
  List<Stroke> _eraseFromStroke(Stroke stroke, StrokePoint eraserPoint, double eraserRadius) {
    if (stroke.points.isEmpty) return [];

    // Mark which points should be erased
    final shouldErase = List<bool>.generate(
      stroke.points.length,
      (i) => _pointIntersectsEraser(stroke.points[i], eraserPoint, eraserRadius),
    );

    // If no points are erased, return original stroke
    if (!shouldErase.contains(true)) {
      return [stroke];
    }

    // If all points are erased, return empty list
    if (!shouldErase.contains(false)) {
      return [];
    }

    // Split stroke into segments at erased points
    final segments = <Stroke>[];
    List<StrokePoint> currentSegment = [];

    for (int i = 0; i < stroke.points.length; i++) {
      if (shouldErase[i]) {
        // Point is erased - save current segment if it has points
        if (currentSegment.length >= 2) {
          segments.add(_createStrokeSegment(stroke, currentSegment));
        }
        currentSegment = [];
      } else {
        // Point is kept - add to current segment
        currentSegment.add(stroke.points[i]);
      }
    }

    // Add final segment if it has points
    if (currentSegment.length >= 2) {
      segments.add(_createStrokeSegment(stroke, currentSegment));
    }

    return segments;
  }

  /// Create a new stroke segment with the same properties as the original
  Stroke _createStrokeSegment(Stroke original, List<StrokePoint> points) {
    return Stroke(
      id: _uuid.v4(), // New ID for the segment
      tool: original.tool,
      color: original.color,
      strokeWidth: original.strokeWidth,
      points: points,
      startTimeMs: points.first.timestampMs,
      endTimeMs: points.last.timestampMs,
    );
  }

  /// Check if a point intersects with the eraser
  bool _pointIntersectsEraser(StrokePoint point, StrokePoint eraserPoint, double radius) {
    final dx = point.x - eraserPoint.x;
    final dy = point.y - eraserPoint.y;
    final distanceSquared = dx * dx + dy * dy;
    return distanceSquared <= radius * radius;
  }

  /// Find a stroke at the given point
  Stroke? _findStrokeAtPoint(StrokePoint point) {
    const selectionRadius = 0.02; // Selection tolerance in normalized coordinates

    // Search in reverse order to select the topmost stroke
    for (int i = state.allStrokes.length - 1; i >= 0; i--) {
      final stroke = state.allStrokes[i];

      // For shape tools, check if point is near the shape boundary
      if (stroke.tool == DrawingTool.rectangle) {
        if (_isPointNearRectangle(stroke, point, selectionRadius)) {
          return stroke;
        }
      } else if (stroke.tool == DrawingTool.circle) {
        if (_isPointNearCircle(stroke, point, selectionRadius)) {
          return stroke;
        }
      } else if (stroke.tool == DrawingTool.line || stroke.tool == DrawingTool.arrow) {
        if (_isPointNearLine(stroke, point, selectionRadius)) {
          return stroke;
        }
      } else {
        // For pen strokes, check if point is near any part of the path
        for (final strokePoint in stroke.points) {
          if (_pointIntersectsEraser(strokePoint, point, selectionRadius)) {
            return stroke;
          }
        }
      }
    }
    return null;
  }

  /// Check if point is near a rectangle stroke
  bool _isPointNearRectangle(Stroke stroke, StrokePoint point, double threshold) {
    if (stroke.points.length < 2) return false;

    final p1 = stroke.points.first;
    final p2 = stroke.points.last;

    final left = p1.x < p2.x ? p1.x : p2.x;
    final right = p1.x > p2.x ? p1.x : p2.x;
    final top = p1.y < p2.y ? p1.y : p2.y;
    final bottom = p1.y > p2.y ? p1.y : p2.y;

    // Check if point is inside the rectangle bounds (with some tolerance)
    return point.x >= left - threshold &&
           point.x <= right + threshold &&
           point.y >= top - threshold &&
           point.y <= bottom + threshold;
  }

  /// Check if point is near a circle/ellipse stroke
  bool _isPointNearCircle(Stroke stroke, StrokePoint point, double threshold) {
    if (stroke.points.length < 2) return false;

    final p1 = stroke.points.first;
    final p2 = stroke.points.last;

    final centerX = (p1.x + p2.x) / 2;
    final centerY = (p1.y + p2.y) / 2;
    final radiusX = (p2.x - p1.x).abs() / 2;
    final radiusY = (p2.y - p1.y).abs() / 2;

    // Check if point is inside the ellipse bounds
    final dx = point.x - centerX;
    final dy = point.y - centerY;

    if (radiusX == 0 || radiusY == 0) return false;

    final distance = (dx * dx) / (radiusX * radiusX) + (dy * dy) / (radiusY * radiusY);
    return distance <= 1.2; // Slightly larger than the ellipse for easier selection
  }

  /// Check if point is near a line/arrow stroke
  bool _isPointNearLine(Stroke stroke, StrokePoint point, double threshold) {
    if (stroke.points.length < 2) return false;

    final p1 = stroke.points.first;
    final p2 = stroke.points.last;

    // Calculate distance from point to line segment
    final lineLength = ((p2.x - p1.x) * (p2.x - p1.x) + (p2.y - p1.y) * (p2.y - p1.y));

    if (lineLength == 0) {
      // Line is actually a point
      return _pointIntersectsEraser(p1, point, threshold);
    }

    // Project point onto line
    final t = ((point.x - p1.x) * (p2.x - p1.x) + (point.y - p1.y) * (p2.y - p1.y)) / lineLength;
    final tClamped = t.clamp(0.0, 1.0);

    final projX = p1.x + tClamped * (p2.x - p1.x);
    final projY = p1.y + tClamped * (p2.y - p1.y);

    final dx = point.x - projX;
    final dy = point.y - projY;
    final distance = (dx * dx + dy * dy);

    return distance <= threshold * threshold;
  }

  /// Move the selected stroke by the drag offset
  void _moveSelectedStroke(StrokePoint currentPoint) {
    if (state.selectedStrokeId == null || state.dragStartPoint == null) return;

    final strokeIndex = state.allStrokes.indexWhere((s) => s.id == state.selectedStrokeId);
    if (strokeIndex == -1) return;

    final stroke = state.allStrokes[strokeIndex];
    final dx = currentPoint.x - state.dragStartPoint!.x;
    final dy = currentPoint.y - state.dragStartPoint!.y;

    // Move all points by the offset
    final movedPoints = stroke.points.map((p) {
      return StrokePoint(
        x: p.x + dx,
        y: p.y + dy,
        timestampMs: p.timestampMs,
      );
    }).toList();

    final movedStroke = stroke.copyWith(points: movedPoints);

    // Update the stroke in the list
    final updatedStrokes = List<Stroke>.from(state.allStrokes);
    updatedStrokes[strokeIndex] = movedStroke;

    final updatedData = state.annotationData!.copyWith(
      strokes: updatedStrokes,
      updatedAt: DateTime.now(),
    );

    state = state.copyWith(
      annotationData: updatedData,
      dragStartPoint: currentPoint, // Update drag start for next move
      hasUnsavedChanges: true,
    );
  }

  /// Deselect the currently selected stroke
  void deselectStroke() {
    state = state.copyWith(clearSelectedStroke: true);
  }
}

/// Annotation provider instance
final annotationProvider =
    StateNotifierProvider<AnnotationNotifier, AnnotationState>((ref) {
  return AnnotationNotifier(AnnotationStorageService(), ref);
});
