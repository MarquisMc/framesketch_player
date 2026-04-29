import 'package:flutter/foundation.dart';

class ExportMetricsService {
  final Stopwatch _totalStopwatch = Stopwatch();
  final Map<String, Duration> _timings = <String, Duration>{};
  final Map<String, Object?> _values = <String, Object?>{};

  Stopwatch startTiming() {
    if (!_totalStopwatch.isRunning) {
      _totalStopwatch.start();
    }
    return Stopwatch()..start();
  }

  void stopTiming(String name, Stopwatch stopwatch) {
    stopwatch.stop();
    _timings[name] = stopwatch.elapsed;
  }

  void setValue(String name, Object? value) {
    _values[name] = value;
  }

  void logSummary({String label = 'video export'}) {
    if (_totalStopwatch.isRunning) {
      _totalStopwatch.stop();
    }

    debugPrint('FrameSketch export metrics [$label]');
    for (final entry in _values.entries) {
      debugPrint('  ${entry.key}: ${entry.value}');
    }
    for (final entry in _timings.entries) {
      debugPrint('  ${entry.key}: ${_formatDuration(entry.value)}');
    }
    debugPrint('  total runtime: ${_formatDuration(_totalStopwatch.elapsed)}');
  }

  String _formatDuration(Duration duration) {
    if (duration.inMilliseconds < 1000) {
      return '${duration.inMilliseconds}ms';
    }

    final seconds = duration.inMilliseconds / 1000.0;
    return '${seconds.toStringAsFixed(2)}s';
  }
}
