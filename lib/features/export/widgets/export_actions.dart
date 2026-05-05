import 'dart:async';
import 'dart:io' show Directory, File, Platform, Process, SystemEncoding;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/annotation_data.dart';
import '../../../core/models/video_metadata.dart';
import '../../../core/services/annotation_overlay_renderer_service.dart';
import '../../../core/services/ffprobe_service.dart';
import '../../../core/theme/app_palette.dart';
import '../../annotations/providers/annotation_provider.dart';
import '../../crop/providers/crop_provider.dart';
import '../../player/providers/player_provider.dart';
import '../application/export_orchestration_planner.dart';
import 'export_options_dialog.dart';

typedef ExportLoadingOverlayRunner =
    Future<T> Function<T>({
      required String message,
      required Future<T> Function() action,
      String? cancelLabel,
      VoidCallback? onCancel,
    });

typedef ExportSuggestedBaseNameBuilder =
    String Function({
      required AnnotationData annotationData,
      required String? playerSourceLabel,
    });

class ExportActions {
  ExportActions({
    required this.ref,
    required this.navigatorKey,
    required this.scaffoldMessengerKey,
    required this.focusNode,
    required this.isMounted,
    required this.activePalette,
    required this.runWithLoadingOverlay,
    required this.showErrorDialog,
    required this.buildSuggestedAnnotationFileBaseName,
    required this.setLoadingOverlayMessage,
    ExportOrchestrationPlanner planner = const ExportOrchestrationPlanner(),
    FFprobeService? ffprobeService,
    AnnotationOverlayRendererService? overlayRenderer,
  }) : _planner = planner,
       _ffprobeService = ffprobeService ?? FFprobeService(),
       _overlayRenderer = overlayRenderer ?? AnnotationOverlayRendererService();

  final WidgetRef ref;
  final GlobalKey<NavigatorState> navigatorKey;
  final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey;
  final FocusNode focusNode;
  final bool Function() isMounted;
  final AppPalette Function() activePalette;
  final ExportLoadingOverlayRunner runWithLoadingOverlay;
  final void Function(String message) showErrorDialog;
  final ExportSuggestedBaseNameBuilder buildSuggestedAnnotationFileBaseName;
  final void Function(String message) setLoadingOverlayMessage;
  final ExportOrchestrationPlanner _planner;
  final FFprobeService _ffprobeService;
  final AnnotationOverlayRendererService _overlayRenderer;

  bool _exportCancelRequested = false;
  Process? _activeFrameExportProcess;

  void dispose() {
    _exportCancelRequested = true;
    _activeFrameExportProcess?.kill();
    _activeFrameExportProcess = null;
  }

  Future<void> exportVideoFromTopBar() async {
    try {
      final playerState = ref.read(playerProvider);
      final annotationData = ref.read(annotationProvider).annotationData;

      if (playerState.currentVideoPath == null) {
        showErrorDialog('No video loaded');
        return;
      }
      if (annotationData == null || playerState.metadata == null) {
        showErrorDialog('Open a video before exporting.');
        return;
      }

      final cropState = ref.read(cropProvider);
      if (cropState.exportStatus == ExportStatus.exporting) {
        return;
      }

      final dialogHostContext = navigatorKey.currentContext;
      if (dialogHostContext == null || !isMounted()) {
        return;
      }

      final exportRequest = await showDialog<ExportRequest>(
        context: dialogHostContext,
        builder: (dialogContext) => ExportOptionsDialog(
          initialFrame: ref.read(playerProvider.notifier).currentFrame,
          metadata: playerState.metadata!,
          suggestedBaseName: buildSuggestedAnnotationFileBaseName(
            annotationData: annotationData,
            playerSourceLabel: playerState.currentSourceLabel,
          ),
          exportStart: cropState.exportStart,
          exportEnd: cropState.exportEnd,
          isLocalSource: playerState.isLocalFileSource,
        ),
      );

      if (exportRequest == null) {
        focusNode.requestFocus();
        return;
      }

      switch (exportRequest.mode) {
        case ExportMode.frame:
          await _exportSingleFrame(exportRequest);
          break;
        case ExportMode.frames:
          await _exportFrameRange(exportRequest);
          break;
        case ExportMode.video:
          await _exportAnnotatedVideo(exportRequest);
          break;
        case ExportMode.annotationFile:
          await _exportAnnotationFile(exportRequest, annotationData);
          break;
      }

      focusNode.requestFocus();
    } catch (e) {
      if (e is _ExportCancelledException) {
        _exportCancelRequested = false;
        if (isMounted()) {
          _showExportCancelledSnackBar();
          focusNode.requestFocus();
        }
        return;
      }
      if (isMounted()) {
        showErrorDialog('Error exporting video: $e');
      }
    }
  }

