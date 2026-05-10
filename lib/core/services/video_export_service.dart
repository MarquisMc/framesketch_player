import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;

import '../../features/annotations/models/stroke.dart';
import '../models/annotation_data.dart';
import 'annotation_overlay_renderer_service.dart';
import 'annotation_storage_service.dart';
import 'export_metrics_service.dart';
import 'ffmpeg_binaries_service.dart';
import 'video_export_models.dart';

typedef VideoExportPreparationCallback =
    void Function(FFmpegProvisioningProgress progress);
typedef VideoExportProgressCallback = void Function(double progress);

class VideoExportService {
  static const bool _useFullDecodeValidation = false;

  final AnnotationOverlayRendererService _overlayRenderer;
  final AnnotationStorageService _annotationStorage;
  final FFmpegBinariesService _ffmpegBinaries;
  final StreamController<void> _cancelController =
      StreamController<void>.broadcast();

  Process? _ffmpegProcess;
  bool _cancelRequested = false;

  VideoExportService({
    AnnotationOverlayRendererService? overlayRenderer,
    AnnotationStorageService? annotationStorage,
    FFmpegBinariesService? ffmpegBinaries,
  }) : _overlayRenderer = overlayRenderer ?? AnnotationOverlayRendererService(),
       _annotationStorage = annotationStorage ?? AnnotationStorageService(),
       _ffmpegBinaries = ffmpegBinaries ?? FFmpegBinariesService();

