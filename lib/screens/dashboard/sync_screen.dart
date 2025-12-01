import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../core/services/sync_service.dart';
import '../../core/services/enhanced_sync_service.dart';
import '../../widgets/dashboard_layout.dart';

enum SyncStatus { pending, syncing, completed, failed }

class SyncOperation {
  final String tableName;
  final SyncStatus status;
  final int recordsCount;
  final DateTime timestamp;
  final Duration duration;
  final String? error;
  final Map<String, int>? detailedResults;
  final String sessionId;

  SyncOperation({
    required this.tableName,
    required this.status,
    required this.recordsCount,
    required this.timestamp,
    required this.duration,
    this.error,
    this.detailedResults,
    required this.sessionId,
  });

  Map<String, dynamic> toJson() {
    return {
      'tableName': tableName,
      'status': status.index,
      'recordsCount': recordsCount,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'duration': duration.inMilliseconds,
      'error': error,
      'detailedResults': detailedResults,
      'sessionId': sessionId,
    };
  }

  factory SyncOperation.fromJson(Map<String, dynamic> json) {
    return SyncOperation(
      tableName: json['tableName'],
      status: SyncStatus.values[json['status']],
      recordsCount: json['recordsCount'],
      timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp']),
      duration: Duration(milliseconds: json['duration']),
      error: json['error'],
      detailedResults: json['detailedResults'] != null
          ? Map<String, int>.from(json['detailedResults'])
          : null,
      sessionId: json['sessionId'],
    );
  }
}

class SyncScreen extends StatefulWidget {
  const SyncScreen({super.key});

