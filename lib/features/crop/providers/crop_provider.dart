import 'package:path/path.dart' as path;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../player/providers/player_provider.dart';
import '../../../core/models/annotation_data.dart';
import '../../../core/services/annotation_storage_service.dart';
import '../../../core/services/video_export_models.dart';
import '../../../core/services/video_export_service.dart';

final videoExportServiceProvider = Provider<VideoExportService>((ref) {
  return VideoExportService();
});

final annotationStorageServiceProvider = Provider<AnnotationStorageService>((
  ref,
) {
  return AnnotationStorageService();
});

/// Available aspect ratio presets for cropping
enum CropAspectRatio {
  /// Free-form cropping (no constraint)
  free,

  /// Original source video ratio
  original,

  /// 16:9 widescreen (landscape)
  ratio16x9,

  /// 1:1 square
  ratio1x1,

  /// 9:16 vertical (portrait)
  ratio9x16,

  /// 4:3 standard
  ratio4x3,

  /// 3:4 portrait
  ratio3x4,
}

extension CropAspectRatioExtension on CropAspectRatio {
  String get displayName {
    switch (this) {
      case CropAspectRatio.free:
        return 'Free';
      case CropAspectRatio.original:
        return 'Original';
      case CropAspectRatio.ratio16x9:
        return '16:9';
      case CropAspectRatio.ratio1x1:
        return '1:1';
      case CropAspectRatio.ratio9x16:
        return '9:16';
      case CropAspectRatio.ratio4x3:
        return '4:3';
      case CropAspectRatio.ratio3x4:
        return '3:4';
    }
  }

  /// Returns the aspect ratio value (width / height)
  /// Returns null for free-form
  double? get ratio {
    switch (this) {
      case CropAspectRatio.free:
      case CropAspectRatio.original:
        return null;
      case CropAspectRatio.ratio16x9:
        return 16 / 9;
      case CropAspectRatio.ratio1x1:
        return 1.0;
      case CropAspectRatio.ratio9x16:
        return 9 / 16;
      case CropAspectRatio.ratio4x3:
        return 4 / 3;
      case CropAspectRatio.ratio3x4:
        return 3 / 4;
    }
  }
}

/// Represents a normalized crop rectangle (0-1 coordinate space)
class CropRect {
  /// Left edge (0.0 to 1.0)
  final double left;

  /// Top edge (0.0 to 1.0)
  final double top;

  /// Right edge (0.0 to 1.0)
  final double right;

  /// Bottom edge (0.0 to 1.0)
  final double bottom;

