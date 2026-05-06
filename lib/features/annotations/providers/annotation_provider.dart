import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/annotation_timeline_index.dart';
import '../models/frame_marker.dart';
import '../models/stroke.dart';
import '../../../core/models/annotation_data.dart';
import '../../../core/services/annotation_storage_service.dart';
import '../../../core/utils/coordinate_transformer.dart';
import '../../player/providers/player_provider.dart';
import '../widgets/annotation_hit_testing.dart';

enum KeyframeCreationMode { automatic, manual }

const double _textReferenceVideoHeight = 720.0;
const double _fallbackTextReferenceAspectRatio = 16.0 / 9.0;

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

/// Annotation notifier
class AnnotationNotifier extends StateNotifier<AnnotationState> {
  final AnnotationStorageService _storageService;
  final Ref ref;
  final _uuid = const Uuid();
  bool _isHistoryOperationInProgress = false;

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
    return AnnotationTimelineIndex.snapToFrameTimeMs(positionMs, fps);
  }

  StrokePoint _squareConstrainedPoint(StrokePoint start, StrokePoint point) {
    final dx = point.x - start.x;
    final dy = point.y - start.y;
    final side = dx.abs() < dy.abs() ? dx.abs() : dy.abs();
    final signedDx = dx < 0 ? -side : side;
    final signedDy = dy < 0 ? -side : side;
    return StrokePoint(
      x: start.x + signedDx,
      y: start.y + signedDy,
      timestampMs: point.timestampMs,
    );
  }

  Set<String> _selectedStrokeIdSet() {
    if (state.pendingTextStrokeId != null) {
      return {state.pendingTextStrokeId!};
    }

    if (state.selectedStrokeIds.isNotEmpty) {
      return state.selectedStrokeIds.toSet();
    }

    if (state.selectedStrokeId != null) {
      return {state.selectedStrokeId!};
    }

    return const <String>{};
  }

  double _minimumTextWidthNormalized(double fontSize) {
    final referenceWidth = _textReferenceWidth();
    final minimumWidthPx = (fontSize * 4.0).clamp(120.0, double.infinity);
    return minimumWidthPx / referenceWidth;
  }

  double _minimumTextHeightNormalized(double fontSize) {
    final minimumHeightPx = (fontSize * 1.8).clamp(36.0, double.infinity);
    return minimumHeightPx / _textReferenceVideoHeight;
  }

  double _textReferenceWidth() {
    final videoSize = _effectiveVideoSizeForTransform();
    final aspectRatio =
        videoSize == null || videoSize.width <= 0 || videoSize.height <= 0
        ? _fallbackTextReferenceAspectRatio
        : videoSize.width / videoSize.height;
    return _textReferenceVideoHeight * aspectRatio;
  }

  Size _measureTextBounds(
    Stroke stroke, {
    double? maxWidthNormalized,
    bool includeHintText = false,
  }) {
    final rawText = (stroke.text ?? '').trimRight();
    final measuredText = rawText.isEmpty
        ? (includeHintText ? 'Type text...' : ' ')
        : rawText;
    final referenceWidth = _textReferenceWidth();

    if (referenceWidth > 0) {
      final maxWidthPx = maxWidthNormalized == null
          ? double.infinity
          : (maxWidthNormalized * referenceWidth)
                .clamp(1.0, referenceWidth)
                .toDouble();
      final textPainter = TextPainter(
        text: TextSpan(
          text: measuredText,
          style: TextStyle(fontSize: stroke.fontSize, height: 1.2),
        ),
        textDirection: TextDirection.ltr,
        maxLines: null,
      )..layout(maxWidth: maxWidthPx);

      return Size(
        textPainter.width / referenceWidth,
        textPainter.height / _textReferenceVideoHeight,
      );
    }

    final lines = measuredText.split('\n');
    var longestLineLength = 0;
    for (final line in lines) {
      if (line.length > longestLineLength) {
        longestLineLength = line.length;
      }
    }

    final effectiveChars = longestLineLength == 0 ? 1 : longestLineLength;
    final effectiveFontSize = stroke.fontSize;
    var estimatedWidth = effectiveChars * 0.008 * (effectiveFontSize / 32.0);
    var estimatedHeight = lines.length * 0.028 * (effectiveFontSize / 32.0);

    if (maxWidthNormalized != null && estimatedWidth > maxWidthNormalized) {
      final lineCount = (estimatedWidth / maxWidthNormalized)
          .ceil()
          .clamp(1, 1000)
          .toInt();
      estimatedWidth = maxWidthNormalized;
      estimatedHeight *= lineCount;
    }

    return Size(estimatedWidth, estimatedHeight);
  }

  Stroke _withTextBounds(Stroke stroke, Rect rect) {
    if (stroke.points.isEmpty) {
      return stroke.copyWith(
        points: [
          StrokePoint(x: rect.left, y: rect.top, timestampMs: 0),
          StrokePoint(x: rect.right, y: rect.bottom, timestampMs: 0),
        ],
      );
    }
    final firstTimestamp = stroke.points.first.timestampMs;
    final secondTimestamp = stroke.points.length > 1
        ? stroke.points.last.timestampMs
        : firstTimestamp;
    return stroke.copyWith(
      points: [
        StrokePoint(x: rect.left, y: rect.top, timestampMs: firstTimestamp),
        StrokePoint(
          x: rect.right,
          y: rect.bottom,
          timestampMs: secondTimestamp,
        ),
      ],
    );
  }

  Stroke _ensureTextStrokeFitsBox(
    Stroke stroke, {
    bool allowWidthGrowth = false,
    bool enforceMinimumSize = true,
    bool includeHintText = false,
  }) {
    final bounds = _textBoundsRect(stroke);
    final minimumWidth = enforceMinimumSize
        ? _minimumTextWidthNormalized(stroke.fontSize)
        : 0.0;
    final minimumHeight = enforceMinimumSize
        ? _minimumTextHeightNormalized(stroke.fontSize)
        : 0.0;
    final hasUsableBox = bounds.width > 0.0001 && bounds.height > 0.0001;
    final currentWidth = hasUsableBox ? bounds.width : minimumWidth;
    final targetWidth = allowWidthGrowth
        ? currentWidth
        : max(currentWidth, minimumWidth);
    final measured = _measureTextBounds(
      stroke,
      maxWidthNormalized: targetWidth,
      includeHintText: includeHintText,
    );
    final requiredWidth = allowWidthGrowth
        ? max(measured.width, targetWidth)
        : targetWidth;
    final requiredHeight = measured.height > minimumHeight
        ? measured.height
        : minimumHeight;

    final left = bounds.left.clamp(0.0, 1.0).toDouble();
    final top = bounds.top.clamp(0.0, 1.0).toDouble();
    final right = (left + requiredWidth).clamp(0.0, 1.0).toDouble();
    final bottom = (top + requiredHeight).clamp(0.0, 1.0).toDouble();
    return _withTextBounds(stroke, Rect.fromLTRB(left, top, right, bottom));
  }

  Rect? _resizeRectFromHandle(
    Rect rect,
    ResizeHandle handle,
    StrokePoint currentPoint, {
    double minWidth = 0.005,
    double minHeight = 0.005,
  }) {
    var left = rect.left;
    var right = rect.right;
    var top = rect.top;
    var bottom = rect.bottom;

    final adjustLeft =
        handle == ResizeHandle.left ||
        handle == ResizeHandle.topLeft ||
        handle == ResizeHandle.bottomLeft;
    final adjustRight =
        handle == ResizeHandle.right ||
        handle == ResizeHandle.topRight ||
        handle == ResizeHandle.bottomRight;
    final adjustTop =
        handle == ResizeHandle.top ||
        handle == ResizeHandle.topLeft ||
        handle == ResizeHandle.topRight;
    final adjustBottom =
        handle == ResizeHandle.bottom ||
        handle == ResizeHandle.bottomLeft ||
        handle == ResizeHandle.bottomRight;

    if (adjustLeft) {
      left = currentPoint.x.clamp(0.0, right - minWidth).toDouble();
    }
    if (adjustRight) {
      right = currentPoint.x.clamp(left + minWidth, 1.0).toDouble();
    }
    if (adjustTop) {
      top = currentPoint.y.clamp(0.0, bottom - minHeight).toDouble();
    }
    if (adjustBottom) {
      bottom = currentPoint.y.clamp(top + minHeight, 1.0).toDouble();
    }

    if (right - left < minWidth) {
      return null;
    }
    if (bottom - top < minHeight) {
      return null;
    }

    return Rect.fromLTRB(left, top, right, bottom);
  }

  Stroke _resizeStrokeToBounds(
    Stroke stroke, {
    required Rect originalBounds,
    required Rect newBounds,
  }) {
    if (stroke.tool == DrawingTool.text) {
      return _withTextBounds(stroke, newBounds);
    }

    const epsilon = 0.000001;
    final originalWidth = originalBounds.width.abs();
    final originalHeight = originalBounds.height.abs();
    final centerX = originalBounds.center.dx;
    final centerY = originalBounds.center.dy;
    final pointCount = stroke.points.length;

    final resizedPoints = <StrokePoint>[];
    for (var i = 0; i < pointCount; i++) {
      final point = stroke.points[i];

      final relativeX = originalWidth < epsilon
          ? pointCount <= 1
                ? 0.5
                : i / (pointCount - 1)
          : (point.x - originalBounds.left) / originalWidth;
      final relativeY = originalHeight < epsilon
          ? pointCount <= 1
                ? 0.5
                : i / (pointCount - 1)
          : (point.y - originalBounds.top) / originalHeight;

      final fallbackX = point.x <= centerX ? 0.0 : 1.0;
      final fallbackY = point.y <= centerY ? 0.0 : 1.0;
      final normalizedX = (originalWidth < epsilon ? fallbackX : relativeX)
          .clamp(0.0, 1.0);
      final normalizedY = (originalHeight < epsilon ? fallbackY : relativeY)
          .clamp(0.0, 1.0);

      resizedPoints.add(
        StrokePoint(
          x: newBounds.left + (newBounds.width * normalizedX),
          y: newBounds.top + (newBounds.height * normalizedY),
          timestampMs: point.timestampMs,
        ),
      );
    }

    return stroke.copyWith(points: resizedPoints, scale: 1.0);
  }

  Rect _textBoundsRect(Stroke stroke) {
    final anchor = stroke.points.first;
    if (stroke.points.length >= 2) {
      final p2 = stroke.points.last;
      final left = anchor.x < p2.x ? anchor.x : p2.x;
      final right = anchor.x > p2.x ? anchor.x : p2.x;
      final top = anchor.y < p2.y ? anchor.y : p2.y;
      final bottom = anchor.y > p2.y ? anchor.y : p2.y;
      return Rect.fromLTRB(left, top, right, bottom);
    }

    final textBounds = _measureTextBounds(stroke);
    return Rect.fromLTRB(
      anchor.x,
      anchor.y,
      anchor.x + textBounds.width,
      anchor.y + textBounds.height,
    );
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
    return state.timelineIndex.sortedKeyframeTimesMs;
  }

  int? _activeKeyframeTimeMsAt(int positionMs) {
    return state.timelineIndex.activeKeyframeTimeMsAt(positionMs);
  }

  List<Stroke> _strokesAtKeyframe(int keyframeMs) {
    return state.timelineIndex.strokesAtKeyframe(keyframeMs);
  }

  List<FrameMarker> _sortedMarkers([List<FrameMarker>? markers]) {
    if (markers != null) {
      return AnnotationTimelineIndex.sortMarkers(markers);
    }
    return state.timelineIndex.sortedMarkers;
  }

  FrameMarker? _markerAtFrame(int positionMs) {
    return state.timelineIndex.markerAtFrame(positionMs);
  }

  Duration _toExactFramePosition(int positionMs) {
    final fps = _effectiveFps;
    if (fps <= 0) {
      return Duration(milliseconds: positionMs);
    }

    final frameIndex = ((positionMs / 1000.0) * fps).round();
    final targetMicros = ((frameIndex * 1000000.0) / fps).round();
    return Duration(microseconds: targetMicros);
  }

  bool _isStrokeVisibleAtCurrentPosition(Stroke stroke) {
    final currentPositionMs = ref.read(playerProvider).position.inMilliseconds;
    final activeKeyframeMs = _activeKeyframeTimeMsAt(currentPositionMs);
    if (activeKeyframeMs == null) return false;

    return activeKeyframeMs ==
        _snapToFrameTimeMs(stroke.startTimeMs, _effectiveFps);
  }

  void _updateMarkers(List<FrameMarker> markers) {
    final annotationData = state.annotationData;
    if (annotationData == null) return;

    state = state.copyWith(
      annotationData: annotationData.copyWith(
        markers: _sortedMarkers(markers),
        updatedAt: DateTime.now(),
      ),
      hasUnsavedChanges: true,
    );
  }

  List<FrameMarker> _normalizeImportedMarkers(
    List<FrameMarker> markers, {
    Set<String>? reservedIds,
  }) {
    final usedIds = <String>{...?reservedIds};
    final normalized = <FrameMarker>[];

    for (final marker in markers) {
      final trimmedLabel = marker.label.trim();
      if (trimmedLabel.isEmpty) {
        continue;
      }

      var nextId = marker.id.trim().isEmpty ? _uuid.v4() : marker.id.trim();
      while (usedIds.contains(nextId)) {
        nextId = _uuid.v4();
      }
      usedIds.add(nextId);

      normalized.add(
        marker.copyWith(
          id: nextId,
          label: trimmedLabel,
          note: marker.note.trim(),
          timeMs: _snapToFrameTimeMs(
            marker.timeMs,
            _effectiveFps,
          ).clamp(0, 1 << 30).toInt(),
        ),
      );
    }

    return normalized;
  }

  FrameMarker? _adjacentMarker({required bool forward, Duration? position}) {
    final targetPosition = position ?? ref.read(playerProvider).position;
    return state.timelineIndex.adjacentMarker(
      forward: forward,
      positionMs: targetPosition.inMilliseconds,
    );
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
        clearCurrentStroke: true,
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

      state = state.copyWith(
        annotationData: newData,
        clearCurrentStroke: true,
        hasUnsavedChanges: false,
      );
    }
  }

  /// Initialize annotations for a YouTube video using a stable synthetic key.
  Future<void> initializeForYouTubeVideo({
    required String youtubeVideoId,
    required String youtubeUrl,
    required double fps,
  }) async {
    final sourceKey = _storageService.buildYouTubeAnnotationKey(youtubeVideoId);
    final existingData = await _storageService.loadAnnotations(sourceKey);

    if (existingData != null) {
      final normalizedData = existingData.youtubeUrl == youtubeUrl
          ? existingData
          : existingData.copyWith(youtubeUrl: youtubeUrl);
      state = state.copyWith(
        annotationData: normalizedData,
        clearCurrentStroke: true,
        hasUnsavedChanges: normalizedData != existingData,
      );
      return;
    }

    final videoId = _storageService.generateVideoId(sourceKey);
    final newData = AnnotationData(
      videoId: videoId,
      videoPath: sourceKey,
      youtubeUrl: youtubeUrl,
      fps: fps,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      viewportWidth: 0,
      viewportHeight: 0,
    );

    state = state.copyWith(
      annotationData: newData,
      clearCurrentStroke: true,
      hasUnsavedChanges: false,
    );
  }

  /// Initialize annotation state from an imported/shared annotation JSON.
  void initializeFromAnnotationData(AnnotationData data) {
    state = state.copyWith(
      annotationData: data,
      undoStack: const [],
      redoStack: const [],
      clearCurrentStroke: true,
      clearSelectedStroke: true,
      clearSelectionBox: true,
      clearDragStartPoint: true,
      clearPendingTextStrokeId: true,
      hasUnsavedChanges: false,
    );
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
    state = state.copyWith(currentTool: tool, clearCurrentStroke: true);
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

  /// Move all strokes assigned to a keyframe to a new timeline position.
  void moveKeyframe({required int fromKeyframeMs, required int toKeyframeMs}) {
    if (state.annotationData == null) return;

    final fps = _effectiveFps;
    final fromSnappedMs = _snapToFrameTimeMs(fromKeyframeMs, fps);
    final toSnappedMs = _snapToFrameTimeMs(toKeyframeMs, fps);
    if (fromSnappedMs == toSnappedMs) return;

    final deltaMs = toSnappedMs - fromSnappedMs;
    var changed = false;
    final updatedStrokes = state.allStrokes.map((stroke) {
      final strokeKeyframeMs = _snapToFrameTimeMs(stroke.startTimeMs, fps);
      if (strokeKeyframeMs != fromSnappedMs) {
        return stroke;
      }

      changed = true;
      final nextStartMs = (stroke.startTimeMs + deltaMs)
          .clamp(0, 1 << 30)
          .toInt();
      var nextEndMs = (stroke.endTimeMs + deltaMs).clamp(0, 1 << 30).toInt();
      if (nextEndMs < nextStartMs) {
        nextEndMs = nextStartMs;
      }

      return stroke.copyWith(startTimeMs: nextStartMs, endTimeMs: nextEndMs);
    }).toList();

    if (!changed) return;

    final updatedData = state.annotationData!.copyWith(
      strokes: updatedStrokes,
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

  void upsertMarker({
    String? markerId,
    required String label,
    required Color color,
    String note = '',
    int? timeMs,
  }) {
    if (state.annotationData == null) return;

    final trimmedLabel = label.trim();
    if (trimmedLabel.isEmpty) return;

    final markerTimeMs = _snapToFrameTimeMs(
      timeMs ?? ref.read(playerProvider).position.inMilliseconds,
      _effectiveFps,
    ).clamp(0, 1 << 30).toInt();

    final existingIndex = markerId == null
        ? -1
        : state.allMarkers.indexWhere((marker) => marker.id == markerId);

    final marker = FrameMarker(
      id: existingIndex >= 0 ? state.allMarkers[existingIndex].id : _uuid.v4(),
      timeMs: markerTimeMs,
      label: trimmedLabel,
      note: note.trim(),
      color: color,
    );

    final updatedMarkers = [...state.allMarkers];
    if (existingIndex >= 0) {
      updatedMarkers[existingIndex] = marker;
    } else {
      updatedMarkers.add(marker);
    }

    _updateMarkers(updatedMarkers);
  }

  void deleteMarker(String markerId) {
    if (state.annotationData == null) return;

    final updatedMarkers = state.allMarkers
        .where((marker) => marker.id != markerId)
        .toList();

    if (updatedMarkers.length == state.allMarkers.length) {
      return;
    }

    _updateMarkers(updatedMarkers);
  }

  void replaceMarkers(List<FrameMarker> importedMarkers) {
    if (state.annotationData == null) return;
    _updateMarkers(_normalizeImportedMarkers(importedMarkers));
  }

  void mergeMarkers(List<FrameMarker> importedMarkers) {
    if (state.annotationData == null) return;

    final normalized = _normalizeImportedMarkers(
      importedMarkers,
      reservedIds: state.allMarkers.map((marker) => marker.id).toSet(),
    );
    _updateMarkers([...state.allMarkers, ...normalized]);
  }

  Future<FrameMarker?> seekToNextMarker() async {
    final marker = _adjacentMarker(forward: true);
    if (marker == null) return null;

    await seekToMarker(marker);
    return marker;
  }

  Future<FrameMarker?> seekToPreviousMarker() async {
    final marker = _adjacentMarker(forward: false);
    if (marker == null) return null;

    await seekToMarker(marker);
    return marker;
  }

  Future<void> seekToMarker(FrameMarker marker) async {
    await ref
        .read(playerProvider.notifier)
        .seek(_toExactFramePosition(marker.timeMs));
  }

  /// Set current color
  void setColor(Color color) {
    state = state.copyWith(currentColor: color);
  }

  /// Set stroke width
  void setStrokeWidth(double width) {
    final normalizedWidth = width.clamp(1.0, 10.0).toDouble();
    final selectedIds = _selectedStrokeIdSet();
    var didUpdateSelectedStroke = false;

    if (state.annotationData != null && selectedIds.isNotEmpty) {
      final updatedStrokes = state.allStrokes.map((stroke) {
        if (!selectedIds.contains(stroke.id) ||
            stroke.tool == DrawingTool.text) {
          return stroke;
        }

        if ((stroke.strokeWidth - normalizedWidth).abs() < 0.001) {
          return stroke;
        }

        didUpdateSelectedStroke = true;
        return stroke.copyWith(strokeWidth: normalizedWidth);
      }).toList();

      if (didUpdateSelectedStroke) {
        final updatedData = state.annotationData!.copyWith(
          strokes: updatedStrokes,
          updatedAt: DateTime.now(),
        );
        state = state.copyWith(
          annotationData: updatedData,
          currentStrokeWidth: normalizedWidth,
          hasUnsavedChanges: true,
        );
        return;
      }
    }

    state = state.copyWith(currentStrokeWidth: normalizedWidth);
  }

  /// Set font size for text tool
  void setFontSize(double size) {
    final normalizedSize = size.clamp(12.0, 100.0).toDouble();
    final selectedIds = _selectedStrokeIdSet();
    var didUpdateSelectedStroke = false;

    if (state.annotationData != null && selectedIds.isNotEmpty) {
      final updatedStrokes = state.allStrokes.map((stroke) {
        if (!selectedIds.contains(stroke.id) ||
            stroke.tool != DrawingTool.text) {
          return stroke;
        }

        if ((stroke.fontSize - normalizedSize).abs() < 0.001) {
          return stroke;
        }

        didUpdateSelectedStroke = true;
        return _ensureTextStrokeFitsBox(
          stroke.copyWith(fontSize: normalizedSize),
          allowWidthGrowth: false,
          enforceMinimumSize: true,
          includeHintText: true,
        );
      }).toList();

      if (didUpdateSelectedStroke) {
        final updatedData = state.annotationData!.copyWith(
          strokes: updatedStrokes,
          updatedAt: DateTime.now(),
        );
        state = state.copyWith(
          annotationData: updatedData,
          currentFontSize: normalizedSize,
          hasUnsavedChanges: true,
        );
        return;
      }
    }

    state = state.copyWith(currentFontSize: normalizedSize);
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

    // If text tool, create stroke at click position and enter inline edit mode
    if (state.currentTool == DrawingTool.text) {
      final initialWidth = _minimumTextWidthNormalized(state.currentFontSize);
      final initialHeight = _minimumTextHeightNormalized(state.currentFontSize);
      final left = point.x
          .clamp(0.0, (1.0 - initialWidth).clamp(0.0, 1.0))
          .toDouble();
      final top = point.y
          .clamp(0.0, (1.0 - initialHeight).clamp(0.0, 1.0))
          .toDouble();
      final newStroke = Stroke(
        id: _uuid.v4(),
        tool: DrawingTool.text,
        color: state.currentColor,
        strokeWidth: state.currentStrokeWidth,
        points: [
          StrokePoint(x: left, y: top, timestampMs: point.timestampMs),
          StrokePoint(
            x: (left + initialWidth).clamp(0.0, 1.0).toDouble(),
            y: (top + initialHeight).clamp(0.0, 1.0).toDouble(),
            timestampMs: point.timestampMs,
          ),
        ],
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
        state.currentTool == DrawingTool.filledSquare ||
        state.currentTool == DrawingTool.circle ||
        state.currentTool == DrawingTool.filledCircle ||
        state.currentTool == DrawingTool.line ||
        state.currentTool == DrawingTool.arrow;

    final List<StrokePoint> updatedPoints;
    if (isShapeTool) {
      // Replace the last point for shapes (start point stays, end point updates)
      final start = state.currentStroke!.points.first;
      final constrainedPoint = state.currentTool == DrawingTool.filledSquare
          ? _squareConstrainedPoint(start, point)
          : point;
      updatedPoints = [start, constrainedPoint];
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

    final finalizedStroke = state.currentStroke!;
    final updatedStrokes = [...state.allStrokes, finalizedStroke];
    final updatedData = state.annotationData!.copyWith(
      strokes: updatedStrokes,
      updatedAt: DateTime.now(),
    );

    state = state.copyWith(
      annotationData: updatedData,
      clearCurrentStroke: true,
      isDrawing: false,
      hasUnsavedChanges: true,
      redoStack: [], // Clear redo stack when new action is performed
    );
  }

  /// Cancel current stroke
  void cancelStroke() {
    state = state.copyWith(
      clearCurrentStroke: true,
      isDrawing: false,
      isBoxSelecting: false,
      clearSelectionBox: true,
    );
  }

  /// Undo last stroke
  Future<void> undo() async {
    if (_isHistoryOperationInProgress || state.allStrokes.isEmpty) return;

    _isHistoryOperationInProgress = true;
    try {
      final strokes = List<Stroke>.from(state.allStrokes);
      final lastStroke = strokes.removeLast();
      if (!_isStrokeVisibleAtCurrentPosition(lastStroke)) {
        await ref
            .read(playerProvider.notifier)
            .seek(_toExactFramePosition(lastStroke.startTimeMs));
        await Future<void>.delayed(const Duration(milliseconds: 120));
      }

      final updatedData = state.annotationData!.copyWith(
        strokes: strokes,
        updatedAt: DateTime.now(),
      );

      state = state.copyWith(
        annotationData: updatedData,
        undoStack: [...state.undoStack, lastStroke],
        hasUnsavedChanges: true,
      );
    } finally {
      _isHistoryOperationInProgress = false;
    }
  }

  /// Redo last undone stroke
  Future<void> redo() async {
    if (_isHistoryOperationInProgress || state.undoStack.isEmpty) return;

    _isHistoryOperationInProgress = true;
    try {
      final undoStack = List<Stroke>.from(state.undoStack);
      final strokeToRedo = undoStack.removeLast();
      if (!_isStrokeVisibleAtCurrentPosition(strokeToRedo)) {
        await ref
            .read(playerProvider.notifier)
            .seek(_toExactFramePosition(strokeToRedo.startTimeMs));
        await Future<void>.delayed(const Duration(milliseconds: 120));
      }

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
    } finally {
      _isHistoryOperationInProgress = false;
    }
  }

  /// Clear all annotations
  void clearAll() {
    final updatedData = state.annotationData!.copyWith(
      strokes: [],
      updatedAt: DateTime.now(),
    );

    state = state.copyWith(
      annotationData: updatedData,
      clearCurrentStroke: true,
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

  /// Save annotations to a user-selected JSON path.
  Future<bool> saveAnnotationsToFile(String outputPath) async {
    if (state.annotationData == null) return false;

    final success = await _storageService.saveAnnotationsToFile(
      state.annotationData!,
      outputPath,
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
      scale: original.scale,
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
      if (stroke.tool == DrawingTool.rectangle ||
          stroke.tool == DrawingTool.filledSquare) {
        if (_isPointNearRectangle(stroke, point, selectionRadius)) {
          return stroke;
        }
      } else if (stroke.tool == DrawingTool.circle ||
          stroke.tool == DrawingTool.filledCircle) {
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
    if (stroke.points.isEmpty || stroke.text == null || stroke.text!.isEmpty) {
      return false;
    }

    final bounds = _textBoundsRect(stroke);

    return point.x >= bounds.left - threshold &&
        point.x <= bounds.right + threshold &&
        point.y >= bounds.top - threshold &&
        point.y <= bounds.bottom + threshold;
  }

  /// Move the selected stroke by the drag offset
  void _moveSelectedStrokes(StrokePoint currentPoint) {
    if (state.selectedStrokeIds.isEmpty || state.dragStartPoint == null) return;

    final selectedSet = state.selectedStrokeIds.toSet();
    final requestedDx = currentPoint.x - state.dragStartPoint!.x;
    final requestedDy = currentPoint.y - state.dragStartPoint!.y;
    final clampedDelta = _clampedDragDeltaForSelectedStrokes(
      selectedSet,
      requestedDx,
      requestedDy,
    );
    final dx = clampedDelta.dx;
    final dy = clampedDelta.dy;
    if (dx == 0 && dy == 0) {
      return;
    }

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
      dragStartPoint: StrokePoint(
        x: state.dragStartPoint!.x + dx,
        y: state.dragStartPoint!.y + dy,
        timestampMs: currentPoint.timestampMs,
      ),
      hasUnsavedChanges: true,
    );
  }

  Offset _clampedDragDeltaForSelectedStrokes(
    Set<String> selectedSet,
    double requestedDx,
    double requestedDy,
  ) {
    final selectedBounds = _selectedStrokeBounds(selectedSet);
    if (selectedBounds == null) {
      return Offset(requestedDx, requestedDy);
    }

    final minDx = -selectedBounds.left;
    final maxDx = 1.0 - selectedBounds.right;
    final minDy = -selectedBounds.top;
    final maxDy = 1.0 - selectedBounds.bottom;

    return Offset(
      _clampDragAxis(requestedDx, minDx, maxDx),
      _clampDragAxis(requestedDy, minDy, maxDy),
    );
  }

  double _clampDragAxis(
    double requestedDelta,
    double minDelta,
    double maxDelta,
  ) {
    if (minDelta > maxDelta) {
      return 0.0;
    }
    return requestedDelta.clamp(minDelta, maxDelta).toDouble();
  }

  Rect? _selectedStrokeBounds(Set<String> selectedSet) {
    Rect? selectedBounds;
    for (final stroke in state.allStrokes) {
      if (!selectedSet.contains(stroke.id)) continue;

      final bounds = _strokeBounds(stroke);
      if (bounds == null) continue;

      selectedBounds = selectedBounds == null
          ? bounds
          : selectedBounds.expandToInclude(bounds);
    }

    return selectedBounds;
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
      return _textBoundsRect(stroke);
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
    if (state.selectedStrokeIds.isEmpty && state.selectedStrokeId == null) {
      return;
    }
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

  /// Start resizing a selected stroke from a handle.
  void startScaling(ResizeHandle corner, StrokePoint point) {
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
        state.scalingCorner == null) {
      return;
    }

    final strokeIndex = state.allStrokes.indexWhere(
      (s) => s.id == state.selectedStrokeId,
    );
    if (strokeIndex == -1) return;

    final stroke = state.allStrokes[strokeIndex];

    final originalBounds = _strokeBounds(stroke);
    if (originalBounds == null) {
      return;
    }

    final resizedBounds = _resizeRectFromHandle(
      originalBounds,
      state.scalingCorner!,
      currentPoint,
    );
    if (resizedBounds == null) return;

    final updatedStroke = _resizeStrokeToBounds(
      stroke,
      originalBounds: originalBounds,
      newBounds: resizedBounds,
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

  /// Update text content for the currently edited text stroke.
  void updatePendingTextStrokeText(String textContent) {
    if (state.pendingTextStrokeId == null) return;

    final strokeIndex = state.allStrokes.indexWhere(
      (s) => s.id == state.pendingTextStrokeId,
    );
    if (strokeIndex == -1) {
      state = state.copyWith(clearPendingTextStrokeId: true);
      return;
    }

    final existing = state.allStrokes[strokeIndex];
    if ((existing.text ?? '') == textContent) return;

    final updatedStroke = existing.copyWith(text: textContent);
    final updatedStrokes = List<Stroke>.from(state.allStrokes);
    updatedStrokes[strokeIndex] = updatedStroke;

    final updatedData = state.annotationData!.copyWith(
      strokes: updatedStrokes,
      updatedAt: DateTime.now(),
    );

    state = state.copyWith(
      annotationData: updatedData,
      hasUnsavedChanges: true,
    );
  }

  /// Update the edited text stroke bounding box in normalized coordinates.
  void updatePendingTextStrokeBounds({
    required double left,
    required double top,
    required double right,
    required double bottom,
  }) {
    if (state.pendingTextStrokeId == null) return;

    final strokeIndex = state.allStrokes.indexWhere(
      (s) => s.id == state.pendingTextStrokeId,
    );
    if (strokeIndex == -1) {
      state = state.copyWith(clearPendingTextStrokeId: true);
      return;
    }

    final existing = state.allStrokes[strokeIndex];
    if (existing.points.isEmpty) return;

    final normalizedLeft = left < right ? left : right;
    final normalizedRight = left > right ? left : right;
    final normalizedTop = top < bottom ? top : bottom;
    final normalizedBottom = top > bottom ? top : bottom;

    final oldBounds = _textBoundsRect(existing);
    const epsilon = 0.0001;
    if ((oldBounds.left - normalizedLeft).abs() < epsilon &&
        (oldBounds.top - normalizedTop).abs() < epsilon &&
        (oldBounds.right - normalizedRight).abs() < epsilon &&
        (oldBounds.bottom - normalizedBottom).abs() < epsilon) {
      return;
    }

    final firstTimestamp = existing.points.first.timestampMs;
    final secondTimestamp = existing.points.length > 1
        ? existing.points.last.timestampMs
        : firstTimestamp;
    final updatedStroke = existing.copyWith(
      points: [
        StrokePoint(
          x: normalizedLeft,
          y: normalizedTop,
          timestampMs: firstTimestamp,
        ),
        StrokePoint(
          x: normalizedRight,
          y: normalizedBottom,
          timestampMs: secondTimestamp,
        ),
      ],
    );

    final updatedStrokes = List<Stroke>.from(state.allStrokes);
    updatedStrokes[strokeIndex] = updatedStroke;

    final updatedData = state.annotationData!.copyWith(
      strokes: updatedStrokes,
      updatedAt: DateTime.now(),
    );

    state = state.copyWith(
      annotationData: updatedData,
      hasUnsavedChanges: true,
    );
  }

  /// Finalize inline text editing. Empty text removes the stroke.
  void finalizePendingTextStroke() {
    if (state.pendingTextStrokeId == null) return;

    final strokeIndex = state.allStrokes.indexWhere(
      (s) => s.id == state.pendingTextStrokeId,
    );
    if (strokeIndex == -1) {
      state = state.copyWith(clearPendingTextStrokeId: true);
      return;
    }

    final existing = state.allStrokes[strokeIndex];
    final normalizedText = (existing.text ?? '').trim();

    if (normalizedText.isEmpty) {
      final updatedStrokes = state.allStrokes
          .where((s) => s.id != existing.id)
          .toList();
      final clearSelected =
          state.selectedStrokeId == existing.id ||
          state.selectedStrokeIds.contains(existing.id);
      final updatedData = state.annotationData!.copyWith(
        strokes: updatedStrokes,
        updatedAt: DateTime.now(),
      );

      state = state.copyWith(
        annotationData: updatedData,
        clearPendingTextStrokeId: true,
        clearSelectedStroke: clearSelected,
        hasUnsavedChanges: true,
      );
      return;
    }

    final updatedStroke = _ensureTextStrokeFitsBox(
      existing.copyWith(text: normalizedText),
      allowWidthGrowth: false,
      enforceMinimumSize: true,
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

  /// Backwards-compatible confirmation API.
  void confirmTextStroke(String textContent) {
    updatePendingTextStrokeText(textContent);
    finalizePendingTextStroke();
  }

  /// Cancel a pending text stroke (remove it)
  void cancelTextStroke() {
    finalizePendingTextStroke();
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

  /// Sorted frame markers for the current source.
  List<FrameMarker> getSortedMarkers() {
    return _sortedMarkers();
  }

  /// Marker that lands exactly on the current frame, if any.
  FrameMarker? getCurrentFrameMarker([Duration? position]) {
    final targetPosition = position ?? ref.read(playerProvider).position;
    return _markerAtFrame(targetPosition.inMilliseconds);
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

List<Stroke> _resolveSelectedAnnotationStrokes(AnnotationState state) {
  final targetIds = state.pendingTextStrokeId != null
      ? {state.pendingTextStrokeId!}
      : state.selectedStrokeIds.isNotEmpty
      ? state.selectedStrokeIds.toSet()
      : <String>{if (state.selectedStrokeId != null) state.selectedStrokeId!};

  if (targetIds.isEmpty) return const [];

  return state.allStrokes
      .where((stroke) => targetIds.contains(stroke.id))
      .toList();
}

final annotationKeyframeModeProvider = Provider<KeyframeCreationMode>((ref) {
  return ref.watch(
    annotationProvider.select((state) => state.keyframeCreationMode),
  );
});

final selectedAnnotationStrokesProvider = Provider<List<Stroke>>((ref) {
  final state = ref.watch(annotationProvider);
  return _resolveSelectedAnnotationStrokes(state);
});

final selectedAnnotationStrokeProvider = Provider<Stroke?>((ref) {
  final selectedStrokes = ref.watch(selectedAnnotationStrokesProvider);
  return selectedStrokes.isEmpty ? null : selectedStrokes.first;
});

final activeAnnotationSizingToolProvider = Provider<DrawingTool>((ref) {
  final selectedStrokes = ref.watch(selectedAnnotationStrokesProvider);
  final currentTool = ref.watch(
    annotationProvider.select((state) => state.currentTool),
  );
  if (selectedStrokes.isEmpty) {
    return currentTool;
  }

  final firstNonTextStroke = selectedStrokes
      .where((stroke) => stroke.tool != DrawingTool.text)
      .firstOrNull;
  if (firstNonTextStroke != null) {
    return firstNonTextStroke.tool;
  }

  return DrawingTool.text;
});

final activeAnnotationStrokeWidthProvider = Provider<double>((ref) {
  final selectedStrokes = ref.watch(selectedAnnotationStrokesProvider);
  final currentStrokeWidth = ref.watch(
    annotationProvider.select((state) => state.currentStrokeWidth),
  );
  final firstNonTextStroke = selectedStrokes
      .where((stroke) => stroke.tool != DrawingTool.text)
      .firstOrNull;
  if (firstNonTextStroke == null) {
    return currentStrokeWidth;
  }
  return firstNonTextStroke.strokeWidth;
});

final activeAnnotationFontSizeProvider = Provider<double>((ref) {
  final selectedStrokes = ref.watch(selectedAnnotationStrokesProvider);
  final currentFontSize = ref.watch(
    annotationProvider.select((state) => state.currentFontSize),
  );
  final firstTextStroke = selectedStrokes
      .where((stroke) => stroke.tool == DrawingTool.text)
      .firstOrNull;
  final hasOnlyTextSelection =
      firstTextStroke != null &&
      selectedStrokes.every((stroke) => stroke.tool == DrawingTool.text);
  if (!hasOnlyTextSelection) {
    return currentFontSize;
  }
  return firstTextStroke.fontSize;
});

/// Sorted keyframes that contain at least one annotation stroke.
final annotationKeyframeTimesProvider = Provider<List<int>>((ref) {
  ref.watch(annotationProvider);
  return ref.read(annotationProvider.notifier).getSortedKeyframeTimesMs();
});

/// Sorted frame markers for the current source.
final annotationMarkersProvider = Provider<List<FrameMarker>>((ref) {
  ref.watch(annotationProvider);
  return ref.read(annotationProvider.notifier).getSortedMarkers();
});

/// The active keyframe (latest keyframe at or before playback position).
final activeAnnotationKeyframeProvider = Provider<int?>((ref) {
  ref.watch(annotationProvider);
  final position = ref.watch(playerProvider.select((state) => state.position));
  return ref
      .read(annotationProvider.notifier)
      .getActiveKeyframeTimeMs(position);
});

/// The marker that matches the current frame, if any.
final currentAnnotationMarkerProvider = Provider<FrameMarker?>((ref) {
  ref.watch(annotationProvider);
  final position = ref.watch(playerProvider.select((state) => state.position));
  return ref.read(annotationProvider.notifier).getCurrentFrameMarker(position);
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
