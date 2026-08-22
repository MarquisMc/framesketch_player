/// Crop/export domain models: aspect-ratio presets, the normalized crop
/// rectangle, export status, and the crop state consumed by the crop
/// provider.
library;

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
  /// Whether the editor is focused on crop/export controls.
  final bool isCropExportModeActive;

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

  /// Optional single-frame export preview selection.
  final Duration? exportFrameSelection;

  const CropState({
    this.isCropExportModeActive = false,
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
    this.exportFrameSelection,
  });

  CropState copyWith({
    bool? isCropExportModeActive,
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
    Duration? exportFrameSelection,
    bool clearExportFrameSelection = false,
  }) {
    return CropState(
      isCropExportModeActive:
          isCropExportModeActive ?? this.isCropExportModeActive,
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
      exportFrameSelection: clearExportFrameSelection
          ? null
          : (exportFrameSelection ?? this.exportFrameSelection),
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