  const CropRect({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  /// Create a default crop rect covering the entire video
  const CropRect.full() : left = 0.0, top = 0.0, right = 1.0, bottom = 1.0;

  /// Width as a normalized value (0-1)
  double get width => right - left;

  /// Height as a normalized value (0-1)
  double get height => bottom - top;

  /// Aspect ratio of the crop area
  double get aspectRatio => height > 0 ? width / height : 1.0;

  /// Center X position (0-1)
  double get centerX => (left + right) / 2;

  /// Center Y position (0-1)
  double get centerY => (top + bottom) / 2;

  /// Check if rect is valid (positive area, within bounds)
  bool get isValid =>
      left >= 0 &&
      top >= 0 &&
      right <= 1 &&
      bottom <= 1 &&
      left < right &&
      top < bottom;

  /// Create a copy with modified values
  CropRect copyWith({
    double? left,
    double? top,
    double? right,
    double? bottom,
  }) {
    return CropRect(
      left: left ?? this.left,
      top: top ?? this.top,
      right: right ?? this.right,
      bottom: bottom ?? this.bottom,
    );
  }

  /// Clamp all values to valid range (0-1)
  CropRect clamped() {
    return CropRect(
      left: left.clamp(0.0, 1.0),
      top: top.clamp(0.0, 1.0),
      right: right.clamp(0.0, 1.0),
      bottom: bottom.clamp(0.0, 1.0),
    );
  }

  /// Convert to pixel values given video dimensions
  ({int x, int y, int width, int height}) toPixels(
    int videoWidth,
    int videoHeight,
  ) {
    return (
      x: (left * videoWidth).round(),
      y: (top * videoHeight).round(),
      width: (width * videoWidth).round(),
      height: (height * videoHeight).round(),
    );
  }

  @override
  String toString() =>
      'CropRect(left: ${left.toStringAsFixed(3)}, top: ${top.toStringAsFixed(3)}, '
      'right: ${right.toStringAsFixed(3)}, bottom: ${bottom.toStringAsFixed(3)})';
}

/// Export status for tracking FFmpeg progress
enum ExportStatus { idle, preparing, exporting, success, cancelled, error }

/// State for crop functionality
class CropState {
  /// Whether crop mode is active
  final bool isCropModeActive;

  /// Current crop rectangle (normalized 0-1)
  final CropRect cropRect;

  /// Currently selected aspect ratio preset
  final CropAspectRatio aspectRatio;

  /// Which handle/edge is being dragged (null if none)
  final CropHandle? activeHandle;

  /// Export status
  final ExportStatus exportStatus;

  /// Export progress (0.0 to 1.0)
  final double exportProgress;

  /// Optional preparation status while FFmpeg tools are being resolved.
  final String? preparationMessage;

  /// Optional preparation progress (0.0 to 1.0). Null means indeterminate.
  final double? preparationProgress;

  /// Export error message (if any)
  final String? exportError;

  /// Path to exported file (on success)
  final String? exportedFilePath;

  /// Optional export segment start time. Null means start of video.
  final Duration? exportStart;

  /// Optional export segment end time. Null means end of video.
  final Duration? exportEnd;

  const CropState({
    this.isCropModeActive = false,
    this.cropRect = const CropRect.full(),
    this.aspectRatio = CropAspectRatio.free,
    this.activeHandle,
    this.exportStatus = ExportStatus.idle,
    this.exportProgress = 0.0,
    this.preparationMessage,
    this.preparationProgress,
    this.exportError,
    this.exportedFilePath,
    this.exportStart,
    this.exportEnd,
  });

  CropState copyWith({
    bool? isCropModeActive,
    CropRect? cropRect,
    CropAspectRatio? aspectRatio,
    CropHandle? activeHandle,
    bool clearActiveHandle = false,
    ExportStatus? exportStatus,
    double? exportProgress,
    String? preparationMessage,
    bool clearPreparationMessage = false,
    double? preparationProgress,
    bool clearPreparationProgress = false,
    String? exportError,
    bool clearExportError = false,
    String? exportedFilePath,
    bool clearExportedFilePath = false,
    Duration? exportStart,
    bool clearExportStart = false,
    Duration? exportEnd,
    bool clearExportEnd = false,
  }) {
    return CropState(
      isCropModeActive: isCropModeActive ?? this.isCropModeActive,
      cropRect: cropRect ?? this.cropRect,
      aspectRatio: aspectRatio ?? this.aspectRatio,
      activeHandle: clearActiveHandle
          ? null
          : (activeHandle ?? this.activeHandle),
      exportStatus: exportStatus ?? this.exportStatus,
      exportProgress: exportProgress ?? this.exportProgress,
      preparationMessage: clearPreparationMessage
          ? null
          : (preparationMessage ?? this.preparationMessage),
      preparationProgress: clearPreparationProgress
          ? null
          : (preparationProgress ?? this.preparationProgress),
      exportError: clearExportError ? null : (exportError ?? this.exportError),
      exportedFilePath: clearExportedFilePath
          ? null
          : (exportedFilePath ?? this.exportedFilePath),
      exportStart: clearExportStart ? null : (exportStart ?? this.exportStart),
      exportEnd: clearExportEnd ? null : (exportEnd ?? this.exportEnd),
    );
  }
}

/// Identifies which part of the crop rectangle is being manipulated
enum CropHandle {
  /// Moving the entire rectangle
  move,

  /// Corners
  topLeft,
  topRight,
  bottomLeft,
  bottomRight,

  /// Edges
  top,
  bottom,
  left,
  right,
}

/// Notifier for crop state management
class CropNotifier extends StateNotifier<CropState> {
  final Ref _ref;
  final VideoExportService _videoExportService;
  final AnnotationStorageService _annotationStorageService;

  CropNotifier(
    this._ref, {
    VideoExportService? videoExportService,
    AnnotationStorageService? annotationStorageService,
  }) : _videoExportService =
           videoExportService ?? _ref.read(videoExportServiceProvider),
       _annotationStorageService =
           annotationStorageService ??
           _ref.read(annotationStorageServiceProvider),
       super(const CropState());

  /// Toggle crop mode on/off
  void toggleCropMode() {
    if (state.isCropModeActive) {
      // Exiting crop mode - reset crop rect
      state = state.copyWith(
        isCropModeActive: false,
        cropRect: const CropRect.full(),
        clearActiveHandle: true,
      );
    } else {
      // Entering crop mode
      state = state.copyWith(isCropModeActive: true);
      if (state.aspectRatio != CropAspectRatio.free) {
        setAspectRatio(state.aspectRatio);
      }
    }
  }

  /// Enable crop mode
  void enterCropMode() {
    if (!state.isCropModeActive) {
      state = state.copyWith(isCropModeActive: true);
      if (state.aspectRatio != CropAspectRatio.free) {
        setAspectRatio(state.aspectRatio);
      }
    }
  }

  /// Exit crop mode and reset
  void exitCropMode() {
    state = state.copyWith(
      isCropModeActive: false,
      cropRect: const CropRect.full(),
      clearActiveHandle: true,
    );
  }

  /// Set the aspect ratio constraint
  void setAspectRatio(CropAspectRatio ratio) {
    state = state.copyWith(aspectRatio: ratio);

    if (ratio == CropAspectRatio.free) {
      return;
    }

    final metadata = _ref.read(playerProvider).metadata;
    if (metadata == null || metadata.width <= 0 || metadata.height <= 0) {
      return;
    }

    final videoRatio = metadata.width / metadata.height;
    final targetRatio = ratio == CropAspectRatio.original
        ? videoRatio
        : ratio.ratio;
    if (targetRatio == null || targetRatio <= 0) {
      return;
    }

    // Always derive new preset crops from original video dimensions.
    // This avoids chaining from a previously cropped ratio.
    _applyAspectRatioFromVideoBounds(
      targetRatio: targetRatio,
      videoRatio: videoRatio,
    );
  }

  /// Build a centered crop rect for [targetRatio], fitted inside full video.
  void _applyAspectRatioFromVideoBounds({
    required double targetRatio,
    required double videoRatio,
  }) {
    if ((targetRatio - videoRatio).abs() < 0.0001) {
      state = state.copyWith(cropRect: const CropRect.full());
      return;
    }

    if (targetRatio > videoRatio) {
      // Target is wider than video: use full width, reduce height.
      final normalizedHeight = videoRatio / targetRatio;
      final top = (1.0 - normalizedHeight) / 2.0;
      state = state.copyWith(
        cropRect: CropRect(
          left: 0.0,
          top: top.clamp(0.0, 1.0),
          right: 1.0,
          bottom: (top + normalizedHeight).clamp(0.0, 1.0),
        ),
      );
      return;
    }

    // Target is taller than video: use full height, reduce width.
    final normalizedWidth = targetRatio / videoRatio;
    final left = (1.0 - normalizedWidth) / 2.0;
    state = state.copyWith(
      cropRect: CropRect(
        left: left.clamp(0.0, 1.0),
        top: 0.0,
        right: (left + normalizedWidth).clamp(0.0, 1.0),
        bottom: 1.0,
      ),
    );
  }

  /// Start dragging a handle
  void startDrag(CropHandle handle) {
    state = state.copyWith(activeHandle: handle);
  }

  /// Update crop rect during drag
  void updateDrag(double deltaX, double deltaY, {double? videoAspectRatio}) {
    final handle = state.activeHandle;
    if (handle == null) return;

    var rect = state.cropRect;
    final targetRatio = state.aspectRatio.ratio;

    switch (handle) {
      case CropHandle.move:
        // Move the entire rect
        var newLeft = rect.left + deltaX;
        var newTop = rect.top + deltaY;
        var newRight = rect.right + deltaX;
        var newBottom = rect.bottom + deltaY;

        // Constrain to bounds
        if (newLeft < 0) {
          newRight -= newLeft;
          newLeft = 0;
        }
        if (newTop < 0) {
          newBottom -= newTop;
          newTop = 0;
        }
        if (newRight > 1) {
          newLeft -= (newRight - 1);
          newRight = 1;
        }
        if (newBottom > 1) {
          newTop -= (newBottom - 1);
          newBottom = 1;
        }

        rect = CropRect(
          left: newLeft,
          top: newTop,
          right: newRight,
          bottom: newBottom,
        );
        break;

      case CropHandle.topLeft:
        rect = _resizeFromCorner(
          rect,
          deltaX,
          deltaY,
          targetRatio,
          anchorRight: true,
          anchorBottom: true,
        );
        break;

      case CropHandle.topRight:
        rect = _resizeFromCorner(
          rect,
          deltaX,
          deltaY,
          targetRatio,
          anchorLeft: true,
          anchorBottom: true,
        );
        break;

      case CropHandle.bottomLeft:
        rect = _resizeFromCorner(
          rect,
          deltaX,
          deltaY,
          targetRatio,
          anchorRight: true,
          anchorTop: true,
        );
        break;

      case CropHandle.bottomRight:
        rect = _resizeFromCorner(
          rect,
          deltaX,
          deltaY,
          targetRatio,
          anchorLeft: true,
          anchorTop: true,
        );
        break;

      case CropHandle.top:
        var newTop = (rect.top + deltaY).clamp(0.0, rect.bottom - 0.05);
        if (targetRatio != null) {
          // Adjust width to maintain aspect ratio
          final newHeight = rect.bottom - newTop;
          final newWidth = newHeight * targetRatio;
          final centerX = rect.centerX;
          rect = CropRect(
            left: (centerX - newWidth / 2).clamp(0.0, 1.0),
            top: newTop,
            right: (centerX + newWidth / 2).clamp(0.0, 1.0),
            bottom: rect.bottom,
          );
        } else {
          rect = rect.copyWith(top: newTop);
        }
        break;

      case CropHandle.bottom:
        var newBottom = (rect.bottom + deltaY).clamp(rect.top + 0.05, 1.0);
        if (targetRatio != null) {
          final newHeight = newBottom - rect.top;
          final newWidth = newHeight * targetRatio;
          final centerX = rect.centerX;
          rect = CropRect(
            left: (centerX - newWidth / 2).clamp(0.0, 1.0),
            top: rect.top,
            right: (centerX + newWidth / 2).clamp(0.0, 1.0),
            bottom: newBottom,
          );
        } else {
          rect = rect.copyWith(bottom: newBottom);
        }
        break;

      case CropHandle.left:
        var newLeft = (rect.left + deltaX).clamp(0.0, rect.right - 0.05);
        if (targetRatio != null) {
          final newWidth = rect.right - newLeft;
          final newHeight = newWidth / targetRatio;
          final centerY = rect.centerY;
          rect = CropRect(
            left: newLeft,
            top: (centerY - newHeight / 2).clamp(0.0, 1.0),
            right: rect.right,
            bottom: (centerY + newHeight / 2).clamp(0.0, 1.0),
          );
        } else {
          rect = rect.copyWith(left: newLeft);
        }
        break;

      case CropHandle.right:
        var newRight = (rect.right + deltaX).clamp(rect.left + 0.05, 1.0);
        if (targetRatio != null) {
          final newWidth = newRight - rect.left;
          final newHeight = newWidth / targetRatio;
          final centerY = rect.centerY;
          rect = CropRect(
            left: rect.left,
            top: (centerY - newHeight / 2).clamp(0.0, 1.0),
            right: newRight,
            bottom: (centerY + newHeight / 2).clamp(0.0, 1.0),
          );
        } else {
          rect = rect.copyWith(right: newRight);
        }
        break;
    }

    state = state.copyWith(cropRect: rect.clamped());
  }

  /// Helper to resize from a corner while maintaining aspect ratio
  CropRect _resizeFromCorner(
    CropRect rect,
    double deltaX,
    double deltaY,
    double? targetRatio, {
    bool anchorLeft = false,
    bool anchorRight = false,
    bool anchorTop = false,
    bool anchorBottom = false,
  }) {
    double newLeft = rect.left;
    double newTop = rect.top;
    double newRight = rect.right;
    double newBottom = rect.bottom;

    if (!anchorLeft) {
      newLeft = (rect.left + deltaX).clamp(0.0, rect.right - 0.05);
    }
    if (!anchorRight) {
      newRight = (rect.right + deltaX).clamp(rect.left + 0.05, 1.0);
    }
    if (!anchorTop) newTop = (rect.top + deltaY).clamp(0.0, rect.bottom - 0.05);
    if (!anchorBottom) {
      newBottom = (rect.bottom + deltaY).clamp(rect.top + 0.05, 1.0);
    }

    if (targetRatio != null) {
      // Maintain aspect ratio - use the larger dimension change
      final newWidth = newRight - newLeft;
      final newHeight = newBottom - newTop;
      final currentRatio = newWidth / newHeight;

      if (currentRatio > targetRatio) {
        // Too wide - adjust width
        final adjustedWidth = newHeight * targetRatio;
        if (anchorLeft) {
          newRight = newLeft + adjustedWidth;
        } else {
          newLeft = newRight - adjustedWidth;
        }
      } else {
        // Too tall - adjust height
        final adjustedHeight = newWidth / targetRatio;
        if (anchorTop) {
          newBottom = newTop + adjustedHeight;
        } else {
          newTop = newBottom - adjustedHeight;
        }
      }
    }

    return CropRect(
      left: newLeft.clamp(0.0, 1.0),
      top: newTop.clamp(0.0, 1.0),
      right: newRight.clamp(0.0, 1.0),
      bottom: newBottom.clamp(0.0, 1.0),
    );
  }

  /// End dragging
  void endDrag() {
    state = state.copyWith(clearActiveHandle: true);
  }

  /// Reset crop rect to full video
  void resetCrop() {
    state = state.copyWith(cropRect: const CropRect.full());
  }

  /// Set export segment range. Pass null values for full-range defaults.
  void setExportRange({Duration? start, Duration? end}) {
    final playerState = _ref.read(playerProvider);
    final fullDuration = playerState.duration;

    if (fullDuration <= Duration.zero) {
      state = state.copyWith(exportStart: start, exportEnd: end);
      return;
    }

    const minSegmentMs = 100;
    final fullMs = fullDuration.inMilliseconds;

    var startMs = start?.inMilliseconds ?? 0;
    var endMs = end?.inMilliseconds ?? fullMs;

    startMs = startMs.clamp(0, fullMs);
    endMs = endMs.clamp(0, fullMs);

    if (endMs - startMs < minSegmentMs) {
      if (start != null && end == null) {
        endMs = (startMs + minSegmentMs).clamp(0, fullMs);
      } else {
        startMs = (endMs - minSegmentMs).clamp(0, fullMs);
      }
      if (endMs - startMs < minSegmentMs) {
        startMs = 0;
        endMs = fullMs;
      }
    }

    state = state.copyWith(
      exportStart: startMs == 0 ? null : Duration(milliseconds: startMs),
      exportEnd: endMs == fullMs ? null : Duration(milliseconds: endMs),
    );
  }

  /// Reset export segment to full video range.
  void resetExportRange() {
    state = state.copyWith(clearExportStart: true, clearExportEnd: true);
  }

  /// Export cropped video using FFmpeg (bundled with media_kit)
  Future<void> exportCroppedVideo(
    String outputPath, {
    AnnotationData? annotationData,
    VideoExportPreset preset = VideoExportPreset.compatible,
    String annotationSidecarExtension = 'json',
  }) async {
    final playerState = _ref.read(playerProvider);
    if (playerState.currentVideoPath == null ||
        playerState.metadata == null ||
        !playerState.isLocalFileSource) {
      state = state.copyWith(
        exportStatus: ExportStatus.error,
        clearPreparationMessage: true,
        clearPreparationProgress: true,
        exportError: 'Export requires a local video file',
      );
      return;
    }

    final inputPath = playerState.currentVideoPath!;
    final metadata = playerState.metadata!;

    state = state.copyWith(
      exportStatus: ExportStatus.preparing,
      exportProgress: 0.0,
      preparationMessage: 'Locating FFmpeg tools...',
      clearPreparationProgress: true,
      clearExportError: true,
      clearExportedFilePath: true,
    );

    final result = await _videoExportService.export(
      VideoExportRequest(
        inputPath: inputPath,
        outputPath: outputPath,
        cropRect: VideoExportCropRect(
          left: state.cropRect.left,
          top: state.cropRect.top,
          right: state.cropRect.right,
          bottom: state.cropRect.bottom,
        ),
        videoWidth: metadata.width,
        videoHeight: metadata.height,
        fullDuration: playerState.duration,
        start: state.exportStart,
        end: state.exportEnd,
        annotationData: annotationData,
        preset: preset,
      ),
      onPreparationProgress: (progress) {
        if (state.exportStatus != ExportStatus.preparing) return;
        state = state.copyWith(
          preparationMessage: progress.message,
          preparationProgress: progress.progress,
        );
      },
      onExporting: () {
        state = state.copyWith(
          exportStatus: ExportStatus.exporting,
          clearPreparationMessage: true,
          clearPreparationProgress: true,
        );
      },
      onProgress: (progress) {
        if (state.exportStatus != ExportStatus.exporting) return;
        state = state.copyWith(exportProgress: progress);
      },
    );

    switch (result.status) {
      case VideoExportResultStatus.success:
        if (annotationData != null) {
          final sidecarPath = _annotationSidecarPathFor(
            result.outputPath,
            extension: annotationSidecarExtension,
          );
          try {
            final sidecarSaved = await _annotationStorageService
                .saveAnnotationsToFile(annotationData, sidecarPath);
            if (!sidecarSaved) {
              state = state.copyWith(
                exportStatus: ExportStatus.error,
                exportProgress: 1.0,
                clearPreparationMessage: true,
                clearPreparationProgress: true,
                exportedFilePath: result.outputPath,
                exportError:
                    'Video exported successfully to ${result.outputPath}, '
                    'but the annotation sidecar could not be saved to '
                    '$sidecarPath.',
              );
              break;
            }
          } catch (error, stackTrace) {
            debugPrint(
              'Failed to save annotation sidecar for ${result.outputPath}: '
              '$error\n$stackTrace',
            );
            state = state.copyWith(
              exportStatus: ExportStatus.error,
              exportProgress: 1.0,
              clearPreparationMessage: true,
              clearPreparationProgress: true,
              exportedFilePath: result.outputPath,
              exportError:
                  'Video exported successfully to ${result.outputPath}, '
                  'but the annotation sidecar could not be saved to '
                  '$sidecarPath.',
            );
            break;
          }
        }
        state = state.copyWith(
          exportStatus: ExportStatus.success,
          exportProgress: 1.0,
          clearPreparationMessage: true,
          clearPreparationProgress: true,
          exportedFilePath: result.outputPath,
        );
        break;
      case VideoExportResultStatus.cancelled:
        state = state.copyWith(
          exportStatus: ExportStatus.cancelled,
          exportProgress: 0.0,
          clearPreparationMessage: true,
          clearPreparationProgress: true,
        );
        break;
      case VideoExportResultStatus.error:
        state = state.copyWith(
          exportStatus: ExportStatus.error,
          clearPreparationMessage: true,
          clearPreparationProgress: true,
          exportError: result.errorMessage ?? 'Failed to export video.',
        );
        break;
    }
  }

  String _annotationSidecarPathFor(
    String exportedVideoPath, {
    required String extension,
  }) {
    final normalizedExtension = extension.startsWith('.')
        ? extension
        : '.$extension';
    return path.setExtension(exportedVideoPath, normalizedExtension);
  }

  /// Cancel ongoing export
  void cancelExport() {
    _videoExportService.cancel();
  }

  /// Reset export state
  void resetExportState() {
    state = state.copyWith(
      exportStatus: ExportStatus.idle,
      exportProgress: 0.0,
      clearPreparationMessage: true,
      clearPreparationProgress: true,
      clearExportError: true,
      clearExportedFilePath: true,
    );
  }

  /// Reset all state when video changes
  void onVideoChanged() {
    cancelExport();
    state = const CropState();
  }

  @override
  void dispose() {
    cancelExport();
    super.dispose();
  }
}

/// Crop provider instance
final cropProvider = StateNotifierProvider<CropNotifier, CropState>((ref) {
  return CropNotifier(
    ref,
    videoExportService: ref.read(videoExportServiceProvider),
    annotationStorageService: ref.read(annotationStorageServiceProvider),
  );
});