  @override
  State<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends State<SyncScreen> with TickerProviderStateMixin {
  final SyncService _syncService = SyncService();
  final EnhancedSyncService _enhancedSyncService = EnhancedSyncService();
  bool _isSyncing = false;
  DateTime? _lastSyncTime;
  String? _syncError;
  List<SyncOperation> _syncHistory = [];
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  String _getDisplayName(String tableName) {
    switch (tableName) {
      case 'outlets':
        return 'Outlets';
      case 'reps':
        return 'Representatives';
      case 'products':
        return 'Products';
      case 'stock_balances':
        return 'Stock Balances';
      case 'expenditures':
        return 'Expenditures';
      case 'stock_counts':
        return 'Stock Counts';
      default:
        return tableName;
    }
  }

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
    _loadSyncHistory();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadSyncHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = prefs.getStringList('sync_history') ?? [];

      final loadedHistory = historyJson
          .map((jsonStr) => SyncOperation.fromJson(json.decode(jsonStr)))
          .toList();

      setState(() {
        _syncHistory = loadedHistory;
      });
    } catch (e) {
      print('Error loading sync history: $e');
      // Initialize with empty history if loading fails
      setState(() {
        _syncHistory = [];
      });
    }
  }

  Future<void> _saveSyncHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = _syncHistory
          .map((operation) => json.encode(operation.toJson()))
          .toList();

      // Keep only the last 50 sync operations to prevent storage bloat
      final limitedHistory = historyJson.take(50).toList();
      await prefs.setStringList('sync_history', limitedHistory);
    } catch (e) {
      print('Error saving sync history: $e');
    }
  }

  Future<void> _clearSyncHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Sync History'),
        content: const Text(
            'Are you sure you want to clear all sync history? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        _syncHistory.clear();
      });
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('sync_history');
    }
  }

  List<List<SyncOperation>> _groupSyncOperationsBySession() {
    final Map<String, List<SyncOperation>> sessionGroups = {};

    for (final operation in _syncHistory) {
      final sessionId = operation.sessionId;
      if (!sessionGroups.containsKey(sessionId)) {
        sessionGroups[sessionId] = [];
      }
      sessionGroups[sessionId]!.add(operation);
    }

    // Sort sessions by timestamp (newest first)
    final sortedSessions = sessionGroups.entries.toList()
      ..sort(
          (a, b) => b.value.first.timestamp.compareTo(a.value.first.timestamp));

    return sortedSessions.map((entry) => entry.value).toList();
  }

  Future<void> _syncAll() async {
    setState(() {
      _isSyncing = true;
      _syncError = null;
    });

    final syncStartTime = DateTime.now();
    final sessionId = DateTime.now().millisecondsSinceEpoch.toString();
    final List<String> tables = [
      'outlets',
      'reps',
      'products',
      'sales',
      'stock_balances',
      'stock_intake',
      'intake_balances',
      'expenditures',
      'stock_counts'
    ];

    try {
      // Initialize sync operations for all tables
      final operationStart = DateTime.now();
      for (String tableName in tables) {
        setState(() {
          _syncHistory.insert(
              0,
              SyncOperation(
                tableName: tableName,
                status: SyncStatus.syncing,
                recordsCount: 0,
                timestamp: operationStart,
                duration: Duration.zero,
                sessionId: sessionId,
              ));
        });
      }

      // Perform actual sync and get results
      final syncResults = await _syncService.syncAll();

      // Update sync history with actual results
      setState(() {
        for (String tableName in tables) {
          final index = _syncHistory.indexWhere((op) =>
              op.tableName == tableName && op.status == SyncStatus.syncing);
          if (index != -1) {
            final tableResults = syncResults[tableName];
            final recordsCount = tableResults?['synced'] ?? 0;

            _syncHistory[index] = SyncOperation(
              tableName: tableName,
              status: SyncStatus.completed,
              recordsCount: recordsCount,
              timestamp: operationStart,
              duration: DateTime.now().difference(operationStart),
              detailedResults: tableResults,
              sessionId: sessionId,
            );
          }
        }
        _lastSyncTime = DateTime.now();
      });

      // Save sync history to persistent storage
      await _saveSyncHistory();
    } catch (e) {
      setState(() {
        _syncError = e.toString();
        // Mark current syncing operations as failed
        for (int i = 0; i < _syncHistory.length; i++) {
          if (_syncHistory[i].status == SyncStatus.syncing) {
            _syncHistory[i] = SyncOperation(
              tableName: _syncHistory[i].tableName,
              status: SyncStatus.failed,
              recordsCount: 0,
              timestamp: _syncHistory[i].timestamp,
              duration: DateTime.now().difference(_syncHistory[i].timestamp),
              error: e.toString(),
              sessionId: sessionId,
            );
          }
        }
      });

      // Save sync history even on failure
      await _saveSyncHistory();
    } finally {
      setState(() {
        _isSyncing = false;
      });
    }
  }

  Future<void> _syncAllWithBackupDialog() async {
    if (_isSyncing) return;
    setState(() {
      _isSyncing = true;
      _syncError = null;
    });

    String statusText = 'Creating database backup...';
    bool isComplete = false;
    bool started = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            // Kick off the backup + sync flow exactly once
            if (!started) {
              started = true;
              () async {
                try {
                  await _enhancedSyncService
                      .createDatabaseBackupZipToDocuments();
                  setDialogState(() {
                    statusText = 'Sync operation started...';
                  });
                  await _syncAll();
                  setDialogState(() {
                    statusText = 'Sync complete';
                  });
                } catch (e) {
                  setState(() {
                    _syncError = e.toString();
                  });
                  setDialogState(() {
                    statusText = 'Sync failed';
                  });
                } finally {
                  isComplete = true;
                }
              }();
            }

            return AlertDialog(
              title: const Text('Sync Status'),
              content: Row(
                children: [
                  if (!(statusText == 'Sync complete' ||
                      statusText == 'Sync failed'))
                    const Padding(
                      padding: EdgeInsets.only(right: 12),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  Expanded(child: Text(statusText)),
                ],
              ),
              actions: [
                if (statusText == 'Sync complete' ||
                    statusText == 'Sync failed')
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('OK'),
                  ),
              ],
            );
          },
        );
      },
    );

    setState(() {
      _isSyncing = false;
    });
  }

  Future<void> _resetDatabase() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Database'),
        content: const Text(
          'This will delete all local data. The data will be re-synced from the server on next sync. Are you sure you want to continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        _isSyncing = true;
        _syncError = null;
      });

      try {
        await _syncService.resetDatabase();
        setState(() {
          _lastSyncTime = null;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Database reset successfully')),
          );
        }
      } catch (e) {
        setState(() {
          _syncError = e.toString();
        });
      } finally {
        setState(() {
          _isSyncing = false;
        });
      }
    }
  }

  Widget _buildSyncHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade600, Colors.blue.shade800],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Data Synchronization',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _lastSyncTime != null
                        ? 'Last sync: ${DateFormat('MMM dd, yyyy • HH:mm').format(_lastSyncTime!)}'
                        : 'Never synced',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: _isSyncing ? null : _syncAllWithBackupDialog,
                icon: _isSyncing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.blue),
                        ),
                      )
                    : const Icon(Icons.sync, size: 18),
                label: Text(_isSyncing ? 'Syncing...' : 'Sync Now'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.blue.shade700,
                  elevation: 0,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showSessionDetails(List<SyncOperation> sessionOperations) {
    final firstOperation = sessionOperations.first;
    final totalRecords =
        sessionOperations.fold<int>(0, (sum, op) => sum + op.recordsCount);
    final hasFailures =
        sessionOperations.any((op) => op.status == SyncStatus.failed);
    final allCompleted =
        sessionOperations.every((op) => op.status == SyncStatus.completed);
    final totalDuration = sessionOperations.fold<Duration>(
      Duration.zero,
      (sum, op) => sum + op.duration,
    );

    final statusText = hasFailures
        ? 'Failed'
        : allCompleted
            ? 'Completed'
            : 'In Progress';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sync Session Details'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDetailRow('Status', statusText),
                _buildDetailRow('Session ID', firstOperation.sessionId),
                _buildDetailRow(
                    'Timestamp',
                    DateFormat('MMM dd, yyyy HH:mm:ss')
                        .format(firstOperation.timestamp)),
                _buildDetailRow('Total Duration',
                    '${totalDuration.inSeconds}.${(totalDuration.inMilliseconds % 1000).toString().padLeft(3, '0')}s'),
                _buildDetailRow(
                    'Tables Synced', sessionOperations.length.toString()),
                _buildDetailRow('Total Records', totalRecords.toString()),
                const SizedBox(height: 16),
                const Text(
                  'Table Details:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...sessionOperations.map((operation) => Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: operation.status ==
                                            SyncStatus.completed
                                        ? Colors.green
                                        : operation.status == SyncStatus.failed
                                            ? Colors.red
                                            : Colors.orange,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _getDisplayName(operation.tableName),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${operation.recordsCount} records • ${operation.duration.inSeconds}.${(operation.duration.inMilliseconds % 1000).toString().padLeft(3, '0')}s',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                            if (operation.detailedResults != null &&
                                operation.detailedResults!.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              ...operation.detailedResults!.entries.map(
                                (entry) => Text(
                                  '${_getDetailLabel(entry.key)}: ${entry.value}',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ],
                            if (operation.error != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Error: ${operation.error}',
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    )),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showSyncDetails(SyncOperation operation) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(
                operation.status == SyncStatus.completed
                    ? Icons.check_circle
                    : operation.status == SyncStatus.failed
                        ? Icons.error
                        : Icons.sync,
                color: operation.status == SyncStatus.completed
                    ? Colors.green
                    : operation.status == SyncStatus.failed
                        ? Colors.red
                        : Colors.orange,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${_getDisplayName(operation.tableName)} Sync Details',
                  style: const TextStyle(fontSize: 18),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow('Status', _getStatusText(operation.status)),
                _buildDetailRow(
                    'Timestamp',
                    DateFormat('MMM dd, yyyy HH:mm:ss')
                        .format(operation.timestamp)),
                _buildDetailRow('Duration',
                    '${operation.duration.inSeconds}.${(operation.duration.inMilliseconds % 1000).toString().padLeft(3, '0')}s'),
                _buildDetailRow(
                    'Total Records', operation.recordsCount.toString()),
                if (operation.detailedResults != null)
                  ...operation.detailedResults!.entries
                      .map((entry) => _buildDetailRow(
                          _getDetailLabel(entry.key), entry.value.toString()))
                      .toList(),
                if (operation.error != null) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'Error Details:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Text(
                      operation.error!,
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  'Session ID: ${operation.sessionId}',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  String _getStatusText(SyncStatus status) {
    switch (status) {
      case SyncStatus.completed:
        return 'Completed Successfully';
      case SyncStatus.syncing:
        return 'In Progress';
      case SyncStatus.failed:
        return 'Failed';
      case SyncStatus.pending:
        return 'Pending';
    }
  }

  String _getDetailLabel(String key) {
    switch (key) {
      case 'synced':
        return 'Total Synced';
      case 'uploaded':
        return 'Uploaded';
      case 'downloaded':
        return 'Downloaded';
      default:
        return key
            .replaceAll('_', ' ')
            .split(' ')
            .map((word) => word.isNotEmpty
                ? word[0].toUpperCase() + word.substring(1)
                : '')
            .join(' ');
    }
  }

  Future<void> _clearTable(String tableName, String displayName,
      {String? warningMessage}) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Reset $displayName'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                'Are you sure you want to clear all local $displayName data? This action cannot be undone.'),
            if (warningMessage != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        color: Colors.orange.shade800, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        warningMessage,
                        style: TextStyle(
                            color: Colors.orange.shade900, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        _isSyncing = true;
      });

      try {
        switch (tableName) {
          case 'stock_intake':
            await _syncService.clearStockIntake();
            break;
          case 'intake_balances':
            await _syncService.clearIntakeBalances();
            break;
          case 'product_distributions':
            await _syncService.clearProductDistributions();
            break;
          case 'sales':
            await _syncService.clearSales();
            break;
          case 'stock_balances':
            await _syncService.clearStockBalances();
            break;
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$displayName cleared successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Error clearing $displayName: $e'),
                backgroundColor: Colors.red),
          );
        }
      } finally {
        setState(() {
          _isSyncing = false;
        });
      }
    }
  }

  Widget _buildDataManagementSection() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Data Management',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Clear local data for specific sections. This does not delete data from the cloud unless you sync empty data back.',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildResetButton(
                  'Stock Intake',
                  () => _clearTable('stock_intake', 'Stock Intake',
                      warningMessage:
                          'Clearing this without clearing Product Distributions may result in negative warehouse balances.'),
                ),
                _buildResetButton(
                  'Intake Balances',
                  () => _clearTable('intake_balances', 'Intake Balances'),
                ),
                _buildResetButton(
                  'Product Distributions',
                  () =>
                      _clearTable('product_distributions', 'Product Distributions'),
                ),
                _buildResetButton(
                  'Sales',
                  () => _clearTable('sales', 'Sales',
                      warningMessage:
                          'This will also clear all associated Sale Items.'),
                ),
                _buildResetButton(
                  'Stock Balances',
                  () => _clearTable('stock_balances', 'Stock Balances',
                      warningMessage:
                          'This will set the stock quantity at all outlets to ZERO.'),
                ),
              ],
            ),
            const Divider(height: 32),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isSyncing ? null : _resetDatabase,
                icon: const Icon(Icons.delete_forever),
                label: const Text('Reset Entire Database'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResetButton(String label, VoidCallback onPressed) {
    return OutlinedButton(
      onPressed: _isSyncing ? null : onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.red.shade700,
        side: BorderSide(color: Colors.red.shade200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      child: Text(label, style: const TextStyle(fontSize: 13)),
    );
  }

  Widget _buildSyncSessionCard(List<SyncOperation> sessionOperations) {
    final firstOperation = sessionOperations.first;
    final totalRecords =
        sessionOperations.fold<int>(0, (sum, op) => sum + op.recordsCount);
    final hasFailures =
        sessionOperations.any((op) => op.status == SyncStatus.failed);
    final allCompleted =
        sessionOperations.every((op) => op.status == SyncStatus.completed);

    final statusColor = hasFailures
        ? Colors.red
        : allCompleted
            ? Colors.green
            : Colors.orange;

    final statusText = hasFailures
        ? 'Failed'
        : allCompleted
            ? 'Completed'
            : 'In Progress';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _showSessionDetails(sessionOperations),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  hasFailures
                      ? Icons.error
                      : allCompleted
                          ? Icons.check_circle
                          : Icons.sync,
                  color: statusColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sync Session - $statusText',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${sessionOperations.length} tables, $totalRecords total records',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Tables: ${sessionOperations.map((op) => _getDisplayName(op.tableName)).join(', ')}',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    DateFormat('MMM dd, HH:mm')
                        .format(firstOperation.timestamp),
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: Colors.grey.shade400,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSyncOperationCard(SyncOperation operation) {
    Color statusColor;
    IconData statusIcon;

    switch (operation.status) {
      case SyncStatus.completed:
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case SyncStatus.syncing:
        statusColor = Colors.orange;
        statusIcon = Icons.sync;
        break;
      case SyncStatus.failed:
        statusColor = Colors.red;
        statusIcon = Icons.error;
        break;
      case SyncStatus.pending:
        statusColor = Colors.grey;
        statusIcon = Icons.schedule;
        break;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _showSyncDetails(operation),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  statusIcon,
                  color: statusColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getDisplayName(operation.tableName),
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      operation.status == SyncStatus.syncing
                          ? 'Syncing...'
                          : operation.status == SyncStatus.completed
                              ? '${operation.recordsCount} records synced'
                              : operation.status == SyncStatus.failed
                                  ? 'Sync failed'
                                  : 'Pending sync',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                      ),
                    ),
                    if (operation.error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          operation.error!,
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 12,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    DateFormat('HH:mm').format(operation.timestamp),
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                    ),
                  ),
                  if (operation.duration.inMilliseconds > 0)
                    Text(
                      '${operation.duration.inSeconds}s',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 11,
                      ),
                    ),
                  const SizedBox(height: 4),
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: Colors.grey.shade400,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Group operations by session
    final sessionOperations = _groupSyncOperationsBySession();

    return DashboardLayout(
      title: 'Sync',
      child: Column(
        children: [
          _buildSyncHeader(),
          if (_syncError != null)
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.red.shade700),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _syncError!,
                      style: TextStyle(color: Colors.red.shade900),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                _buildDataManagementSection(),
                if (sessionOperations.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.sync_disabled,
                            size: 64,
                            color: Colors.grey.shade300,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No sync history',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Tap "Sync Now" to synchronize data',
                            style: TextStyle(
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Sync History',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextButton(
                          onPressed: _clearSyncHistory,
                          child: const Text('Clear History'),
                        ),
                      ],
                    ),
                  ),
                  ...sessionOperations.map((session) => FadeTransition(
                        opacity: _fadeAnimation,
                        child: GestureDetector(
                          onTap: () => _showSessionDetails(session),
                          child: _buildSyncSessionCard(session),
                        ),
                      )),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
