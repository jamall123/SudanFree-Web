import 'package:flutter/foundation.dart';

/// Performance monitoring service for tracking custom traces and network metrics.
///
/// Uses Stopwatch-based timing for now. When firebase_performance is added
/// to pubspec.yaml, this can be upgraded to full Firebase Performance traces
/// with zero API changes for callers.
///
/// Usage:
/// ```dart
/// final trace = PerformanceService().startTrace('load_freelancers');
/// await doSomething();
/// trace.stop();
/// ```
class PerformanceService {
  static final PerformanceService _instance = PerformanceService._internal();
  factory PerformanceService() => _instance;
  PerformanceService._internal();

  /// Start a custom performance trace
  AppTrace startTrace(String name) {
    final trace = AppTrace._(name);
    trace._start();
    return trace;
  }

  /// Measure and log the duration of an async operation
  Future<T> measureAsync<T>(String name, Future<T> Function() operation) async {
    final trace = startTrace(name);
    try {
      final result = await operation();
      trace.putAttribute('status', 'success');
      return result;
    } catch (e) {
      trace.putAttribute('status', 'error');
      trace.putAttribute('error',
          e.toString().substring(0, 100.clamp(0, e.toString().length)));
      rethrow;
    } finally {
      trace.stop();
    }
  }
}

/// A lightweight performance trace that logs timing data.
class AppTrace {
  final String name;
  final Stopwatch _stopwatch = Stopwatch();
  final Map<String, String> _attributes = {};
  final Map<String, int> _metrics = {};

  AppTrace._(this.name);

  void _start() {
    _stopwatch.start();
    debugPrint('⏱️ [Perf] Trace "$name" started');
  }

  /// Add a string attribute to this trace
  void putAttribute(String key, String value) {
    _attributes[key] = value;
  }

  /// Add a numeric metric to this trace
  void incrementMetric(String name, int value) {
    _metrics[name] = (_metrics[name] ?? 0) + value;
  }

  /// Stop the trace and log the results
  void stop() {
    _stopwatch.stop();
    final durationMs = _stopwatch.elapsedMilliseconds;

    // Log performance data
    final buffer =
        StringBuffer('⏱️ [Perf] "$name" completed in ${durationMs}ms');
    if (_attributes.isNotEmpty) {
      buffer.write(' | attrs: $_attributes');
    }
    if (_metrics.isNotEmpty) {
      buffer.write(' | metrics: $_metrics');
    }

    // Warn if operation took too long
    if (durationMs > 3000) {
      debugPrint('⚠️ [Perf] SLOW: $buffer');
    } else {
      debugPrint(buffer.toString());
    }
  }
}