  Future<void> exportFramesFromPanel({
    required int startFrame,
    required int endFrame,
    required int step,
    required bool isPng,
  }) async {
    final playerState = ref.read(playerProvider);
    if (playerState.currentVideoPath == null || playerState.metadata == null) {
      showErrorDialog('No video loaded');
      return;
    }
    final annotationData = ref.read(annotationProvider).annotationData;
    if (annotationData == null) {
      showErrorDialog('Open a video before exporting.');
      return;
    }
    final suggestedBase = buildSuggestedAnnotationFileBaseName(
      annotationData: annotationData,
      playerSourceLabel: playerState.currentSourceLabel,
    );
    final cropState = ref.read(cropProvider);
    final meta = playerState.metadata!;
    final cropPixels = cropState.isCropModeActive
        ? cropState.cropRect.toPixels(meta.width, meta.height)
        : null;

    final request = ExportRequest(
      mode: startFrame == endFrame ? ExportMode.frame : ExportMode.frames,
      suggestedBaseName: suggestedBase,
      startFrame: startFrame,
      endFrame: endFrame,
      frameStep: step,
      frameFormat: isPng ? FrameExportFormat.png : FrameExportFormat.jpg,
      cropPixels: cropPixels,
    );
    try {
      if (startFrame == endFrame) {
        await _exportSingleFrame(request);
      } else {
        await _exportFrameRange(request);
      }
    } catch (e) {
      if (e is _ExportCancelledException) {
        _exportCancelRequested = false;
        if (isMounted()) _showExportCancelledSnackBar();
        return;
      }
      if (isMounted()) showErrorDialog('Error exporting frames: $e');
    } finally {
      focusNode.requestFocus();
    }
  }