  Future<VideoExportResult> export(
    VideoExportRequest request, {
    VideoExportPreparationCallback? onPreparationProgress,
    VoidCallback? onExporting,
    VideoExportProgressCallback? onProgress,
  }) async {
    _cancelRequested = false;

    final normalizedOutputPath = normalizeOutputPath(request.outputPath);
    final fullMs = request.fullDuration.inMilliseconds;
    var startMs = request.start?.inMilliseconds ?? 0;
    var endMs = request.end?.inMilliseconds ?? fullMs;

    startMs = startMs.clamp(0, fullMs);
    endMs = endMs.clamp(0, fullMs);

    final targetDurationMs = endMs - startMs;
    final isSegmentedExport = startMs > 0 || endMs < fullMs;
    if (targetDurationMs <= 0) {
      return VideoExportResult.error(
        outputPath: normalizedOutputPath,
        errorMessage: 'Invalid export range selected',
      );
    }

    final cropGeometry = _buildCropGeometry(
      rect: request.cropRect,
      videoWidth: request.videoWidth,
      videoHeight: request.videoHeight,
    );
    final normalizedCropFilter = cropGeometry.filter;
    final metrics = ExportMetricsService()
      ..setValue('input path', request.inputPath)
      ..setValue('output path', normalizedOutputPath)
      ..setValue(
        'video dimensions',
        '${request.videoWidth}x${request.videoHeight}',
      )
      ..setValue('crop rect', request.cropRect)
      ..setValue(
        'export range',
        '${Duration(milliseconds: startMs)} - ${Duration(milliseconds: endMs)} '
            '(${Duration(milliseconds: targetDurationMs)})',
      );

    final annotationLoadingTimer = metrics.startTiming();
    final effectiveAnnotationData =
        request.annotationData ??
        await _annotationStorage.loadAnnotations(request.inputPath);
    metrics.stopTiming('annotation loading', annotationLoadingTimer);

    final overlayFramePlans = planOverlayFrames(
      annotationData: effectiveAnnotationData,
      startMs: startMs,
      endMs: endMs,
    );
    final hasActiveAnnotations = overlayFramePlans.any(
      (frame) => frame.strokes.isNotEmpty,
    );
    final annotationCounts = _countActiveOverlayFrameAnnotations(
      overlayFramePlans,
    );
    final useStreamCopy = request.cropRect.isFullFrame && !hasActiveAnnotations;
    metrics
      ..setValue(
        'annotation stroke count',
        effectiveAnnotationData?.strokes.length ?? 0,
      )
      ..setValue('active annotation stroke count', annotationCounts.strokeCount)
      ..setValue('active annotation keyframe count', annotationCounts.keyframes)
      ..setValue('stream copy used', useStreamCopy)
      ..setValue('re-encode used', !useStreamCopy)
      ..setValue('export preset', request.preset.displayName)
      ..setValue(
        'encoder settings',
        useStreamCopy ? 'copy' : request.preset.encoderSummary,
      );

    Directory? overlayTempDir;

    try {
      final ffmpegDiscoveryTimer = metrics.startTiming();
      final ffmpegPath = await _ffmpegBinaries.findFFmpegPath(
        onProgress: onPreparationProgress,
      );
      metrics.stopTiming(
        'FFmpeg binary discovery/provisioning',
        ffmpegDiscoveryTimer,
      );
      if (ffmpegPath == null) {
        return VideoExportResult.error(
          outputPath: normalizedOutputPath,
          errorMessage:
              'FFmpeg not found. Automatic provisioning failed. Check internet access and try again.',
        );
      }
      if (_cancelRequested) {
        return VideoExportResult.cancelled(outputPath: normalizedOutputPath);
      }

      PreparedOverlayStream? overlayStream;
      final overlayPreparationTimer = metrics.startTiming();
      if (!useStreamCopy) {
        overlayTempDir = await Directory.systemTemp.createTemp(
          'framesketch_annotation_overlays_',
        );
        overlayStream = await _prepareAnnotationOverlayStream(
          annotationData: effectiveAnnotationData,
          framePlans: overlayFramePlans,
          cropGeometry: cropGeometry,
          tempDir: overlayTempDir,
        );
      }
      metrics
        ..stopTiming('overlay preparation', overlayPreparationTimer)
        ..setValue('overlay count', overlayStream?.frameCount ?? 0)
        ..setValue(
          'overlay stream used',
          overlayStream == null ? false : overlayStream.frameCount > 0,
        )
        ..setValue(
          'overlay dimensions',
          overlayStream == null
              ? 'none'
              : '${overlayStream.width}x${overlayStream.height}',
        );
      if (_cancelRequested) {
        return VideoExportResult.cancelled(outputPath: normalizedOutputPath);
      }

      final args = _buildFfmpegArgs(
        inputPath: request.inputPath,
        outputPath: normalizedOutputPath,
        startMs: startMs,
        targetDurationMs: targetDurationMs,
        isSegmentedExport: isSegmentedExport,
        useStreamCopy: useStreamCopy,
        overlayStream: overlayStream,
        cropFilter: normalizedCropFilter,
        preset: request.preset,
      );

      onExporting?.call();

      final ffmpegProcessTimer = metrics.startTiming();
      _ffmpegProcess = await Process.start(ffmpegPath, args);
      final stdoutDone = _ffmpegProcess!.stdout.drain<void>();

      final durationSeconds = targetDurationMs / 1000.0;
      final stderrLines = <String>[];
      final stderrDone = _ffmpegProcess!.stderr
          .transform(const SystemEncoding().decoder)
          .forEach((data) {
            stderrLines.addAll(
              data
                  .split('\n')
                  .map((line) => line.trimRight())
                  .where((line) => line.trim().isNotEmpty),
            );
            final progress = _parseProgress(data, durationSeconds);
            if (progress != null) {
              onProgress?.call(progress);
            }
          });

      final exitCode = await _ffmpegProcess!.exitCode;
      await Future.wait([stdoutDone, stderrDone]);

      metrics
        ..stopTiming('FFmpeg process runtime', ffmpegProcessTimer)
        ..setValue('FFmpeg exit code', exitCode);

      if (_cancelRequested) {
        await _deleteIfExists(normalizedOutputPath);
        return VideoExportResult.cancelled(outputPath: normalizedOutputPath);
      }

      if (exitCode != 0) {
        await _deleteIfExists(normalizedOutputPath);
        return VideoExportResult.error(
          outputPath: normalizedOutputPath,
          errorMessage:
              'Export failed (exit code: $exitCode)\n${_stderrTail(stderrLines)}',
        );
      }

      final outputFile = File(normalizedOutputPath);
      if (!await outputFile.exists() || await outputFile.length() == 0) {
        return VideoExportResult.error(
          outputPath: normalizedOutputPath,
          errorMessage: 'Export completed but output file is invalid.',
        );
      }

      final validationResult = await _validateExport(
        ffmpegPath: ffmpegPath,
        expectedDuration: Duration(milliseconds: targetDurationMs),
        outputPath: normalizedOutputPath,
        metrics: metrics,
      );
      if (_cancelRequested) {
        await _deleteIfExists(normalizedOutputPath);
        return VideoExportResult.cancelled(outputPath: normalizedOutputPath);
      }
      if (validationResult != null) {
        await _deleteIfExists(normalizedOutputPath);
        return VideoExportResult.error(
          outputPath: normalizedOutputPath,
          errorMessage: validationResult,
        );
      }

      return VideoExportResult.success(outputPath: normalizedOutputPath);
    } catch (e) {
      return VideoExportResult.error(
        outputPath: normalizedOutputPath,
        errorMessage: 'Failed to export video: $e',
      );
    } finally {
      _ffmpegProcess = null;
      final cleanupTimer = metrics.startTiming();
      if (overlayTempDir != null) {
        try {
          if (await overlayTempDir.exists()) {
            await overlayTempDir.delete(recursive: true);
          }
        } catch (_) {}
      }
      metrics.stopTiming('cleanup runtime', cleanupTimer);
      metrics.logSummary();
    }
  }

