import 'dart:async';
import 'dart:collection';
import 'dart:math';
import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';

/// Performance monitoring service for database operations and sync processes
class PerformanceMonitorService {
  static final PerformanceMonitorService _instance =
      PerformanceMonitorService._internal();
  factory PerformanceMonitorService() => _instance;
  PerformanceMonitorService._internal();

  // Performance metrics storage
  final Map<String, List<PerformanceMetric>> _metrics = {};
  final Map<String, OperationStats> _operationStats = {};

  // Configuration
  static const int MAX_METRICS_PER_OPERATION = 1000;
  static const Duration CLEANUP_INTERVAL = Duration(hours: 1);
  static const Duration METRIC_RETENTION = Duration(hours: 24);

  // Thresholds for alerts
  static const int SLOW_QUERY_THRESHOLD_MS = 1000;
  static const int VERY_SLOW_QUERY_THRESHOLD_MS = 5000;
  static const double HIGH_MEMORY_USAGE_MB = 100.0;

  // Cleanup timer
  Timer? _cleanupTimer;

  // Alert callbacks
  final List<Function(PerformanceAlert)> _alertCallbacks = [];

  /// Initialize performance monitoring
  void initialize() {
    _startCleanupTimer();
    print('Performance monitoring initialized');
  }

  /// Start monitoring a database operation
  PerformanceTracker startTracking(String operationName,
      {Map<String, dynamic>? metadata}) {
    return PerformanceTracker._(operationName, metadata ?? {}, this);
  }

  /// Record a completed operation
  void _recordMetric(PerformanceMetric metric) {
    // Store metric
    _metrics.putIfAbsent(metric.operationName, () => []).add(metric);

    // Update operation stats
    _updateOperationStats(metric);

    // Check for performance issues
    _checkForAlerts(metric);

    // Limit metrics per operation
    final operationMetrics = _metrics[metric.operationName]!;
    if (operationMetrics.length > MAX_METRICS_PER_OPERATION) {
      operationMetrics.removeAt(0); // Remove oldest
    }
  }

  /// Update operation statistics
  void _updateOperationStats(PerformanceMetric metric) {
    final stats = _operationStats.putIfAbsent(
      metric.operationName,
      () => OperationStats(metric.operationName),
    );

    stats.addMetric(metric);
  }

  /// Check for performance alerts
  void _checkForAlerts(PerformanceMetric metric) {
    final alerts = <PerformanceAlert>[];

    // Slow query alert
    if (metric.durationMs > VERY_SLOW_QUERY_THRESHOLD_MS) {
      alerts.add(PerformanceAlert(
        type: AlertType.verySlowQuery,
        operationName: metric.operationName,
        message: 'Very slow query detected: ${metric.durationMs}ms',
        metric: metric,
        severity: AlertSeverity.critical,
      ));
    } else if (metric.durationMs > SLOW_QUERY_THRESHOLD_MS) {
      alerts.add(PerformanceAlert(
        type: AlertType.slowQuery,
        operationName: metric.operationName,
        message: 'Slow query detected: ${metric.durationMs}ms',
        metric: metric,
        severity: AlertSeverity.warning,
      ));
    }

    // High memory usage alert
    if (metric.memoryUsageMb != null &&
        metric.memoryUsageMb! > HIGH_MEMORY_USAGE_MB) {
      alerts.add(PerformanceAlert(
        type: AlertType.highMemoryUsage,
        operationName: metric.operationName,
        message:
            'High memory usage: ${metric.memoryUsageMb!.toStringAsFixed(2)}MB',
        metric: metric,
        severity: AlertSeverity.warning,
      ));
    }

    // Error alert
    if (metric.error != null) {
      alerts.add(PerformanceAlert(
        type: AlertType.operationError,
        operationName: metric.operationName,
        message: 'Operation failed: ${metric.error}',
        metric: metric,
        severity: AlertSeverity.error,
      ));
    }

    // Notify alert callbacks
    for (var alert in alerts) {
      for (var callback in _alertCallbacks) {
        try {
          callback(alert);
        } catch (e) {
          print('Error in alert callback: $e');
        }
      }
    }
  }

  /// Add alert callback
  void addAlertCallback(Function(PerformanceAlert) callback) {
    _alertCallbacks.add(callback);
  }

  /// Remove alert callback
  void removeAlertCallback(Function(PerformanceAlert) callback) {
    _alertCallbacks.remove(callback);
  }