  Future<void> _exportSingleFrame(ExportRequest request) async {
    final playerState = ref.read(playerProvider);
    final metadata = playerState.metadata;
    final videoPath = playerState.currentVideoPath;
    if (metadata == null || videoPath == null) {
      showErrorDialog('No video loaded');
      return;
    }

    final outputPath = await FilePicker.platform.saveFile(
      dialogTitle: 'Export Frame',
      fileName:
          '${request.suggestedBaseName}_frame_${request.startFrame.toString().padLeft(6, '0')}.${request.frameExtension}',
      type: FileType.custom,
      allowedExtensions: [request.frameExtension],
    );

    if (outputPath == null) {
      return;
    }

    final normalizedOutputPath = _ensureFileExtension(
      outputPath,
      request.frameExtension,
    );
    final timestamp = _durationForFrame(request.startFrame, metadata.fps);

    await runWithLoadingOverlay(
      message: 'Exporting frame ${request.startFrame}...',
      cancelLabel: 'Cancel Export',
      onCancel: _requestExportCancel,
      action: () async {
        _exportCancelRequested = false;
        await _exportFrameImage(
          videoPath,
          timestamp: timestamp,
          outputPath: normalizedOutputPath,
          metadata: metadata,
          annotationData: ref.read(annotationProvider).annotationData,
          cropPixels: request.cropPixels,
        );
      },
    );

    if (!isMounted()) return;
    if (_exportCancelRequested) {
      _exportCancelRequested = false;
      _showExportCancelledSnackBar();
      return;
    }
    scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text('Frame exported: $normalizedOutputPath'),
        backgroundColor: activePalette().success,
      ),
    );
  }

  Future<void> _exportFrameRange(ExportRequest request) async {
    final playerState = ref.read(playerProvider);
    final metadata = playerState.metadata;
    final videoPath = playerState.currentVideoPath;
    if (metadata == null || videoPath == null) {
      showErrorDialog('No video loaded');
      return;
    }

    final selectedDirectory = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Choose Folder for Exported Frames',
    );
    if (selectedDirectory == null) {
      return;
    }

    final outputDirectory = Directory(selectedDirectory);
    late final FrameRangeExportPlan framePlan;
    await runWithLoadingOverlay(
      message: 'Preparing frame export...',
      cancelLabel: 'Cancel Export',
      onCancel: _requestExportCancel,
      action: () async {
        _exportCancelRequested = false;
        final annotationData = ref.read(annotationProvider).annotationData;
        final ffmpegPath = await _findExportFfmpegPath();
        framePlan = _planner.planFrameRange(
          startFrame: request.startFrame,
          endFrame: request.endFrame,
          step: request.frameStep,
          fps: metadata.fps,
          outputDirectoryPath: outputDirectory.path,
          suggestedBaseName: request.suggestedBaseName,
          frameExtension: request.frameExtension,
          annotationData: annotationData,
        );

        setLoadingOverlayMessage(
          'Exporting ${framePlan.jobs.length} frames...',
        );

        switch (framePlan.route) {
          case FrameRangeExportRoute.unannotated:
            await _exportUnannotatedFrameRange(
              ffmpegPath: ffmpegPath,
              videoPath: videoPath,
              jobs: framePlan.jobs,
              selectExpression: framePlan.selectExpression,
              frameExtension: request.frameExtension,
              cropPixels: request.cropPixels,
            );
            break;
          case FrameRangeExportRoute.annotated:
            await _exportAnnotatedFrameRange(
              ffmpegPath: ffmpegPath,
              videoPath: videoPath,
              jobs: framePlan.jobs,
              metadata: metadata,
              annotationData: annotationData!,
              cropPixels: request.cropPixels,
            );
            break;
        }
      },
    );

    if (!isMounted()) return;
    if (_exportCancelRequested) {
      _exportCancelRequested = false;
      _showExportCancelledSnackBar();
      return;
    }
    scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text(
          'Exported ${framePlan.jobs.length} frames to ${outputDirectory.path}',
        ),
        backgroundColor: activePalette().success,
      ),
    );
  }

  Future<void> _exportAnnotatedVideo(ExportRequest request) async {
    final playerState = ref.read(playerProvider);
    if (!playerState.isLocalFileSource) {
      showErrorDialog('Video export is only available for local video files.');
      return;
    }

    final cropState = ref.read(cropProvider);
    final cropNotifier = ref.read(cropProvider.notifier);
    final annotationNotifier = ref.read(annotationProvider.notifier);
    final outputPath = await FilePicker.platform.saveFile(
      dialogTitle: 'Export Annotated Video',
      fileName: '${request.suggestedBaseName}_annotated.mp4',
      type: FileType.custom,
      allowedExtensions: const ['mp4'],
    );

    if (outputPath == null) {
      return;
    }

    final normalizedOutputPath = _ensureFileExtension(outputPath, 'mp4');
    final metadata = playerState.metadata;
    if (metadata == null) {
      showErrorDialog('Video metadata not available');
      return;
    }

    final previousStart = cropState.exportStart;
    final previousEnd = cropState.exportEnd;

    try {
      cropNotifier.setExportRange(
        start: _durationForFrame(request.startFrame, metadata.fps),
        end: _durationForFrame(request.endFrame + 1, metadata.fps),
      );

      await annotationNotifier.saveAnnotations();
      await runWithLoadingOverlay(
        message: 'Exporting annotated video...',
        cancelLabel: 'Cancel Export',
        onCancel: () {
          cropNotifier.cancelExport();
          if (!isMounted()) return;
          setLoadingOverlayMessage('Cancelling export...');
        },
        action: () => cropNotifier.exportCroppedVideo(
          normalizedOutputPath,
          annotationData: ref.read(annotationProvider).annotationData,
          preset: request.videoPreset,
        ),
      );
    } finally {
      cropNotifier.setExportRange(start: previousStart, end: previousEnd);
    }

    if (!isMounted()) return;

    final updatedCropState = ref.read(cropProvider);
    switch (updatedCropState.exportStatus) {
      case ExportStatus.success:
        scaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(
            content: Text(
              'Export complete: ${updatedCropState.exportedFilePath ?? normalizedOutputPath}',
            ),
            backgroundColor: activePalette().success,
          ),
        );
        break;
      case ExportStatus.cancelled:
        scaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(
            content: const Text('Export cancelled'),
            backgroundColor: activePalette().warning,
          ),
        );
        break;
      case ExportStatus.error:
        showErrorDialog(updatedCropState.exportError ?? 'Export failed');
        break;
      case ExportStatus.idle:
      case ExportStatus.preparing:
      case ExportStatus.exporting:
        break;
    }
  }

  Future<void> _exportFrameImage(
    String videoPath, {
    required Duration timestamp,
    required String outputPath,
    required VideoMetadata metadata,
    required AnnotationData? annotationData,
    ({int x, int y, int width, int height})? cropPixels,
  }) async {
    _throwIfExportCancelled();
    final visibleStrokes = ref
        .read(annotationProvider.notifier)
        .getVisibleStrokes(timestamp);
    if (annotationData == null || visibleStrokes.isEmpty) {
      final exported = await _extractFrameAtCancellable(
        videoPath,
        timestamp: timestamp,
        outputPath: outputPath,
        cropPixels: cropPixels,
      );
      if (exported == null) {
        throw StateError('Failed to export frame.');
      }
      return;
    }

    final ffmpegPath = await _findExportFfmpegPath();

    Directory? tempDir;
    try {
      tempDir = await Directory.systemTemp.createTemp(
        'framesketch_frame_export_',
      );
      final overlayPath =
          '${tempDir.path}${Platform.pathSeparator}frame_overlay.png';
      await _overlayRenderer.renderOverlayImage(
        outputPath: overlayPath,
        strokes: visibleStrokes,
        width: metadata.width,
        height: metadata.height,
        viewportWidth: annotationData.viewportWidth,
        viewportHeight: annotationData.viewportHeight,
      );

      final seconds = (timestamp.inMicroseconds / 1000000.0).toStringAsFixed(6);
      _throwIfExportCancelled();
      final filterComplex = cropPixels != null
          ? '[0:v][1:v]overlay=0:0[overlaid];[overlaid]crop=${cropPixels.width}:${cropPixels.height}:${cropPixels.x}:${cropPixels.y}'
          : '[0:v][1:v]overlay=0:0';
      final process = await Process.start(ffmpegPath, [
        '-hide_banner',
        '-ss',
        seconds,
        '-i',
        videoPath,
        '-i',
        overlayPath,
        '-filter_complex',
        filterComplex,
        '-frames:v',
        '1',
        '-q:v',
        '2',
        '-y',
        outputPath,
      ]);
      _activeFrameExportProcess = process;
      unawaited(process.stdout.drain<void>());
      unawaited(process.stderr.drain<void>());

      final result = await process.exitCode
          .timeout(
            const Duration(minutes: 2),
            onTimeout: () {
              process.kill();
              throw TimeoutException(
                'FFmpeg frame export exceeded 2 minute timeout',
              );
            },
          )
          .then((exitCode) => _ProcessResult(exitCode, '', ''));

      _throwIfExportCancelled();
      if (result.exitCode != 0) {
        throw StateError(
          'Failed to burn annotations into frame: ${result.stderr}',
        );
      }
    } finally {
      if (tempDir != null && await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
      _activeFrameExportProcess = null;
    }
  }

  Future<File?> _extractFrameAtCancellable(
    String videoPath, {
    required Duration timestamp,
    required String outputPath,
    String? ffmpegPath,
    ({int x, int y, int width, int height})? cropPixels,
  }) async {
    final resolvedFfmpegPath = ffmpegPath ?? await _findExportFfmpegPath();

    _throwIfExportCancelled();
    final seconds = (timestamp.inMicroseconds / 1000000.0).toStringAsFixed(6);
    final args = <String>[
      '-ss',
      seconds,
      '-i',
      videoPath,
      if (cropPixels != null) ...[
        '-vf',
        'crop=${cropPixels.width}:${cropPixels.height}:${cropPixels.x}:${cropPixels.y}',
      ],
      '-frames:v',
      '1',
      '-q:v',
      '2',
      '-y',
      outputPath,
    ];
    final process = await Process.start(resolvedFfmpegPath, args);
    _activeFrameExportProcess = process;

    final stderrBuffer = StringBuffer();
    unawaited(process.stdout.drain<void>());
    process.stderr
        .transform(const SystemEncoding().decoder)
        .listen(stderrBuffer.write);

    final exitCode = await process.exitCode.timeout(
      const Duration(minutes: 2),
      onTimeout: () {
        process.kill();
        throw TimeoutException('FFmpeg frame export exceeded 2 minute timeout');
      },
    );
    _activeFrameExportProcess = null;
    _throwIfExportCancelled();
    if (exitCode == 0) {
      return File(outputPath);
    }
    throw StateError('Failed to export frame: ${stderrBuffer.toString()}');
  }

  Future<String> _findExportFfmpegPath() async {
    final ffmpegPath = await _ffprobeService.findFFmpegPath();
    if (ffmpegPath == null) {
      throw StateError(
        'FFmpeg not found. Automatic provisioning failed. Check internet access and try again.',
      );
    }
    return ffmpegPath;
  }

  Future<void> _exportUnannotatedFrameRange({
    required String ffmpegPath,
    required String videoPath,
    required List<FrameRangeExportJob> jobs,
    required String selectExpression,
    required String frameExtension,
    ({int x, int y, int width, int height})? cropPixels,
  }) async {
    if (jobs.isEmpty) return;

    Directory? tempDir;
    try {
      tempDir = await Directory.systemTemp.createTemp(
        'framesketch_frame_range_',
      );
      final tempPattern =
          '${tempDir.path}${Platform.pathSeparator}frame_%06d.$frameExtension';
      final vfFilter = cropPixels != null
          ? 'select=$selectExpression,crop=${cropPixels.width}:${cropPixels.height}:${cropPixels.x}:${cropPixels.y}'
          : 'select=$selectExpression';

      _throwIfExportCancelled();
      final process = await Process.start(ffmpegPath, [
        '-hide_banner',
        '-i',
        videoPath,
        '-vf',
        vfFilter,
        '-vsync',
        '0',
        '-q:v',
        '2',
        '-y',
        tempPattern,
      ]);
      _activeFrameExportProcess = process;

      final stderrBuffer = StringBuffer();
      unawaited(process.stdout.drain<void>());
      process.stderr
          .transform(const SystemEncoding().decoder)
          .listen(stderrBuffer.write);

      final exitCode = await process.exitCode.timeout(
        const Duration(minutes: 10),
        onTimeout: () {
          process.kill();
          throw TimeoutException(
            'FFmpeg frame range export exceeded 10 minute timeout',
          );
        },
      );
      _activeFrameExportProcess = null;
      _throwIfExportCancelled();

      if (exitCode != 0) {
        throw StateError(
          'Failed to export frame range: ${stderrBuffer.toString()}',
        );
      }

      for (var index = 0; index < jobs.length; index += 1) {
        _throwIfExportCancelled();
        final tempPath =
            '${tempDir.path}${Platform.pathSeparator}frame_${(index + 1).toString().padLeft(6, '0')}.$frameExtension';
        final tempFile = File(tempPath);
        if (!await tempFile.exists()) {
          throw StateError(
            'Frame range export produced fewer frames than expected.',
          );
        }
        final outputFile = File(jobs[index].outputPath);
        if (await outputFile.exists()) {
          await outputFile.delete();
        }
        await tempFile.rename(jobs[index].outputPath);
        _updateFrameRangeProgress(index + 1, jobs.length);
      }
    } finally {
      _activeFrameExportProcess = null;
      if (tempDir != null && await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    }
  }

  Future<void> _exportAnnotatedFrameRange({
    required String ffmpegPath,
    required String videoPath,
    required List<FrameRangeExportJob> jobs,
    required VideoMetadata metadata,
    required AnnotationData annotationData,
    ({int x, int y, int width, int height})? cropPixels,
  }) async {
    Directory? tempDir;
    try {
      tempDir = await Directory.systemTemp.createTemp(
        'framesketch_annotated_frames_',
      );
      final overlayCache = <int, String>{};

      for (var index = 0; index < jobs.length; index += 1) {
        _throwIfExportCancelled();
        final job = jobs[index];
        if (job.visibleStrokes.isEmpty) {
          final exported = await _extractFrameAtCancellable(
            videoPath,
            timestamp: job.timestamp,
            outputPath: job.outputPath,
            ffmpegPath: ffmpegPath,
            cropPixels: cropPixels,
          );
          if (exported == null) {
            throw StateError('Failed to export frame.');
          }
          _updateFrameRangeProgress(index + 1, jobs.length);
          continue;
        }

        final keyframeMs = job.activeKeyframeMs ?? job.timestamp.inMilliseconds;
        var overlayPath = overlayCache[keyframeMs];
        if (overlayPath == null) {
          overlayPath =
              '${tempDir.path}${Platform.pathSeparator}overlay_${overlayCache.length.toString().padLeft(4, '0')}.png';
          await _overlayRenderer.renderOverlayImage(
            outputPath: overlayPath,
            strokes: job.visibleStrokes,
            width: metadata.width,
            height: metadata.height,
            viewportWidth: annotationData.viewportWidth,
            viewportHeight: annotationData.viewportHeight,
          );
          overlayCache[keyframeMs] = overlayPath;
        }

        await _exportAnnotatedFrameImageWithOverlay(
          ffmpegPath: ffmpegPath,
          videoPath: videoPath,
          timestamp: job.timestamp,
          outputPath: job.outputPath,
          overlayPath: overlayPath,
          cropPixels: cropPixels,
        );
        _updateFrameRangeProgress(index + 1, jobs.length);
      }
    } finally {
      if (tempDir != null && await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
      _activeFrameExportProcess = null;
    }
  }

  Future<void> _exportAnnotatedFrameImageWithOverlay({
    required String ffmpegPath,
    required String videoPath,
    required Duration timestamp,
    required String outputPath,
    required String overlayPath,
    ({int x, int y, int width, int height})? cropPixels,
  }) async {
    final seconds = (timestamp.inMicroseconds / 1000000.0).toStringAsFixed(6);
    _throwIfExportCancelled();
    final filterComplex = cropPixels != null
        ? '[0:v]crop=${cropPixels.width}:${cropPixels.height}:${cropPixels.x}:${cropPixels.y}[cropped];[cropped][1:v]overlay=0:0'
        : '[0:v][1:v]overlay=0:0';
    final process = await Process.start(ffmpegPath, [
      '-hide_banner',
      '-ss',
      seconds,
      '-i',
      videoPath,
      '-i',
      overlayPath,
      '-filter_complex',
      filterComplex,
      '-frames:v',
      '1',
      '-q:v',
      '2',
      '-y',
      outputPath,
    ]);
    _activeFrameExportProcess = process;
    unawaited(process.stdout.drain<void>());
    unawaited(process.stderr.drain<void>());

    final exitCode = await process.exitCode.timeout(
      const Duration(minutes: 2),
      onTimeout: () {
        process.kill();
        throw TimeoutException('FFmpeg frame export exceeded 2 minute timeout');
      },
    );
    _activeFrameExportProcess = null;
    _throwIfExportCancelled();
    if (exitCode != 0) {
      throw StateError('Failed to burn annotations into frame.');
    }
  }

  void _updateFrameRangeProgress(int completedFrames, int totalFrames) {
    if (!isMounted()) return;
    final progressPercent = ((completedFrames / totalFrames) * 100).round();
    setLoadingOverlayMessage(
      'Exporting frame $completedFrames/$totalFrames ($progressPercent%)',
    );
  }

  void _requestExportCancel() {
    _exportCancelRequested = true;
    _activeFrameExportProcess?.kill();
    if (!isMounted()) return;
    setLoadingOverlayMessage('Cancelling export...');
  }

  void _throwIfExportCancelled() {
    if (_exportCancelRequested) {
      throw const _ExportCancelledException();
    }
  }

  void _showExportCancelledSnackBar() {
    scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: const Text('Export cancelled'),
        backgroundColor: activePalette().warning,
      ),
    );
  }

  Future<void> _exportAnnotationFile(
    ExportRequest request,
    AnnotationData annotationData,
  ) async {
    final extension = request.annotationExtension;
    final selectedPath = await FilePicker.platform.saveFile(
      dialogTitle: 'Export Annotation File',
      fileName: '${request.suggestedBaseName}.$extension',
      type: FileType.custom,
      allowedExtensions: ['framesketch', 'json'],
    );

    if (selectedPath == null) {
      return;
    }

    final outputPath = _ensureFileExtension(selectedPath, extension);
    final success = await ref
        .read(annotationProvider.notifier)
        .saveAnnotationsToFile(outputPath);

    if (!isMounted()) return;
    if (success) {
      scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text('Annotation file exported: $outputPath'),
          backgroundColor: activePalette().success,
        ),
      );
    } else {
      showErrorDialog('Failed to export annotation file');
    }
  }

  Duration _durationForFrame(int frame, double fps) {
    if (fps <= 0) {
      return Duration(milliseconds: frame * 33);
    }
    final micros = ((frame * 1000000.0) / fps).round();
    return Duration(microseconds: micros);
  }

  String _ensureFileExtension(String path, String extension) {
    final normalizedExtension = extension.startsWith('.')
        ? extension.substring(1)
        : extension;
    final lowerPath = path.toLowerCase();
    final suffix = '.${normalizedExtension.toLowerCase()}';
    if (lowerPath.endsWith(suffix)) {
      return path;
    }
    return '$path.$normalizedExtension';
  }
}

class _ExportCancelledException implements Exception {
  const _ExportCancelledException();
}

class _ProcessResult {
  final int exitCode;
  final String stdout;
  final String stderr;

  _ProcessResult(this.exitCode, this.stdout, this.stderr);
}
