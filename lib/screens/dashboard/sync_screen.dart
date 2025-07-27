import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/services/sync_service.dart';
import '../../widgets/dashboard_layout.dart';

enum SyncStatus { pending, syncing, completed, failed }

class SyncOperation {
  final String tableName;
  final SyncStatus status;
  final int recordsCount;
  final DateTime timestamp;
  final Duration duration;
  final String? error;

  SyncOperation({
    required this.tableName,
    required this.status,
    required this.recordsCount,
    required this.timestamp,
    required this.duration,
    this.error,
  });
}

class SyncScreen extends StatefulWidget {
  const SyncScreen({super.key});

  @override
  State<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends State<SyncScreen> with TickerProviderStateMixin {
  final SyncService _syncService = SyncService();
  bool _isSyncing = false;
  DateTime? _lastSyncTime;
  String? _syncError;
  List<SyncOperation> _syncHistory = [];
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

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

  void _loadSyncHistory() {
    // Load sync history from local storage or initialize with sample data
    setState(() {
      _syncHistory = [
        SyncOperation(
          tableName: 'Profiles',
          status: SyncStatus.completed,
          recordsCount: 15,
          timestamp: DateTime.now().subtract(const Duration(hours: 2)),
          duration: const Duration(seconds: 3),
        ),
        SyncOperation(
          tableName: 'Outlets',
          status: SyncStatus.completed,
          recordsCount: 8,
          timestamp: DateTime.now().subtract(const Duration(hours: 2)),
          duration: const Duration(seconds: 2),
        ),
      ];
    });
  }

  Future<void> _syncAll() async {
    setState(() {
      _isSyncing = true;
      _syncError = null;
    });

    final syncStartTime = DateTime.now();
    final List<String> tables = [
      'Profiles',
      'Outlets',
      'Products',
      'Sales',
      'Customers',
      'Stock Balances',
      'Expenditures'
    ];

    try {
      for (String tableName in tables) {
        final operationStart = DateTime.now();

        // Add pending operation
        setState(() {
          _syncHistory.insert(
              0,
              SyncOperation(
                tableName: tableName,
                status: SyncStatus.syncing,
                recordsCount: 0,
                timestamp: operationStart,
                duration: Duration.zero,
              ));
        });

        // Simulate sync operation (replace with actual sync logic)
        await Future.delayed(
            Duration(milliseconds: 500 + (tableName.length * 100)));
        final recordsCount =
            10 + (tableName.length % 20); // Simulate records count

        // Update operation as completed
        setState(() {
          final index = _syncHistory.indexWhere((op) =>
              op.tableName == tableName && op.status == SyncStatus.syncing);
          if (index != -1) {
            _syncHistory[index] = SyncOperation(
              tableName: tableName,
              status: SyncStatus.completed,
              recordsCount: recordsCount,
              timestamp: operationStart,
              duration: DateTime.now().difference(operationStart),
            );
          }
        });
      }

      await _syncService.syncAll();
      setState(() {
        _lastSyncTime = DateTime.now();
      });
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
            );
          }
        }
      });
    } finally {
      setState(() {
        _isSyncing = false;
      });
    }
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
                onPressed: _isSyncing ? null : _syncAll,
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
                    operation.tableName,
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
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DashboardLayout(
      title: 'Sync Center',
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Column(
          children: [
            _buildSyncHeader(),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_syncError != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline,
                                color: Colors.red.shade600),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Sync Error',
                                    style: TextStyle(
                                      color: Colors.red.shade800,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _syncError!,
                                    style: TextStyle(
                                      color: Colors.red.shade700,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Recent Sync Operations',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _isSyncing ? null : _resetDatabase,
                          icon: const Icon(Icons.restore, size: 18),
                          label: const Text('Reset DB'),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.red.shade600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: _syncHistory.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.sync_disabled,
                                    size: 64,
                                    color: Colors.grey.shade400,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No sync operations yet',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Tap "Sync Now" to start synchronizing data',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              itemCount: _syncHistory.length,
                              itemBuilder: (context, index) {
                                return _buildSyncOperationCard(
                                    _syncHistory[index]);
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