  /// Get performance summary for an operation
  OperationSummary? getOperationSummary(String operationName) {
    final stats = _operationStats[operationName];
    if (stats == null) return null;

    final metrics = _metrics[operationName] ?? [];
    if (metrics.isEmpty) return null;

    return OperationSummary(
      operationName: operationName,
      totalExecutions: stats.totalExecutions,
      averageDurationMs: stats.averageDurationMs,
      minDurationMs: stats.minDurationMs,
      maxDurationMs: stats.maxDurationMs,
      totalDurationMs: stats.totalDurationMs,
      successRate: stats.successRate,
      errorCount: stats.errorCount,
      lastExecuted: stats.lastExecuted,
      recentMetrics: metrics.take(10).toList(),
    );
  }

  /// Get overall performance report
  PerformanceReport getPerformanceReport() {
    final now = DateTime.now();
    final oneDayAgo = now.subtract(Duration(days: 1));
    final oneHourAgo = now.subtract(Duration(hours: 1));

    // Calculate overall stats
    int totalOperations = 0;
    int totalErrors = 0;
    int slowQueries = 0;
    int verySlowQueries = 0;
    double totalDurationMs = 0;

    final operationSummaries = <OperationSummary>[];

    for (var entry in _operationStats.entries) {
      final stats = entry.value;
      final summary = getOperationSummary(entry.key);

      if (summary != null) {
        operationSummaries.add(summary);
        totalOperations += stats.totalExecutions;
        totalErrors += stats.errorCount;
        totalDurationMs += stats.totalDurationMs;

        // Count slow queries
        final metrics = _metrics[entry.key] ?? [];
        for (var metric in metrics) {
          if (metric.timestamp.isAfter(oneDayAgo)) {
            if (metric.durationMs > VERY_SLOW_QUERY_THRESHOLD_MS) {
              verySlowQueries++;
            } else if (metric.durationMs > SLOW_QUERY_THRESHOLD_MS) {
              slowQueries++;
            }
          }
        }
      }
    }

    // Sort by average duration (slowest first)
    operationSummaries
        .sort((a, b) => b.averageDurationMs.compareTo(a.averageDurationMs));

    return PerformanceReport(
      generatedAt: now,
      totalOperations: totalOperations,
      totalErrors: totalErrors,
      overallSuccessRate: totalOperations > 0
          ? ((totalOperations - totalErrors) / totalOperations * 100)
          : 100,
      averageDurationMs:
          totalOperations > 0 ? totalDurationMs / totalOperations : 0,
      slowQueries: slowQueries,
      verySlowQueries: verySlowQueries,
      operationSummaries: operationSummaries,
      topSlowOperations: operationSummaries.take(10).toList(),
    );
  }

  /// Get real-time performance metrics
  Map<String, dynamic> getRealTimeMetrics() {
    final now = DateTime.now();
    final oneMinuteAgo = now.subtract(Duration(minutes: 1));
    final fiveMinutesAgo = now.subtract(Duration(minutes: 5));

    int operationsLastMinute = 0;
    int operationsLast5Minutes = 0;
    int errorsLastMinute = 0;
    double avgDurationLastMinute = 0;

    final recentDurations = <int>[];

    for (var metrics in _metrics.values) {
      for (var metric in metrics) {
        if (metric.timestamp.isAfter(fiveMinutesAgo)) {
          operationsLast5Minutes++;

          if (metric.timestamp.isAfter(oneMinuteAgo)) {
            operationsLastMinute++;
            recentDurations.add(metric.durationMs);

            if (metric.error != null) {
              errorsLastMinute++;
            }
          }
        }
      }
    }

    if (recentDurations.isNotEmpty) {
      avgDurationLastMinute =
          recentDurations.reduce((a, b) => a + b) / recentDurations.length;
    }

    return {
      'operations_per_minute': operationsLastMinute,
      'operations_per_5_minutes': operationsLast5Minutes,
      'errors_per_minute': errorsLastMinute,
      'avg_duration_ms_last_minute': avgDurationLastMinute.round(),
      'active_operations': _metrics.length,
      'total_metrics_stored':
          _metrics.values.fold<int>(0, (sum, list) => sum + list.length),
      'timestamp': now.toIso8601String(),
    };
  }

