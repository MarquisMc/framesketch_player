import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/stroke.dart';
import '../../../core/models/annotation_data.dart';
import '../../../core/services/annotation_storage_service.dart';
import '../../../core/utils/coordinate_transformer.dart';
import '../../player/providers/player_provider.dart';

enum KeyframeCreationMode { automatic, manual }

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
  final List<String> selectedStrokeIds;
  final StrokePoint? dragStartPoint;
  final StrokePoint? selectionBoxStartPoint;
  final StrokePoint? selectionBoxEndPoint;
  final bool isBoxSelecting;
  final double currentFontSize;
  final String? pendingTextStrokeId;
  final bool isScaling;
  final String? scalingCorner;
  final KeyframeCreationMode keyframeCreationMode;

  const AnnotationState({
    this.annotationData,
    this.undoStack = const [],
    this.redoStack = const [],
    this.currentTool = DrawingTool.pen,
    this.currentColor = const Color(0xFF58D3C4),
    this.currentStrokeWidth = 3.0,
    this.currentStroke,
    this.isDrawing = false,
    this.hasUnsavedChanges = false,
    this.selectedStrokeId,
    this.selectedStrokeIds = const [],
    this.dragStartPoint,
    this.selectionBoxStartPoint,
    this.selectionBoxEndPoint,
    this.isBoxSelecting = false,
    this.currentFontSize = 16.0,
    this.pendingTextStrokeId,
    this.isScaling = false,
    this.scalingCorner,
    this.keyframeCreationMode = KeyframeCreationMode.automatic,
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
    List<String>? selectedStrokeIds,
    StrokePoint? dragStartPoint,
    StrokePoint? selectionBoxStartPoint,
    StrokePoint? selectionBoxEndPoint,
    bool? isBoxSelecting,
    bool clearSelectedStroke = false,
    bool clearDragStartPoint = false,
    bool clearSelectionBox = false,
    double? currentFontSize,
    String? pendingTextStrokeId,
    bool clearPendingTextStrokeId = false,
    bool? isScaling,
    String? scalingCorner,
    bool clearScalingCorner = false,
    KeyframeCreationMode? keyframeCreationMode,
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
      selectedStrokeId: clearSelectedStroke
          ? null
          : (selectedStrokeId ?? this.selectedStrokeId),
      selectedStrokeIds: clearSelectedStroke
          ? const []
          : (selectedStrokeIds ?? this.selectedStrokeIds),
      dragStartPoint: clearDragStartPoint
          ? null
          : (dragStartPoint ?? this.dragStartPoint),
      selectionBoxStartPoint: clearSelectionBox
          ? null
          : (selectionBoxStartPoint ?? this.selectionBoxStartPoint),
      selectionBoxEndPoint: clearSelectionBox
          ? null
          : (selectionBoxEndPoint ?? this.selectionBoxEndPoint),
      isBoxSelecting: isBoxSelecting ?? this.isBoxSelecting,
      currentFontSize: currentFontSize ?? this.currentFontSize,
      pendingTextStrokeId: clearPendingTextStrokeId
          ? null
          : (pendingTextStrokeId ?? this.pendingTextStrokeId),
      isScaling: isScaling ?? this.isScaling,
      scalingCorner: clearScalingCorner
          ? null
          : (scalingCorner ?? this.scalingCorner),
      keyframeCreationMode: keyframeCreationMode ?? this.keyframeCreationMode,
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

  double get _effectiveFps {
    final annotationFps = state.annotationData?.fps;
    if (annotationFps != null && annotationFps > 0) {
      return annotationFps;
    }

    final playerFps = ref.read(playerProvider).metadata?.fps;
    if (playerFps != null && playerFps > 0) {
      return playerFps;
    }

    return 30.0;
  }

  Size? _effectiveVideoSizeForTransform() {
    final playerState = ref.read(playerProvider);
    final rect = playerState.videoController?.rect.value;
    if (rect != null && rect.width > 1 && rect.height > 1) {
      return Size(rect.width, rect.height);
    }

    final metadata = playerState.metadata;
    if (metadata == null || metadata.width <= 0 || metadata.height <= 0) {
      return null;
    }

    return Size(metadata.width.toDouble(), metadata.height.toDouble());
  }

  int _snapToFrameTimeMs(int positionMs, double fps) {
    if (fps <= 0) return positionMs;
    final frameDurationMs = 1000.0 / fps;
    final frameIndex = (positionMs / frameDurationMs).round();
    return (frameIndex * frameDurationMs).round();
  }

  int _currentFrameTimeMs() {
    final currentPositionMs = ref.read(playerProvider).position.inMilliseconds;
    return _snapToFrameTimeMs(currentPositionMs, _effectiveFps);
  }

  int _strokeFrameTimeMs() {
    final currentPositionMs = ref.read(playerProvider).position.inMilliseconds;
    if (state.keyframeCreationMode == KeyframeCreationMode.automatic) {
      return _snapToFrameTimeMs(currentPositionMs, _effectiveFps);
    }

    final activeKeyframeMs = _activeKeyframeTimeMsAt(currentPositionMs);
    return activeKeyframeMs ??
        _snapToFrameTimeMs(currentPositionMs, _effectiveFps);
  }

  List<int> _sortedKeyframeTimesMs() {
    if (state.allStrokes.isEmpty) return const [];

    final fps = _effectiveFps;
    final uniqueKeyframes = <int>{};

    for (final stroke in state.allStrokes) {
      uniqueKeyframes.add(_snapToFrameTimeMs(stroke.startTimeMs, fps));
    }

    final sorted = uniqueKeyframes.toList()..sort();
    return sorted;
  }

  int? _activeKeyframeTimeMsAt(int positionMs) {
    final keyframes = _sortedKeyframeTimesMs();
    if (keyframes.isEmpty) return null;
    final snappedPositionMs = _snapToFrameTimeMs(positionMs, _effectiveFps);

    // Exact keyframe match for the current frame gets highest priority.
    if (keyframes.contains(snappedPositionMs)) {
      return snappedPositionMs;
    }

    int? activeKeyframe;
    for (final keyframeMs in keyframes) {
      if (keyframeMs <= snappedPositionMs) {
        activeKeyframe = keyframeMs;
      } else {
        break;
      }
    }

    return activeKeyframe;
  }

  List<Stroke> _strokesAtKeyframe(int keyframeMs) {
    final fps = _effectiveFps;
    return state.allStrokes
        .where(
          (stroke) => _snapToFrameTimeMs(stroke.startTimeMs, fps) == keyframeMs,
        )
        .toList();
  }

  /// Initialize annotations for a video
  Future<void> initializeForVideo(String videoPath, double fps) async {
    // Try to load existing annotations
    final existingData = await _storageService.loadAnnotations(videoPath);

    if (existingData != null) {
      final migratedData = _migrateLegacyCoordinatesIfNeeded(existingData);
      final didMigrate = migratedData != existingData;

      state = state.copyWith(
        annotationData: migratedData,
        hasUnsavedChanges: didMigrate,
      );

      if (didMigrate) {
        final persisted = await _storageService.saveAnnotations(migratedData);
        if (persisted) {
          state = state.copyWith(hasUnsavedChanges: false);
        }
      }
    } else {
      // Create new annotation data
      final videoId = _storageService.generateVideoId(videoPath);
      final newData = AnnotationData(
        videoId: videoId,
        videoPath: videoPath,
        fps: fps,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        // 0/0 marks the modern coordinate space (video-normalized).
        viewportWidth: 0,
        viewportHeight: 0,
      );

      state = state.copyWith(annotationData: newData, hasUnsavedChanges: false);
    }
  }

  AnnotationData _migrateLegacyCoordinatesIfNeeded(AnnotationData data) {
    if (data.viewportWidth <= 0 || data.viewportHeight <= 0) {
      return data;
    }

    final effectiveVideoSize = _effectiveVideoSizeForTransform();
    if (effectiveVideoSize == null ||
        effectiveVideoSize.width <= 0 ||
        effectiveVideoSize.height <= 0) {
      return data;
    }

    final migratedStrokes = data.strokes.map((stroke) {
      final migratedPoints = stroke.points
          .map(
            (point) =>
                CoordinateTransformer.legacyViewportNormalizedToVideoNormalized(
                  point: point,
                  legacyViewportWidth: data.viewportWidth,
                  legacyViewportHeight: data.viewportHeight,
                  videoWidth: effectiveVideoSize.width.round(),
                  videoHeight: effectiveVideoSize.height.round(),
                ),
          )
          .toList();
      return stroke.copyWith(points: migratedPoints);
    }).toList();

    return data.copyWith(
      strokes: migratedStrokes,
      // Keep using existing field for backwards compatibility while marking
      // that coordinates are now video-normalized.
      viewportWidth: 0,
      viewportHeight: 0,
      updatedAt: DateTime.now(),
    );
  }

  /// Set current drawing tool
  void setTool(DrawingTool tool) {
    state = state.copyWith(currentTool: tool);
  }

  /// Toggle whether keyframes are created automatically while drawing.
  void setKeyframeCreationMode(KeyframeCreationMode mode) {
    if (state.keyframeCreationMode == mode) return;
    state = state.copyWith(keyframeCreationMode: mode);
  }

  /// Creates a keyframe at the current frame in manual mode by duplicating
  /// no annotation content, matching automatic keyframe behavior.
  void createManualKeyframeAtCurrentFrame() {
    if (state.keyframeCreationMode != KeyframeCreationMode.manual ||
        state.annotationData == null) {
      return;
    }

    final currentFrameMs = _currentFrameTimeMs();
    final keyframes = _sortedKeyframeTimesMs();
    if (keyframes.contains(currentFrameMs)) {
      return;
    }

    final markerStroke = Stroke(
      id: _uuid.v4(),
      tool: DrawingTool.text,
      color: Colors.transparent,
      strokeWidth: 0,
      points: const [StrokePoint(x: 0, y: 0)],
      startTimeMs: currentFrameMs,
      endTimeMs: currentFrameMs,
      text: '',
      fontSize: 1,
    );

    final updatedData = state.annotationData!.copyWith(
      strokes: [...state.allStrokes, markerStroke],
      updatedAt: DateTime.now(),
    );

    state = state.copyWith(
      annotationData: updatedData,
      hasUnsavedChanges: true,
      redoStack: [],
    );
  }

  /// Whether creating a manual keyframe at the current frame is possible.
  bool canCreateManualKeyframeAtCurrentFrame() {
    if (state.keyframeCreationMode != KeyframeCreationMode.manual ||
        state.annotationData == null) {
      return false;
    }

    final currentFrameMs = _currentFrameTimeMs();
    if (_sortedKeyframeTimesMs().contains(currentFrameMs)) {
      return false;
    }

    return true;
  }

  /// Set current color
  void setColor(Color color) {
    state = state.copyWith(currentColor: color);
  }

  /// Set stroke width
  void setStrokeWidth(double width) {
    state = state.copyWith(currentStrokeWidth: width);
  }

  /// Set font size for text tool
  void setFontSize(double size) {
    state = state.copyWith(currentFontSize: size);
  }

  /// Start drawing a new stroke
  void startStroke(StrokePoint point) {
    final currentTimeMs = _strokeFrameTimeMs();

    // If eraser tool, start erasing strokes instead of drawing
    if (state.currentTool == DrawingTool.eraser) {
      _eraseStrokesAtPoint(point);
      state = state.copyWith(isDrawing: true);
      return;
    }

    // If select tool, try to select a stroke
    if (state.currentTool == DrawingTool.select) {
      final selectedStroke = _findStrokeAtPoint(point);
      final selectedIds = state.selectedStrokeIds;

      if (selectedStroke != null) {
        final nextSelected = selectedIds.contains(selectedStroke.id)
            ? selectedIds
            : <String>[selectedStroke.id];
        state = state.copyWith(
          selectedStrokeId: selectedStroke.id,
          selectedStrokeIds: nextSelected,
          dragStartPoint: point,
          isDrawing: true,
          isBoxSelecting: false,
          clearSelectionBox: true,
        );
        return;
      }

      state = state.copyWith(
        selectedStrokeIds: const [],
        dragStartPoint: point,
        selectionBoxStartPoint: point,
        selectionBoxEndPoint: point,
        isDrawing: true,
        isBoxSelecting: true,
        clearSelectedStroke: true,
      );
      return;
    }

    // If text tool, create stroke at click position and trigger dialog
    if (state.currentTool == DrawingTool.text) {
      final newStroke = Stroke(
        id: _uuid.v4(),
        tool: DrawingTool.text,
        color: state.currentColor,
        strokeWidth: state.currentStrokeWidth,
        points: [point],
        startTimeMs: currentTimeMs,
        endTimeMs: currentTimeMs,
        text: '',
        fontSize: state.currentFontSize,
      );

      final updatedStrokes = [...state.allStrokes, newStroke];
      final updatedData = state.annotationData!.copyWith(
        strokes: updatedStrokes,
        updatedAt: DateTime.now(),
      );

      state = state.copyWith(
        annotationData: updatedData,
        pendingTextStrokeId: newStroke.id,
        isDrawing: false,
        hasUnsavedChanges: true,
        redoStack: [],
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

    state = state.copyWith(currentStroke: newStroke, isDrawing: true);
  }

  /// Add point to current stroke
  void addPointToStroke(StrokePoint point) {
    // If eraser tool, continue erasing
    if (state.currentTool == DrawingTool.eraser) {
      _eraseStrokesAtPoint(point);
      return;
    }

    // Text tool does not use drag
    if (state.currentTool == DrawingTool.text) return;

    // If select tool, move the selected stroke
    if (state.currentTool == DrawingTool.select) {
      if (state.isBoxSelecting && state.selectionBoxStartPoint != null) {
        _updateBoxSelection(point);
      } else if (state.selectedStrokeIds.isNotEmpty &&
          state.dragStartPoint != null) {
        _moveSelectedStrokes(point);
      }
      return;
    }

    if (state.currentStroke == null) return;

    // For shape tools (rectangle, circle, line, arrow), keep only start and end points
    final isShapeTool =
        state.currentTool == DrawingTool.rectangle ||
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

    final updatedStroke = state.currentStroke!.copyWith(points: updatedPoints);

    state = state.copyWith(currentStroke: updatedStroke);
  }

  /// Finish current stroke
  void finishStroke() {
    // If eraser tool, just stop erasing
    if (state.currentTool == DrawingTool.eraser) {
      state = state.copyWith(isDrawing: false);
      return;
    }

    // Text tool finishes via dialog, not drag
    if (state.currentTool == DrawingTool.text) {
      state = state.copyWith(isDrawing: false);
      return;
    }

    // If select tool, just stop dragging (keep selection)
    if (state.currentTool == DrawingTool.select) {
      state = state.copyWith(
        isDrawing: false,
        isBoxSelecting: false,
        clearDragStartPoint: true,
        clearSelectionBox: true,
      );
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
      isBoxSelecting: false,
      clearSelectionBox: true,
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

    final success = await _storageService.saveAnnotations(
      state.annotationData!,
    );

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
    final activeKeyframeMs = _activeKeyframeTimeMsAt(
      ref.read(playerProvider).position.inMilliseconds,
    );
    if (activeKeyframeMs == null) return;

    // Eraser radius (in normalized coordinates)
    const eraserRadius = 0.02;

    // Process each stroke and split/remove affected parts
    final updatedStrokes = <Stroke>[];
    bool hasChanges = false;
    final fps = _effectiveFps;

    for (final stroke in state.allStrokes) {
      final strokeKeyframeMs = _snapToFrameTimeMs(stroke.startTimeMs, fps);
      if (strokeKeyframeMs != activeKeyframeMs) {
        updatedStrokes.add(stroke);
        continue;
      }

      final segments = _eraseFromStroke(stroke, point, eraserRadius);

      if (segments.isEmpty) {
        // Entire stroke was erased
        hasChanges = true;
      } else if (segments.length == 1 &&
          segments[0].points.length == stroke.points.length) {
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
  List<Stroke> _eraseFromStroke(
    Stroke stroke,
    StrokePoint eraserPoint,
    double eraserRadius,
  ) {
    if (stroke.points.isEmpty) return [];

    // Mark which points should be erased
    final shouldErase = List<bool>.generate(
      stroke.points.length,
      (i) =>
          _pointIntersectsEraser(stroke.points[i], eraserPoint, eraserRadius),
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
      startTimeMs: original.startTimeMs,
      endTimeMs: original.endTimeMs,
      text: original.text,
      fontSize: original.fontSize,
    );
  }

  /// Check if a point intersects with the eraser
  bool _pointIntersectsEraser(
    StrokePoint point,
    StrokePoint eraserPoint,
    double radius,
  ) {
    final dx = point.x - eraserPoint.x;
    final dy = point.y - eraserPoint.y;
    final distanceSquared = dx * dx + dy * dy;
    return distanceSquared <= radius * radius;
  }

  /// Find a stroke at the given point
  Stroke? _findStrokeAtPoint(StrokePoint point) {
    const selectionRadius =
        0.02; // Selection tolerance in normalized coordinates
    final activeKeyframeMs = _activeKeyframeTimeMsAt(
      ref.read(playerProvider).position.inMilliseconds,
    );
    if (activeKeyframeMs == null) return null;

    final visibleStrokes = _strokesAtKeyframe(activeKeyframeMs);

    // Search in reverse order to select the topmost stroke
    for (int i = visibleStrokes.length - 1; i >= 0; i--) {
      final stroke = visibleStrokes[i];

      // For shape tools, check if point is near the shape boundary
      if (stroke.tool == DrawingTool.rectangle) {
        if (_isPointNearRectangle(stroke, point, selectionRadius)) {
          return stroke;
        }
      } else if (stroke.tool == DrawingTool.circle) {
        if (_isPointNearCircle(stroke, point, selectionRadius)) {
          return stroke;
        }
      } else if (stroke.tool == DrawingTool.line ||
          stroke.tool == DrawingTool.arrow) {
        if (_isPointNearLine(stroke, point, selectionRadius)) {
          return stroke;
        }
      } else if (stroke.tool == DrawingTool.text) {
        if (_isPointNearText(stroke, point, selectionRadius)) {
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
  bool _isPointNearRectangle(
    Stroke stroke,
    StrokePoint point,
    double threshold,
  ) {
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

    final distance =
        (dx * dx) / (radiusX * radiusX) + (dy * dy) / (radiusY * radiusY);
    return distance <=
        1.2; // Slightly larger than the ellipse for easier selection
  }

  /// Check if point is near a line/arrow stroke
  bool _isPointNearLine(Stroke stroke, StrokePoint point, double threshold) {
    if (stroke.points.length < 2) return false;

    final p1 = stroke.points.first;
    final p2 = stroke.points.last;

    // Calculate distance from point to line segment
    final lineLength =
        ((p2.x - p1.x) * (p2.x - p1.x) + (p2.y - p1.y) * (p2.y - p1.y));

    if (lineLength == 0) {
      // Line is actually a point
      return _pointIntersectsEraser(p1, point, threshold);
    }

    // Project point onto line
    final t =
        ((point.x - p1.x) * (p2.x - p1.x) + (point.y - p1.y) * (p2.y - p1.y)) /
        lineLength;
    final tClamped = t.clamp(0.0, 1.0);

    final projX = p1.x + tClamped * (p2.x - p1.x);
    final projY = p1.y + tClamped * (p2.y - p1.y);

    final dx = point.x - projX;
    final dy = point.y - projY;
    final distance = (dx * dx + dy * dy);

    return distance <= threshold * threshold;
  }

  /// Check if point is near a text stroke bounding box
  bool _isPointNearText(Stroke stroke, StrokePoint point, double threshold) {
    if (stroke.points.isEmpty || stroke.text == null || stroke.text!.isEmpty)
      return false;

    final anchor = stroke.points.first;
    // Approximate text bounding box in normalized coordinates
    final textLength = stroke.text!.length;
    final estimatedWidth = textLength * 0.008 * (stroke.fontSize / 16.0);
    final estimatedHeight = 0.025 * (stroke.fontSize / 16.0);

    return point.x >= anchor.x - threshold &&
        point.x <= anchor.x + estimatedWidth + threshold &&
        point.y >= anchor.y - threshold &&
        point.y <= anchor.y + estimatedHeight + threshold;
  }

  /// Move the selected stroke by the drag offset
  void _moveSelectedStrokes(StrokePoint currentPoint) {
    if (state.selectedStrokeIds.isEmpty || state.dragStartPoint == null) return;

    final selectedSet = state.selectedStrokeIds.toSet();
    final dx = currentPoint.x - state.dragStartPoint!.x;
    final dy = currentPoint.y - state.dragStartPoint!.y;
    final updatedStrokes = List<Stroke>.from(state.allStrokes);

    for (int i = 0; i < updatedStrokes.length; i++) {
      final stroke = updatedStrokes[i];
      if (!selectedSet.contains(stroke.id)) continue;

      final movedPoints = stroke.points.map((p) {
        return StrokePoint(
          x: p.x + dx,
          y: p.y + dy,
          timestampMs: p.timestampMs,
        );
      }).toList();

      updatedStrokes[i] = stroke.copyWith(points: movedPoints);
    }

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

  void _updateBoxSelection(StrokePoint currentPoint) {
    final start = state.selectionBoxStartPoint;
    if (start == null) return;

    final left = start.x < currentPoint.x ? start.x : currentPoint.x;
    final right = start.x > currentPoint.x ? start.x : currentPoint.x;
    final top = start.y < currentPoint.y ? start.y : currentPoint.y;
    final bottom = start.y > currentPoint.y ? start.y : currentPoint.y;

    final selectedIds = <String>[];
    for (final stroke in getVisibleStrokes()) {
      final bounds = _strokeBounds(stroke);
      if (bounds == null) continue;

      final intersects =
          bounds.left <= right &&
          bounds.right >= left &&
          bounds.top <= bottom &&
          bounds.bottom >= top;
      if (intersects) {
        selectedIds.add(stroke.id);
      }
    }

    state = state.copyWith(
      selectionBoxEndPoint: currentPoint,
      selectedStrokeIds: selectedIds,
      selectedStrokeId: selectedIds.isNotEmpty ? selectedIds.first : null,
      clearSelectedStroke: selectedIds.isEmpty,
    );
  }

  Rect? _strokeBounds(Stroke stroke) {
    if (stroke.points.isEmpty) return null;

    if (stroke.tool == DrawingTool.text) {
      final anchor = stroke.points.first;
      final textLength = stroke.text?.length ?? 0;
      final estimatedWidth = textLength * 0.008 * (stroke.fontSize / 16.0);
      final estimatedHeight = 0.025 * (stroke.fontSize / 16.0);
      return Rect.fromLTRB(
        anchor.x,
        anchor.y,
        anchor.x + estimatedWidth,
        anchor.y + estimatedHeight,
      );
    }

    double minX = double.infinity;
    double minY = double.infinity;
    double maxX = double.negativeInfinity;
    double maxY = double.negativeInfinity;

    for (final point in stroke.points) {
      if (point.x < minX) minX = point.x;
      if (point.y < minY) minY = point.y;
      if (point.x > maxX) maxX = point.x;
      if (point.y > maxY) maxY = point.y;
    }

    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  /// Deselect the currently selected stroke
  void deselectStroke() {
    state = state.copyWith(
      clearSelectedStroke: true,
      clearSelectionBox: true,
      isBoxSelecting: false,
    );
  }

  /// Delete the currently selected stroke
  void deleteSelectedStroke() {
    if (state.selectedStrokeIds.isEmpty && state.selectedStrokeId == null)
      return;
    final selectedIds = state.selectedStrokeIds.isNotEmpty
        ? state.selectedStrokeIds.toSet()
        : <String>{if (state.selectedStrokeId != null) state.selectedStrokeId!};

    final updatedStrokes = state.allStrokes
        .where((s) => !selectedIds.contains(s.id))
        .toList();

    final updatedData = state.annotationData!.copyWith(
      strokes: updatedStrokes,
      updatedAt: DateTime.now(),
    );

    state = state.copyWith(
      annotationData: updatedData,
      clearSelectedStroke: true,
      hasUnsavedChanges: true,
      redoStack: [],
    );
  }

  /// Start scaling a selected stroke from a corner
  void startScaling(String corner, StrokePoint point) {
    state = state.copyWith(
      isScaling: true,
      scalingCorner: corner,
      dragStartPoint: point,
    );
  }

  /// Update scaling of the selected stroke
  void updateScaling(StrokePoint currentPoint) {
    if (!state.isScaling ||
        state.selectedStrokeId == null ||
        state.scalingCorner == null)
      return;

    final strokeIndex = state.allStrokes.indexWhere(
      (s) => s.id == state.selectedStrokeId,
    );
    if (strokeIndex == -1) return;

    final stroke = state.allStrokes[strokeIndex];

    // Calculate the center point of the annotation
    final center = _getStrokeCenter(stroke);

    // Calculate the new scale based on distance from center
    final initialDistance = _calculateDistance(state.dragStartPoint!, center);
    final currentDistance = _calculateDistance(currentPoint, center);

    if (initialDistance == 0) return;

    // Calculate scale multiplier (current distance / initial distance)
    final scaleMultiplier = currentDistance / initialDistance;
    final newScale = (stroke.scale * scaleMultiplier).clamp(0.1, 10.0);

    // Scale all points relative to the center
    final scaledPoints = stroke.points.map((p) {
      final dx = p.x - center.x;
      final dy = p.y - center.y;
      return StrokePoint(
        x: center.x + dx * (newScale / stroke.scale),
        y: center.y + dy * (newScale / stroke.scale),
        timestampMs: p.timestampMs,
      );
    }).toList();

    final updatedStroke = stroke.copyWith(
      points: scaledPoints,
      scale: newScale,
    );
    final updatedStrokes = List<Stroke>.from(state.allStrokes);
    updatedStrokes[strokeIndex] = updatedStroke;

    final updatedData = state.annotationData!.copyWith(
      strokes: updatedStrokes,
      updatedAt: DateTime.now(),
    );

    state = state.copyWith(
      annotationData: updatedData,
      dragStartPoint: currentPoint,
      hasUnsavedChanges: true,
    );
  }

  /// Finish scaling
  void finishScaling() {
    state = state.copyWith(
      isScaling: false,
      clearScalingCorner: true,
      clearDragStartPoint: true,
    );
  }

  /// Get the center point of a stroke
  StrokePoint _getStrokeCenter(Stroke stroke) {
    if (stroke.points.isEmpty) {
      return const StrokePoint(x: 0.5, y: 0.5);
    }

    if (stroke.points.length == 1) {
      return stroke.points.first;
    }

    double sumX = 0;
    double sumY = 0;
    for (final point in stroke.points) {
      sumX += point.x;
      sumY += point.y;
    }

    return StrokePoint(
      x: sumX / stroke.points.length,
      y: sumY / stroke.points.length,
    );
  }

  /// Calculate distance between two points
  double _calculateDistance(StrokePoint p1, StrokePoint p2) {
    final dx = p2.x - p1.x;
    final dy = p2.y - p1.y;
    return (dx * dx + dy * dy);
  }

  /// Confirm text for a pending text stroke
  void confirmTextStroke(String textContent) {
    if (state.pendingTextStrokeId == null) return;

    final strokeIndex = state.allStrokes.indexWhere(
      (s) => s.id == state.pendingTextStrokeId,
    );
    if (strokeIndex == -1) return;

    final updatedStroke = state.allStrokes[strokeIndex].copyWith(
      text: textContent,
    );
    final updatedStrokes = List<Stroke>.from(state.allStrokes);
    updatedStrokes[strokeIndex] = updatedStroke;

    final updatedData = state.annotationData!.copyWith(
      strokes: updatedStrokes,
      updatedAt: DateTime.now(),
    );

    state = state.copyWith(
      annotationData: updatedData,
      clearPendingTextStrokeId: true,
      hasUnsavedChanges: true,
    );
  }

  /// Cancel a pending text stroke (remove it)
  void cancelTextStroke() {
    if (state.pendingTextStrokeId == null) return;

    final updatedStrokes = state.allStrokes
        .where((s) => s.id != state.pendingTextStrokeId)
        .toList();

    final updatedData = state.annotationData!.copyWith(
      strokes: updatedStrokes,
      updatedAt: DateTime.now(),
    );

    state = state.copyWith(
      annotationData: updatedData,
      clearPendingTextStrokeId: true,
    );
  }

  /// Set a text stroke for editing (triggered by double-tap)
  void editTextStroke(String strokeId) {
    state = state.copyWith(pendingTextStrokeId: strokeId);
  }

  /// Sorted keyframe timestamps (in milliseconds) where annotations exist.
  List<int> getSortedKeyframeTimesMs() {
    return _sortedKeyframeTimesMs();
  }

  /// Keyframe targeted by new drawing operations at the given position.
  int getDrawingTargetKeyframeTimeMs([Duration? position]) {
    final targetPosition = position ?? ref.read(playerProvider).position;
    final snappedTargetMs = _snapToFrameTimeMs(
      targetPosition.inMilliseconds,
      _effectiveFps,
    );

    if (state.keyframeCreationMode == KeyframeCreationMode.automatic) {
      return snappedTargetMs;
    }

    return _activeKeyframeTimeMsAt(targetPosition.inMilliseconds) ??
        snappedTargetMs;
  }

  /// Active annotation keyframe at the given playback position.
  int? getActiveKeyframeTimeMs([Duration? position]) {
    final targetPosition = position ?? ref.read(playerProvider).position;
    return _activeKeyframeTimeMsAt(targetPosition.inMilliseconds);
  }

  /// Visible annotation strokes for the active keyframe at a playback position.
  List<Stroke> getVisibleStrokes([Duration? position]) {
    final keyframeMs = getActiveKeyframeTimeMs(position);
    if (keyframeMs == null) return const [];
    return _strokesAtKeyframe(keyframeMs);
  }
}

/// Annotation provider instance
final annotationProvider =
    StateNotifierProvider<AnnotationNotifier, AnnotationState>((ref) {
      return AnnotationNotifier(AnnotationStorageService(), ref);
    });

final annotationKeyframeModeProvider = Provider<KeyframeCreationMode>((ref) {
  return ref.watch(
    annotationProvider.select((state) => state.keyframeCreationMode),
  );
});

/// Sorted keyframes that contain at least one annotation stroke.
final annotationKeyframeTimesProvider = Provider<List<int>>((ref) {
  ref.watch(annotationProvider);
  return ref.read(annotationProvider.notifier).getSortedKeyframeTimesMs();
});

/// The active keyframe (latest keyframe at or before playback position).
final activeAnnotationKeyframeProvider = Provider<int?>((ref) {
  ref.watch(annotationProvider);
  final position = ref.watch(playerProvider.select((state) => state.position));
  return ref
      .read(annotationProvider.notifier)
      .getActiveKeyframeTimeMs(position);
});

/// The strokes visible for the current active annotation keyframe.
final visibleAnnotationStrokesProvider = Provider<List<Stroke>>((ref) {
  ref.watch(annotationProvider);
  final position = ref.watch(playerProvider.select((state) => state.position));
  return ref.read(annotationProvider.notifier).getVisibleStrokes(position);
});

/// The frame that new drawing actions will target.
final drawingTargetAnnotationKeyframeProvider = Provider<int>((ref) {
  ref.watch(annotationProvider);
  final position = ref.watch(playerProvider.select((state) => state.position));
  return ref
      .read(annotationProvider.notifier)
      .getDrawingTargetKeyframeTimeMs(position);
});

/// Whether the manual "new keyframe" action is currently available.
final canCreateManualKeyframeProvider = Provider<bool>((ref) {
  ref.watch(annotationProvider);
  return ref
      .read(annotationProvider.notifier)
      .canCreateManualKeyframeAtCurrentFrame();
});
