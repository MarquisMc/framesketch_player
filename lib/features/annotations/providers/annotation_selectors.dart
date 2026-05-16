import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../player/providers/player_provider.dart';
import '../models/frame_marker.dart';
import '../models/stroke.dart';
import 'annotation_provider.dart';

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