  /// Get database health metrics
  Future<Map<String, dynamic>> getDatabaseHealthMetrics() async {
    try {
      final db = await DatabaseHelper().database;

      // Get database size info
      final pageCount = await db.rawQuery('PRAGMA page_count');
      final pageSize = await db.rawQuery('PRAGMA page_size');
      final freePages = await db.rawQuery('PRAGMA freelist_count');

      final totalPages =
          pageCount.isNotEmpty ? pageCount.first['page_count'] as int : 0;
      final pageSizeBytes =
          pageSize.isNotEmpty ? pageSize.first['page_size'] as int : 0;
      final freePageCount =
          freePages.isNotEmpty ? freePages.first['freelist_count'] as int : 0;

      final totalSizeBytes = totalPages * pageSizeBytes;
      final freeSizeBytes = freePageCount * pageSizeBytes;
      final usedSizeBytes = totalSizeBytes - freeSizeBytes;

      // Get WAL info
      final walInfo = await db.rawQuery('PRAGMA wal_checkpoint');

      // Get table row counts
      final tables = await db.rawQuery('''
        SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'
      ''');

      final tableCounts = <String, int>{};
      for (var table in tables) {
        final tableName = table['name'] as String;
        try {
          final count =
              await db.rawQuery('SELECT COUNT(*) as count FROM $tableName');
          tableCounts[tableName] = count.first['count'] as int;
        } catch (e) {
          tableCounts[tableName] = -1; // Error getting count
        }
      }

      return {
        'database_size_mb': (totalSizeBytes / (1024 * 1024)).toStringAsFixed(2),
        'used_size_mb': (usedSizeBytes / (1024 * 1024)).toStringAsFixed(2),
        'free_size_mb': (freeSizeBytes / (1024 * 1024)).toStringAsFixed(2),
        'fragmentation_percent': totalPages > 0
            ? ((freePageCount / totalPages) * 100).toStringAsFixed(2)
            : '0',
        'total_pages': totalPages,
        'free_pages': freePageCount,
        'page_size_bytes': pageSizeBytes,
        'wal_info': walInfo,
        'table_counts': tableCounts,
        'total_records': tableCounts.values
            .where((count) => count > 0)
            .fold<int>(0, (sum, count) => sum + count),
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      return {
        'error': e.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }

  /// Export performance data for analysis
  Map<String, dynamic> exportPerformanceData() {
    final export = <String, dynamic>{
      'exported_at': DateTime.now().toIso8601String(),
      'operations': {},
    };

    for (var entry in _metrics.entries) {
      final operationName = entry.key;
      final metrics = entry.value;

      export['operations'][operationName] = {
        'metrics': metrics.map((m) => m.toJson()).toList(),
        'stats': _operationStats[operationName]?.toJson(),
      };
    }

    return export;
  }

  /// Clear all performance data
  void clearAllData() {
    _metrics.clear();
    _operationStats.clear();
    print('All performance data cleared');
  }

  /// Start cleanup timer
  void _startCleanupTimer() {
    _cleanupTimer?.cancel();
    _cleanupTimer = Timer.periodic(CLEANUP_INTERVAL, (_) {
      _cleanupOldMetrics();
    });
  }

  /// Clean up old metrics
  void _cleanupOldMetrics() {
    final cutoff = DateTime.now().subtract(METRIC_RETENTION);
    int removedCount = 0;

    for (var entry in _metrics.entries) {
      final metrics = entry.value;
      final initialCount = metrics.length;

      metrics.removeWhere((metric) => metric.timestamp.isBefore(cutoff));

      removedCount += initialCount - metrics.length;
    }

    // Remove empty operation entries
    _metrics.removeWhere((key, value) => value.isEmpty);
    _operationStats.removeWhere((key, value) => !_metrics.containsKey(key));

    if (removedCount > 0) {
      print('Cleaned up $removedCount old performance metrics');
    }
  }

  /// Dispose performance monitor
  void dispose() {
    _cleanupTimer?.cancel();
    _metrics.clear();
    _operationStats.clear();
    _alertCallbacks.clear();
    print('Performance monitor disposed');
  }
}

/// Performance tracker for individual operations
class PerformanceTracker {
  final String operationName;
  final Map<String, dynamic> metadata;
  final PerformanceMonitorService _monitor;
  final Stopwatch _stopwatch;
  final DateTime _startTime;

  PerformanceTracker._(
    this.operationName,
    this.metadata,
    this._monitor,
  )   : _stopwatch = Stopwatch()..start(),
        _startTime = DateTime.now();

  /// Finish tracking and record the metric
  void finish({
    String? error,
    Map<String, dynamic>? additionalMetadata,
    double? memoryUsageMb,
    int? recordsProcessed,
  }) {
    _stopwatch.stop();

    final metric = PerformanceMetric(
      operationName: operationName,
      durationMs: _stopwatch.elapsedMilliseconds,
      timestamp: _startTime,
      metadata: {...metadata, ...?additionalMetadata},
      error: error,
      memoryUsageMb: memoryUsageMb,
      recordsProcessed: recordsProcessed,
    );

    _monitor._recordMetric(metric);
  }
}

/// Performance metric data class
class PerformanceMetric {
  final String operationName;
  final int durationMs;
  final DateTime timestamp;
  final Map<String, dynamic> metadata;
  final String? error;
  final double? memoryUsageMb;
  final int? recordsProcessed;

  PerformanceMetric({
    required this.operationName,
    required this.durationMs,
    required this.timestamp,
    required this.metadata,
    this.error,
    this.memoryUsageMb,
    this.recordsProcessed,
  });

  Map<String, dynamic> toJson() => {
        'operation_name': operationName,
        'duration_ms': durationMs,
        'timestamp': timestamp.toIso8601String(),
        'metadata': metadata,
        'error': error,
        'memory_usage_mb': memoryUsageMb,
        'records_processed': recordsProcessed,
      };
}

/// Operation statistics
class OperationStats {
  final String operationName;
  int totalExecutions = 0;
  int errorCount = 0;
  int totalDurationMs = 0;
  int minDurationMs = 0;
  int maxDurationMs = 0;
  DateTime? lastExecuted;

  OperationStats(this.operationName);

  void addMetric(PerformanceMetric metric) {
    totalExecutions++;
    totalDurationMs += metric.durationMs;
    lastExecuted = metric.timestamp;

    if (metric.error != null) {
      errorCount++;
    }

    if (minDurationMs == 0 || metric.durationMs < minDurationMs) {
      minDurationMs = metric.durationMs;
    }

    if (metric.durationMs > maxDurationMs) {
      maxDurationMs = metric.durationMs;
    }
  }

  double get averageDurationMs =>
      totalExecutions > 0 ? totalDurationMs / totalExecutions : 0;
  double get successRate => totalExecutions > 0
      ? ((totalExecutions - errorCount) / totalExecutions * 100)
      : 100;

  Map<String, dynamic> toJson() => {
        'operation_name': operationName,
        'total_executions': totalExecutions,
        'error_count': errorCount,
        'success_rate': successRate,
        'average_duration_ms': averageDurationMs,
        'min_duration_ms': minDurationMs,
        'max_duration_ms': maxDurationMs,
        'total_duration_ms': totalDurationMs,
        'last_executed': lastExecuted?.toIso8601String(),
      };
}

/// Operation summary
class OperationSummary {
  final String operationName;
  final int totalExecutions;
  final double averageDurationMs;
  final int minDurationMs;
  final int maxDurationMs;
  final int totalDurationMs;
  final double successRate;
  final int errorCount;
  final DateTime? lastExecuted;
  final List<PerformanceMetric> recentMetrics;

  OperationSummary({
    required this.operationName,
    required this.totalExecutions,
    required this.averageDurationMs,
    required this.minDurationMs,
    required this.maxDurationMs,
    required this.totalDurationMs,
    required this.successRate,
    required this.errorCount,
    required this.lastExecuted,
    required this.recentMetrics,
  });
}

/// Performance report
class PerformanceReport {
  final DateTime generatedAt;
  final int totalOperations;
  final int totalErrors;
  final double overallSuccessRate;
  final double averageDurationMs;
  final int slowQueries;
  final int verySlowQueries;
  final List<OperationSummary> operationSummaries;
  final List<OperationSummary> topSlowOperations;

  PerformanceReport({
    required this.generatedAt,
    required this.totalOperations,
    required this.totalErrors,
    required this.overallSuccessRate,
    required this.averageDurationMs,
    required this.slowQueries,
    required this.verySlowQueries,
    required this.operationSummaries,
    required this.topSlowOperations,
  });
}

/// Performance alert
class PerformanceAlert {
  final AlertType type;
  final String operationName;
  final String message;
  final PerformanceMetric metric;
  final AlertSeverity severity;
  final DateTime timestamp;

  PerformanceAlert({
    required this.type,
    required this.operationName,
    required this.message,
    required this.metric,
    required this.severity,
  }) : timestamp = DateTime.now();
}

/// Alert types
enum AlertType {
  slowQuery,
  verySlowQuery,
  highMemoryUsage,
  operationError,
  highErrorRate,
}

/// Alert severity levels
enum AlertSeverity {
  info,
  warning,
  error,
  critical,
}