  void cancel() {
    _cancelRequested = true;
    _cancelController.add(null);
    _ffmpegProcess?.kill();
  }

  Future<int> _waitForProcessExitWithCancellation(Process process) async {
    final exitCodeCompleter = Completer<int>();
    late final StreamSubscription<void> cancelSubscription;

    cancelSubscription = _cancelController.stream.listen((_) {
      process.kill();
    });

    if (_cancelRequested) {
      process.kill();
    }

    process.exitCode.then(
      (exitCode) {
        if (!exitCodeCompleter.isCompleted) {
          exitCodeCompleter.complete(exitCode);
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        if (!exitCodeCompleter.isCompleted) {
          exitCodeCompleter.completeError(error, stackTrace);
        }
      },
    );

    try {
      return await exitCodeCompleter.future;
    } finally {
      await cancelSubscription.cancel();
    }
  }

  String normalizeOutputPath(String outputPath) {
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

  List<String> _buildFfmpegArgs({
    required String inputPath,
    required String outputPath,
    required int startMs,
    required int targetDurationMs,
    required bool isSegmentedExport,
    required bool useStreamCopy,
    required PreparedOverlayStream? overlayStream,
    required String cropFilter,
    required VideoExportPreset preset,
  }) {
    if (useStreamCopy) {
      return <String>[
        '-hide_banner',
        if (startMs > 0) ...['-ss', (startMs / 1000.0).toStringAsFixed(3)],
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
        outputPath,
      ];
    }

    return <String>[
      '-hide_banner',
      '-fflags',
      '+genpts',
      if (startMs > 0) ...['-ss', (startMs / 1000.0).toStringAsFixed(3)],
      '-i',
      inputPath,
      if (overlayStream != null) ...[
        '-f',
        'concat',
        '-safe',
        '0',
        '-i',
        overlayStream.manifestPath,
      ],
      if (isSegmentedExport || overlayStream != null) ...[
        '-t',
        (targetDurationMs / 1000.0).toStringAsFixed(3),
      ],
      if (overlayStream != null) ...[
        '-filter_complex',
        _buildFilterComplex(hasOverlayStream: true, cropFilter: cropFilter),
        '-map',
        '[vout]',
      ] else ...[
        '-vf',
        '$cropFilter,setsar=1',
        '-map',
        '0:v:0',
      ],
      '-map',
      '0:a:0?',
      '-c:v',
      'libx264',
      '-preset',
      preset.ffmpegPreset,
      '-crf',
      preset.crf,
      if (preset.useBaselineProfile) ...[
        '-profile:v',
        'baseline',
        '-level',
        '3.0',
      ],
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
      '-y',
      outputPath,
    ];
  }

  Future<String?> _validateExport({
    required String ffmpegPath,
    required Duration expectedDuration,
    required String outputPath,
    required ExportMetricsService metrics,
  }) async {
    if (_useFullDecodeValidation) {
      return _validateExportWithFullDecode(
        ffmpegPath: ffmpegPath,
        outputPath: outputPath,
        metrics: metrics,
      );
    }

    final validationTimer = metrics.startTiming();
    try {
      final outputFile = File(outputPath);
      if (!await outputFile.exists()) {
        metrics
          ..stopTiming('validation runtime', validationTimer)
          ..setValue('validation mode', 'ffprobe')
          ..setValue('validation exit code', null);
        return 'Export completed but output file is missing.';
      }

      final outputSize = await outputFile.length();
      if (outputSize <= 0) {
        metrics
          ..stopTiming('validation runtime', validationTimer)
          ..setValue('validation mode', 'ffprobe')
          ..setValue('validation exit code', null);
        return 'Export completed but output file is empty.';
      }

      final ffprobePath = await _ffmpegBinaries.findFFprobePath();
      if (ffprobePath == null) {
        metrics.stopTiming('validation runtime', validationTimer);
        return _validateExportWithQuickFfmpeg(
          ffmpegPath: ffmpegPath,
          outputPath: outputPath,
          metrics: metrics,
        );
      }

      final validationProcess = await Process.start(ffprobePath, [
        '-v',
        'error',
        '-print_format',
        'json',
        '-show_format',
        '-show_streams',
        '-select_streams',
        'v:0',
        outputPath,
      ]);
      _ffmpegProcess = validationProcess;

      final validationStdout = StringBuffer();
      final validationStderr = StringBuffer();
      final validationStdoutDone = validationProcess.stdout
          .transform(const SystemEncoding().decoder)
          .forEach(validationStdout.write);
      final validationStderrDone = validationProcess.stderr
          .transform(const SystemEncoding().decoder)
          .forEach(validationStderr.write);

      final validationExitCode = await _waitForProcessExitWithCancellation(
        validationProcess,
      );
      await Future.wait([validationStdoutDone, validationStderrDone]);
      metrics
        ..stopTiming('validation runtime', validationTimer)
        ..setValue('validation mode', 'ffprobe')
        ..setValue('validation exit code', validationExitCode);

      if (_cancelRequested) return null;

      if (validationExitCode != 0) {
        final validationOutput = validationStderr.toString();
        final validationMessage = validationOutput.isEmpty
            ? 'Unknown validation error'
            : validationOutput.split('\n').take(5).join('\n');
        return 'Exported file failed validation:\n$validationMessage';
      }

      return _validateProbeJson(
        jsonText: validationStdout.toString(),
        expectedDuration: expectedDuration,
      );
    } catch (e) {
      if (validationTimer.isRunning) {
        metrics
          ..stopTiming('validation runtime', validationTimer)
          ..setValue('validation mode', 'ffprobe')
          ..setValue('validation exit code', null);
      }
      return 'Exported file failed validation: $e';
    }
  }

  Future<String?> _validateExportWithFullDecode({
    required String ffmpegPath,
    required String outputPath,
    required ExportMetricsService metrics,
  }) async {
    final validationTimer = metrics.startTiming();
    final validationProcess = await Process.start(ffmpegPath, [
      '-v',
      'error',
      '-i',
      outputPath,
      '-f',
      'null',
      '-',
    ]);
    _ffmpegProcess = validationProcess;

    final validationStdout = StringBuffer();
    final validationStderr = StringBuffer();
    final validationStdoutDone = validationProcess.stdout
        .transform(const SystemEncoding().decoder)
        .forEach(validationStdout.write);
    final validationStderrDone = validationProcess.stderr
        .transform(const SystemEncoding().decoder)
        .forEach(validationStderr.write);

    final validationExitCode = await _waitForProcessExitWithCancellation(
      validationProcess,
    );
    await Future.wait([validationStdoutDone, validationStderrDone]);
    metrics
      ..stopTiming('validation runtime', validationTimer)
      ..setValue('validation mode', 'full decode')
      ..setValue('validation exit code', validationExitCode);

    if (validationExitCode == 0) return null;

    final validationOutput = validationStderr.toString();
    final validationMessage = validationOutput.isEmpty
        ? 'Unknown validation error'
        : validationOutput.split('\n').take(5).join('\n');
    return 'Exported file failed validation:\n$validationMessage';
  }

  Future<String?> _validateExportWithQuickFfmpeg({
    required String ffmpegPath,
    required String outputPath,
    required ExportMetricsService metrics,
  }) async {
    final validationTimer = metrics.startTiming();
    final validationProcess = await Process.start(ffmpegPath, [
      '-v',
      'error',
      '-i',
      outputPath,
      '-map',
      '0:v:0',
      '-frames:v',
      '1',
      '-f',
      'null',
      '-',
    ]);
    _ffmpegProcess = validationProcess;

    final validationStdout = StringBuffer();
    final validationStderr = StringBuffer();
    final validationStdoutDone = validationProcess.stdout
        .transform(const SystemEncoding().decoder)
        .forEach(validationStdout.write);
    final validationStderrDone = validationProcess.stderr
        .transform(const SystemEncoding().decoder)
        .forEach(validationStderr.write);

    final validationExitCode = await _waitForProcessExitWithCancellation(
      validationProcess,
    );
    await Future.wait([validationStdoutDone, validationStderrDone]);
    metrics
      ..stopTiming('validation runtime', validationTimer)
      ..setValue('validation mode', 'quick ffmpeg')
      ..setValue('validation exit code', validationExitCode);

    if (validationExitCode == 0) return null;

    final validationOutput = validationStderr.toString();
    final validationMessage = validationOutput.isEmpty
        ? 'Unknown validation error'
        : validationOutput.split('\n').take(5).join('\n');
    return 'Exported file failed validation:\n$validationMessage';
  }

  String? _validateProbeJson({
    required String jsonText,
    required Duration expectedDuration,
  }) {
    final decoded = json.decode(jsonText) as Map<String, dynamic>;
    final streams = decoded['streams'] as List<dynamic>?;
    if (streams == null || streams.isEmpty) {
      return 'Exported file failed validation: no video stream found.';
    }

    final videoStream = streams.first as Map<String, dynamic>;
    final codecType = videoStream['codec_type']?.toString();
    if (codecType != null && codecType != 'video') {
      return 'Exported file failed validation: first stream is not video.';
    }

    final width = int.tryParse(videoStream['width']?.toString() ?? '');
    final height = int.tryParse(videoStream['height']?.toString() ?? '');
    if (width == null || height == null || width <= 0 || height <= 0) {
      return 'Exported file failed validation: video stream has invalid dimensions.';
    }

    final format = decoded['format'] as Map<String, dynamic>?;
    final durationSeconds =
        double.tryParse(videoStream['duration']?.toString() ?? '') ??
        double.tryParse(format?['duration']?.toString() ?? '') ??
        0.0;
    if (durationSeconds <= 0) {
      return 'Exported file failed validation: duration is missing or zero.';
    }

    final expectedSeconds = expectedDuration.inMilliseconds / 1000.0;
    if (expectedSeconds > 0) {
      final toleranceSeconds = expectedSeconds < 2.0
          ? 1.0
          : (expectedSeconds * 0.10).clamp(1.0, 5.0);
      if ((durationSeconds - expectedSeconds).abs() > toleranceSeconds) {
        return 'Exported file failed validation: duration ${durationSeconds.toStringAsFixed(2)}s is not close to expected ${expectedSeconds.toStringAsFixed(2)}s.';
      }
    }

    return null;
  }

  double? _parseProgress(String data, double durationSeconds) {
    final timeMatch = RegExp(r'time=(\d+):(\d+):(\d+\.\d+)').firstMatch(data);
    if (timeMatch == null || durationSeconds <= 0) return null;

    final hours = int.parse(timeMatch.group(1)!);
    final minutes = int.parse(timeMatch.group(2)!);
    final seconds = double.parse(timeMatch.group(3)!);
    final currentSeconds = hours * 3600 + minutes * 60 + seconds;
    return (currentSeconds / durationSeconds).clamp(0.0, 1.0);
  }

  String _stderrTail(List<String> stderrLines) {
    final tail = stderrLines
        .join('\n')
        .split('\n')
        .where((line) => line.trim().isNotEmpty)
        .toList();
    if (tail.isEmpty) return 'No ffmpeg stderr output captured.';
    return tail.skip(tail.length > 12 ? tail.length - 12 : 0).join('\n');
  }

  Future<void> _deleteIfExists(String filePath) async {
    try {
      await File(filePath).delete();
    } catch (_) {}
  }

  ({int strokeCount, int keyframes}) _countActiveOverlayFrameAnnotations(
    List<VideoOverlayFramePlan> framePlans,
  ) {
    var strokeCount = 0;
    var keyframes = 0;
    for (final frame in framePlans) {
      if (frame.strokes.isEmpty) continue;
      strokeCount += frame.strokes.length;
      keyframes += 1;
    }

    return (strokeCount: strokeCount, keyframes: keyframes);
  }

  Future<PreparedOverlayStream?> _prepareAnnotationOverlayStream({
    required AnnotationData? annotationData,
    required List<VideoOverlayFramePlan> framePlans,
    required _CropGeometry cropGeometry,
    required Directory tempDir,
  }) async {
    if (annotationData == null || annotationData.strokes.isEmpty) {
      return null;
    }

    if (framePlans.isEmpty) return null;

    final manifestPath = path.join(tempDir.path, 'overlay_concat.txt');
    final manifestLines = <String>[];
    String? lastFramePath;

    for (int i = 0; i < framePlans.length; i++) {
      if (_cancelRequested) break;
      final framePlan = framePlans[i];
      final overlayPath = path.join(
        tempDir.path,
        'overlay_${i.toString().padLeft(4, '0')}.png',
      );

      await _overlayRenderer.renderOverlayImage(
        outputPath: overlayPath,
        strokes: framePlan.strokes,
        width: cropGeometry.width,
        height: cropGeometry.height,
        viewportWidth: annotationData.viewportWidth,
        viewportHeight: annotationData.viewportHeight,
        sourceCropLeft: cropGeometry.normalizedLeft,
        sourceCropTop: cropGeometry.normalizedTop,
        sourceCropWidth: cropGeometry.normalizedWidth,
        sourceCropHeight: cropGeometry.normalizedHeight,
      );

      manifestLines
        ..add("file '${_escapeConcatPath(overlayPath)}'")
        ..add('duration ${(framePlan.durationMs / 1000.0).toStringAsFixed(6)}');
      lastFramePath = overlayPath;
    }

    if (_cancelRequested || lastFramePath == null) return null;

    // The concat demuxer needs the final file repeated so the previous
    // duration is honored.
    manifestLines.add("file '${_escapeConcatPath(lastFramePath)}'");
    await File(manifestPath).writeAsString('${manifestLines.join('\n')}\n');

    return PreparedOverlayStream(
      manifestPath: manifestPath,
      frameCount: framePlans.length,
      width: cropGeometry.width,
      height: cropGeometry.height,
    );
  }

  @visibleForTesting
  List<VideoOverlayFramePlan> planOverlayFrames({
    required AnnotationData? annotationData,
    required int startMs,
    required int endMs,
  }) {
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
    final frames = <VideoOverlayFramePlan>[];
    var cursorMs = startMs;

    for (int i = 0; i < keyframes.length; i++) {
      final keyframeMs = keyframes[i];
      final nextKeyframeMs = i + 1 < keyframes.length
          ? keyframes[i + 1]
          : endMs;

      final intervalStartMs = keyframeMs > startMs ? keyframeMs : startMs;
      final intervalEndMs = nextKeyframeMs < endMs ? nextKeyframeMs : endMs;
      if (intervalEndMs <= intervalStartMs) continue;

      if (intervalStartMs > cursorMs) {
        frames.add(
          VideoOverlayFramePlan(
            startMs: cursorMs,
            endMs: intervalStartMs,
            strokes: const [],
          ),
        );
      }

      frames.add(
        VideoOverlayFramePlan(
          startMs: intervalStartMs,
          endMs: intervalEndMs,
          strokes: List<Stroke>.unmodifiable(grouped[keyframeMs]!),
        ),
      );
      cursorMs = intervalEndMs;
    }

    return frames;
  }

  String _buildFilterComplex({
    required bool hasOverlayStream,
    required String cropFilter,
  }) {
    if (!hasOverlayStream) {
      return '[0:v]$cropFilter,setsar=1[vout]';
    }

    return '[0:v]$cropFilter,setsar=1[base];'
        '[1:v]format=rgba,setpts=PTS-STARTPTS[overlay];'
        '[base][overlay]overlay=0:0:format=auto[vout]';
  }

  _CropGeometry _buildCropGeometry({
    required VideoExportCropRect rect,
    required int videoWidth,
    required int videoHeight,
  }) {
    final safeLeft = rect.left.clamp(0.0, 1.0);
    final safeTop = rect.top.clamp(0.0, 1.0);
    final safeWidth = rect.width.clamp(0.01, 1.0);
    final safeHeight = rect.height.clamp(0.01, 1.0);

    String f(double v) => v.toStringAsFixed(6);

    final wExpr = 'max(2\\,floor(iw*${f(safeWidth)}/2)*2)';
    final hExpr = 'max(2\\,floor(ih*${f(safeHeight)}/2)*2)';
    final xExpr = 'min(max(0\\,floor(iw*${f(safeLeft)}))\\,iw-$wExpr)';
    final yExpr = 'min(max(0\\,floor(ih*${f(safeTop)}))\\,ih-$hExpr)';

    final width = _evenAtLeastTwo(videoWidth * safeWidth);
    final height = _evenAtLeastTwo(videoHeight * safeHeight);
    final x = (videoWidth * safeLeft).floor().clamp(0, videoWidth - width);
    final y = (videoHeight * safeTop).floor().clamp(0, videoHeight - height);

    return _CropGeometry(
      filter: 'crop=$wExpr:$hExpr:$xExpr:$yExpr',
      x: x,
      y: y,
      width: width,
      height: height,
      sourceWidth: videoWidth,
      sourceHeight: videoHeight,
    );
  }

  int _evenAtLeastTwo(double value) {
    final even = (value.floor() ~/ 2) * 2;
    return even < 2 ? 2 : even;
  }

  String _escapeConcatPath(String filePath) {
    return path
        .absolute(filePath)
        .replaceAll(r'\', '/')
        .replaceAll("'", r"'\''");
  }
}

@visibleForTesting
class VideoOverlayFramePlan {
  final int startMs;
  final int endMs;
  final List<Stroke> strokes;

  const VideoOverlayFramePlan({
    required this.startMs,
    required this.endMs,
    required this.strokes,
  });

  int get durationMs => endMs - startMs;
}

class PreparedOverlayStream {
  final String manifestPath;
  final int frameCount;
  final int width;
  final int height;

  const PreparedOverlayStream({
    required this.manifestPath,
    required this.frameCount,
    required this.width,
    required this.height,
  });
}

class _CropGeometry {
  final String filter;
  final int x;
  final int y;
  final int width;
  final int height;
  final int sourceWidth;
  final int sourceHeight;

  const _CropGeometry({
    required this.filter,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.sourceWidth,
    required this.sourceHeight,
  });

  double get normalizedLeft => sourceWidth > 0 ? x / sourceWidth : 0.0;
  double get normalizedTop => sourceHeight > 0 ? y / sourceHeight : 0.0;
  double get normalizedWidth => sourceWidth > 0 ? width / sourceWidth : 0.0;
  double get normalizedHeight => sourceHeight > 0 ? height / sourceHeight : 0.0;
}
