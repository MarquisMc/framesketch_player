import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;
import '../../player/providers/player_provider.dart';
import '../../annotations/models/stroke.dart';
import '../../../core/services/annotation_overlay_renderer_service.dart';
import '../../../core/services/annotation_storage_service.dart';
import '../../../core/services/ffmpeg_binaries_service.dart';
import '../../../core/models/annotation_data.dart';

/// Available aspect ratio presets for cropping
enum CropAspectRatio {
  /// Free-form cropping (no constraint)
  free,

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
  double get aspectRatio => width / height;

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
  Process? _ffmpegProcess;
  bool _cancelRequested = false;
  Timer? _progressTimer;
  final AnnotationOverlayRendererService _overlayRenderer =
      AnnotationOverlayRendererService();
  final FFmpegBinariesService _ffmpegBinaries = FFmpegBinariesService();

  CropNotifier(this._ref) : super(const CropState());

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
    }
  }

  /// Enable crop mode
  void enterCropMode() {
    if (!state.isCropModeActive) {
      state = state.copyWith(isCropModeActive: true);
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

    // If we have a current crop rect, adjust it to match the new ratio
    if (ratio != CropAspectRatio.free) {
      _adjustCropRectToAspectRatio(ratio.ratio!);
    }
  }

  /// Adjust the current crop rect to match a specific aspect ratio
  void _adjustCropRectToAspectRatio(double targetRatio) {
    final currentRect = state.cropRect;
    final currentRatio = currentRect.aspectRatio;

    if ((currentRatio - targetRatio).abs() < 0.01) {
      return; // Already matches
    }

    // Keep center, adjust dimensions
    final centerX = currentRect.centerX;
    final centerY = currentRect.centerY;

    double newWidth, newHeight;

    if (currentRatio > targetRatio) {
      // Current is wider - reduce width
      newHeight = currentRect.height;
      newWidth = newHeight * targetRatio;
    } else {
      // Current is taller - reduce height
      newWidth = currentRect.width;
      newHeight = newWidth / targetRatio;
    }

    // Calculate new bounds
    var newLeft = centerX - newWidth / 2;
    var newTop = centerY - newHeight / 2;
    var newRight = centerX + newWidth / 2;
    var newBottom = centerY + newHeight / 2;

    // Clamp to valid range and shift if needed
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

    state = state.copyWith(
      cropRect: CropRect(
        left: newLeft.clamp(0.0, 1.0),
        top: newTop.clamp(0.0, 1.0),
        right: newRight.clamp(0.0, 1.0),
        bottom: newBottom.clamp(0.0, 1.0),
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

  /// Find FFmpeg executable managed by the app.
  Future<String?> _findFFmpegPath({
    FFmpegProvisioningProgressCallback? onProgress,
  }) async {
    return _ffmpegBinaries.findFFmpegPath(onProgress: onProgress);
  }

  /// Export cropped video using FFmpeg (bundled with media_kit)
  Future<void> exportCroppedVideo(
    String outputPath, {
    AnnotationData? annotationData,
  }) async {
    final playerState = _ref.read(playerProvider);
    if (playerState.currentVideoPath == null || playerState.metadata == null) {
      state = state.copyWith(
        exportStatus: ExportStatus.error,
        clearPreparationMessage: true,
        clearPreparationProgress: true,
        exportError: 'No video loaded',
      );
      return;
    }

    final inputPath = playerState.currentVideoPath!;
    final normalizedOutputPath = _normalizeOutputPath(outputPath);
    final fullDuration = playerState.duration;
    final fullMs = fullDuration.inMilliseconds;

    var startMs = state.exportStart?.inMilliseconds ?? 0;
    var endMs = state.exportEnd?.inMilliseconds ?? fullMs;

    startMs = startMs.clamp(0, fullMs);
    endMs = endMs.clamp(0, fullMs);

    final targetDurationMs = endMs - startMs;
    final isSegmentedExport = startMs > 0 || endMs < fullMs;

    if (targetDurationMs <= 0) {
      state = state.copyWith(
        exportStatus: ExportStatus.error,
        clearPreparationMessage: true,
        clearPreparationProgress: true,
        exportError: 'Invalid export range selected',
      );
      return;
    }

    final normalizedCropFilter = _buildNormalizedCropFilter(state.cropRect);
    final isFullFrameCrop = _isFullFrameCrop(state.cropRect);
    final metadata = playerState.metadata!;
    final effectiveAnnotationData =
        annotationData ??
        await AnnotationStorageService().loadAnnotations(inputPath);
    final hasActiveAnnotations = _hasAnnotationsInRange(
      annotationData: effectiveAnnotationData,
      startMs: startMs,
      endMs: endMs,
    );
    final useStreamCopy = isFullFrameCrop && !hasActiveAnnotations;

    state = state.copyWith(
      exportStatus: ExportStatus.preparing,
      exportProgress: 0.0,
      preparationMessage: 'Locating FFmpeg tools...',
      clearPreparationProgress: true,
      clearExportError: true,
      clearExportedFilePath: true,
    );

    _cancelRequested = false;
    Directory? overlayTempDir;

    try {
      // Find FFmpeg executable
      final ffmpegPath = await _findFFmpegPath(
        onProgress: (progress) {
          if (state.exportStatus != ExportStatus.preparing) return;
          state = state.copyWith(
            preparationMessage: progress.message,
            preparationProgress: progress.progress,
          );
        },
      );
      if (ffmpegPath == null) {
        state = state.copyWith(
          exportStatus: ExportStatus.error,
          clearPreparationMessage: true,
          clearPreparationProgress: true,
          exportError:
              'FFmpeg not found. Automatic provisioning failed. Check internet access and try again.',
        );
        return;
      }

      final overlays = <_TimedOverlay>[];
      if (!useStreamCopy) {
        overlayTempDir = await Directory.systemTemp.createTemp(
          'framesketch_annotation_overlays_',
        );
        overlays.addAll(
          await _prepareAnnotationOverlays(
            annotationData: effectiveAnnotationData,
            videoWidth: metadata.width,
            videoHeight: metadata.height,
            startMs: startMs,
            endMs: endMs,
            tempDir: overlayTempDir,
          ),
        );
      }

      // Smart export strategy:
      // 1) Stream copy when no visual transform is needed for same quality + speed.
      // 2) Re-encode only when crop/overlay processing is required.
      final args = useStreamCopy
          ? <String>[
              '-hide_banner',
              if (startMs > 0) ...[
                '-ss',
                (startMs / 1000.0).toStringAsFixed(3),
              ],
              '-i',
              inputPath,
              if (isSegmentedExport) ...[
                '-t',
                (targetDurationMs / 1000.0).toStringAsFixed(3),
              ],
              '-map',
              '0:v:0',
              '-map',
              '0:a:0?',
              '-c',
              'copy',
              '-movflags',
              '+faststart',
              '-avoid_negative_ts',
              'make_zero',
              '-y',
              normalizedOutputPath,
            ]
          : <String>[
              '-hide_banner',
              '-fflags',
              '+genpts',
              if (startMs > 0) ...[
                '-ss',
                (startMs / 1000.0).toStringAsFixed(3),
              ],
              '-i',
              inputPath,
              for (final overlay in overlays) ...[
                '-loop',
                '1',
                '-i',
                overlay.path,
              ],
              // Annotation overlays are provided as looped still-image inputs.
              // For full-range exports, adding an explicit duration prevents FFmpeg
              // from waiting forever on those looped inputs.
              if (isSegmentedExport || overlays.isNotEmpty) ...[
                '-t',
                (targetDurationMs / 1000.0).toStringAsFixed(3),
              ],
              if (overlays.isNotEmpty) ...[
                '-filter_complex',
                _buildFilterComplex(
                  overlays: overlays,
                  cropFilter: normalizedCropFilter,
                ),
                '-map',
                '[vout]',
              ] else ...[
                '-vf',
                '$normalizedCropFilter,setsar=1',
                '-map',
                '0:v:0',
              ],
              '-map',
              '0:a:0?',
              // Use broadly compatible encoding so exported files open reliably
              // in default OS players outside the app.
              '-c:v',
              'libx264',
              '-preset',
              'medium',
              '-crf',
              '20',
              '-profile:v',
              'baseline',
              '-level',
              '3.0',
              '-pix_fmt',
              'yuv420p',
              '-c:a',
              'aac',
              '-profile:a',
              'aac_low',
              '-ar',
              '44100',
              '-ac',
              '2',
              '-b:a',
              '192k',
              '-f',
              'mp4',
              '-movflags',
              '+faststart',
              '-avoid_negative_ts',
              'make_zero',
              '-y', // Overwrite output
              normalizedOutputPath,
            ];

      state = state.copyWith(
        exportStatus: ExportStatus.exporting,
        clearPreparationMessage: true,
        clearPreparationProgress: true,
      );

      // Start FFmpeg process
      _ffmpegProcess = await Process.start(ffmpegPath, args);
      // Drain stdout to avoid process pipe backpressure deadlocks.
      unawaited(_ffmpegProcess!.stdout.drain<void>());

      // Track duration for progress calculation
      final durationSeconds = targetDurationMs / 1000.0;

      // Monitor stderr for progress (FFmpeg outputs progress to stderr)
      final stderrLines = <String>[];
      _ffmpegProcess!.stderr.transform(const SystemEncoding().decoder).listen((
        data,
      ) {
        stderrLines.add(data);

        // Parse progress: look for "time=" in output
        final timeMatch = RegExp(
          r'time=(\d+):(\d+):(\d+\.\d+)',
        ).firstMatch(data);
        if (timeMatch != null && durationSeconds > 0) {
          final hours = int.parse(timeMatch.group(1)!);
          final minutes = int.parse(timeMatch.group(2)!);
          final seconds = double.parse(timeMatch.group(3)!);
          final currentSeconds = hours * 3600 + minutes * 60 + seconds;
          final progress = currentSeconds / durationSeconds;
          state = state.copyWith(exportProgress: progress.clamp(0.0, 1.0));
        }
      });

      // Wait for process to complete
      final exitCode = await _ffmpegProcess!.exitCode;

      if (_cancelRequested) {
        // Clean up partial file
        try {
          await File(normalizedOutputPath).delete();
        } catch (_) {}
        state = state.copyWith(
          exportStatus: ExportStatus.cancelled,
          exportProgress: 0.0,
          clearPreparationMessage: true,
          clearPreparationProgress: true,
        );
      } else if (exitCode == 0) {
        final outputFile = File(normalizedOutputPath);
        if (!await outputFile.exists() || await outputFile.length() == 0) {
          state = state.copyWith(
            exportStatus: ExportStatus.error,
            clearPreparationMessage: true,
            clearPreparationProgress: true,
            exportError: 'Export completed but output file is invalid.',
          );
          return;
        }

        final validation = await Process.run(ffmpegPath, [
          '-v',
          'error',
          '-i',
          normalizedOutputPath,
          '-f',
          'null',
          '-',
        ]);
        if (validation.exitCode != 0) {
          final validationOutput = (validation.stderr ?? '').toString();
          final validationMessage = validationOutput.isEmpty
              ? 'Unknown validation error'
              : validationOutput.split('\n').take(5).join('\n');
          try {
            await File(normalizedOutputPath).delete();
          } catch (_) {}
          state = state.copyWith(
            exportStatus: ExportStatus.error,
            clearPreparationMessage: true,
            clearPreparationProgress: true,
            exportError: 'Exported file failed validation:\n$validationMessage',
          );
          return;
        }

        state = state.copyWith(
          exportStatus: ExportStatus.success,
          exportProgress: 1.0,
          clearPreparationMessage: true,
          clearPreparationProgress: true,
          exportedFilePath: normalizedOutputPath,
        );
      } else {
        try {
          await File(normalizedOutputPath).delete();
        } catch (_) {}
        final tail = stderrLines
            .join('\n')
            .split('\n')
            .where((line) => line.trim().isNotEmpty)
            .toList();
        final tailMessage = tail.isEmpty
            ? 'No ffmpeg stderr output captured.'
            : tail.skip(tail.length > 12 ? tail.length - 12 : 0).join('\n');
        state = state.copyWith(
          exportStatus: ExportStatus.error,
          clearPreparationMessage: true,
          clearPreparationProgress: true,
          exportError: 'Export failed (exit code: $exitCode)\n$tailMessage',
        );
      }
    } catch (e) {
      state = state.copyWith(
        exportStatus: ExportStatus.error,
        clearPreparationMessage: true,
        clearPreparationProgress: true,
        exportError: 'Failed to export video: $e',
      );
    } finally {
      _progressTimer?.cancel();
      _ffmpegProcess = null;
      if (overlayTempDir != null) {
        try {
          if (await overlayTempDir.exists()) {
            await overlayTempDir.delete(recursive: true);
          }
        } catch (_) {}
      }
    }
  }

  bool _isFullFrameCrop(CropRect rect) {
    const epsilon = 0.0005;
    return rect.left.abs() <= epsilon &&
        rect.top.abs() <= epsilon &&
        (1.0 - rect.right).abs() <= epsilon &&
        (1.0 - rect.bottom).abs() <= epsilon;
  }

  bool _hasAnnotationsInRange({
    required AnnotationData? annotationData,
    required int startMs,
    required int endMs,
  }) {
    if (annotationData == null || annotationData.strokes.isEmpty) return false;

    for (final stroke in annotationData.strokes) {
      final strokeStart = stroke.startTimeMs;
      final strokeEnd = stroke.endTimeMs > strokeStart
          ? stroke.endTimeMs
          : strokeStart + 1;
      if (strokeEnd <= startMs || strokeStart >= endMs) {
        continue;
      }
      return true;
    }

    return false;
  }

  Future<List<_TimedOverlay>> _prepareAnnotationOverlays({
    required AnnotationData? annotationData,
    required int videoWidth,
    required int videoHeight,
    required int startMs,
    required int endMs,
    required Directory tempDir,
  }) async {
    if (annotationData == null || annotationData.strokes.isEmpty) {
      return const [];
    }

    final fps = annotationData.fps > 0 ? annotationData.fps : 30.0;
    int snap(int ms) {
      final frameMs = 1000.0 / fps;
      final frame = (ms / frameMs).round();
      return (frame * frameMs).round();
    }

    final grouped = <int, List<Stroke>>{};
    for (final stroke in annotationData.strokes) {
      final keyframeMs = snap(stroke.startTimeMs);
      grouped.putIfAbsent(keyframeMs, () => <Stroke>[]).add(stroke);
    }

    if (grouped.isEmpty) return const [];

    final keyframes = grouped.keys.toList()..sort();
    final overlays = <_TimedOverlay>[];

    for (int i = 0; i < keyframes.length; i++) {
      final keyframeMs = keyframes[i];
      final nextKeyframeMs = i + 1 < keyframes.length
          ? keyframes[i + 1]
          : endMs;

      final intervalStartMs = keyframeMs > startMs ? keyframeMs : startMs;
      final intervalEndMs = nextKeyframeMs < endMs ? nextKeyframeMs : endMs;
      if (intervalEndMs <= intervalStartMs) continue;

      final relativeStart = (intervalStartMs - startMs) / 1000.0;
      final relativeEnd = (intervalEndMs - startMs) / 1000.0;

      final overlayPath = path.join(
        tempDir.path,
        'overlay_${i.toString().padLeft(4, '0')}.png',
      );

      await _overlayRenderer.renderOverlayImage(
        outputPath: overlayPath,
        strokes: grouped[keyframeMs]!,
        width: videoWidth,
        height: videoHeight,
        viewportWidth: annotationData.viewportWidth,
        viewportHeight: annotationData.viewportHeight,
      );

      overlays.add(
        _TimedOverlay(
          path: overlayPath,
          startSec: relativeStart,
          endSec: relativeEnd,
        ),
      );
    }

    return overlays;
  }

  String _buildFilterComplex({
    required List<_TimedOverlay> overlays,
    required String cropFilter,
  }) {
    if (overlays.isEmpty) {
      return '[0:v]$cropFilter,setsar=1[vout]';
    }

    final steps = <String>[];
    String previous = '0:v';

    for (int i = 0; i < overlays.length; i++) {
      final inputLabel = '${i + 1}:v';
      final outputLabel = i == overlays.length - 1 ? 'v_overlayed' : 'v$i';
      final start = overlays[i].startSec.toStringAsFixed(3);
      final end = overlays[i].endSec.toStringAsFixed(3);
      steps.add(
        '[$previous][$inputLabel]overlay=enable=\'between(t\\,$start\\,$end)\'[$outputLabel]',
      );
      previous = outputLabel;
    }

    steps.add('[$previous]$cropFilter,setsar=1[vout]');
    return steps.join(';');
  }

  String _buildNormalizedCropFilter(CropRect rect) {
    final safeLeft = rect.left.clamp(0.0, 1.0);
    final safeTop = rect.top.clamp(0.0, 1.0);
    final safeWidth = rect.width.clamp(0.01, 1.0);
    final safeHeight = rect.height.clamp(0.01, 1.0);

    String f(double v) => v.toStringAsFixed(6);

    final wExpr = 'max(2\\,floor(iw*${f(safeWidth)}/2)*2)';
    final hExpr = 'max(2\\,floor(ih*${f(safeHeight)}/2)*2)';
    final xExpr = 'min(max(0\\,floor(iw*${f(safeLeft)}))\\,iw-$wExpr)';
    final yExpr = 'min(max(0\\,floor(ih*${f(safeTop)}))\\,ih-$hExpr)';

    return 'crop=$wExpr:$hExpr:$xExpr:$yExpr';
  }

  String _normalizeOutputPath(String outputPath) {
    final trimmed = outputPath.trim();
    final extension = path.extension(trimmed).toLowerCase();

    final hasValidExtension =
        extension.isNotEmpty &&
        extension != '.' &&
        RegExp(r'^\.[a-z0-9]+$').hasMatch(extension);

    if (!hasValidExtension) {
      return '${trimmed.replaceAll(RegExp(r'[. ]+$'), '')}.mp4';
    }

    if (extension != '.mp4') {
      final withoutExt = trimmed.substring(
        0,
        trimmed.length - extension.length,
      );
      return '$withoutExt.mp4';
    }

    return trimmed.replaceAll(RegExp(r'[. ]+$'), '');
  }

  /// Cancel ongoing export
  void cancelExport() {
    _cancelRequested = true;
    _ffmpegProcess?.kill();
    _progressTimer?.cancel();
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
  return CropNotifier(ref);
});

class _TimedOverlay {
  final String path;
  final double startSec;
  final double endSec;

  const _TimedOverlay({
    required this.path,
    required this.startSec,
    required this.endSec,
  });
}
