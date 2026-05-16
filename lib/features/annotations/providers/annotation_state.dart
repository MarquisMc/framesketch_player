import 'package:flutter/material.dart';

import '../../../core/models/annotation_data.dart';
import '../models/annotation_timeline_index.dart';
import '../models/frame_marker.dart';
import '../models/stroke.dart';
import '../widgets/annotation_hit_testing.dart';

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
  final ResizeHandle? scalingCorner;
  final KeyframeCreationMode keyframeCreationMode;
  final AnnotationTimelineIndex timelineIndex;

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
    this.currentFontSize = 32.0,
    this.pendingTextStrokeId,
    this.isScaling = false,
    this.scalingCorner,
    this.keyframeCreationMode = KeyframeCreationMode.automatic,
    this.timelineIndex = const AnnotationTimelineIndex(
      fps: 30.0,
      sortedKeyframeTimesMs: [],
      strokesByKeyframeTimeMs: {},
      sortedMarkers: [],
      sortedMarkerFrameTimesMs: [],
      markersByFrameTimeMs: {},
    ),
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
    bool clearCurrentStroke = false,
    bool clearSelectedStroke = false,
    bool clearDragStartPoint = false,
    bool clearSelectionBox = false,
    double? currentFontSize,
    String? pendingTextStrokeId,
    bool clearPendingTextStrokeId = false,
    bool? isScaling,
    ResizeHandle? scalingCorner,
    bool clearScalingCorner = false,
    KeyframeCreationMode? keyframeCreationMode,
  }) {
    final nextAnnotationData = annotationData ?? this.annotationData;
    return AnnotationState(
      annotationData: nextAnnotationData,
      undoStack: undoStack ?? this.undoStack,
      redoStack: redoStack ?? this.redoStack,
      currentTool: currentTool ?? this.currentTool,
      currentColor: currentColor ?? this.currentColor,
      currentStrokeWidth: currentStrokeWidth ?? this.currentStrokeWidth,
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
      currentStroke: clearCurrentStroke
          ? null
          : (currentStroke ?? this.currentStroke),
      currentFontSize: currentFontSize ?? this.currentFontSize,
      pendingTextStrokeId: clearPendingTextStrokeId
          ? null
          : (pendingTextStrokeId ?? this.pendingTextStrokeId),
      isScaling: isScaling ?? this.isScaling,
      scalingCorner: clearScalingCorner
          ? null
          : (scalingCorner ?? this.scalingCorner),
      keyframeCreationMode: keyframeCreationMode ?? this.keyframeCreationMode,
      timelineIndex: annotationData == null
          ? timelineIndex
          : AnnotationTimelineIndex.build(
              strokes: nextAnnotationData?.strokes ?? const [],
              markers: nextAnnotationData?.markers ?? const [],
              fps: nextAnnotationData?.fps ?? 30.0,
            ),
    );
  }

  List<Stroke> get allStrokes {
    return annotationData?.strokes ?? [];
  }

  List<FrameMarker> get allMarkers {
    return annotationData?.markers ?? [];
  }
}
