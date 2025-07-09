import 'package:flutter/material.dart';
import '../../core/services/sync_service.dart';
import 'sidebar.dart';

class SyncScreen extends StatefulWidget {
  const SyncScreen({super.key});

  @override
  State<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends State<SyncScreen> {
  final SyncService _syncService = SyncService();
  bool _isSyncing = false;
  DateTime? _lastSyncTime;
  String? _syncError;

  Future<void> _syncAll() async {
    setState(() {
      _isSyncing = true;
      _syncError = null;
    });

    try {
      await _syncService.syncAll();
      setState(() {
        _lastSyncTime = DateTime.now();
      });
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

  Widget _buildSyncStatus(String title, DateTime? lastSync) {
    return ListTile(
      title: Text(title),
      subtitle: Text(
        lastSync != null
            ? 'Last synced: ${lastSync.toString()}'
            : 'Never synced',
      ),
      trailing: const Icon(Icons.check_circle, color: Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Data Synchronization')),
      drawer: Sidebar(),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Sync Status',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (_lastSyncTime != null)
                          Text(
                            'Last Full Sync: ${_lastSyncTime.toString()}',
                            style: const TextStyle(color: Colors.grey),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildSyncStatus('Profiles', _lastSyncTime),
                    _buildSyncStatus('Outlets', _lastSyncTime),
                    _buildSyncStatus('Products', _lastSyncTime),
                    _buildSyncStatus('Sales', _lastSyncTime),
                    _buildSyncStatus('Customers', _lastSyncTime),
                    _buildSyncStatus('Stock Balances', _lastSyncTime),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_syncError != null)
              Card(
                color: Colors.red[50],
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      const Icon(Icons.error, color: Colors.red),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Sync Error: $_syncError',
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isSyncing ? null : _syncAll,
        icon: _isSyncing
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Icon(Icons.sync),
        label: Text(_isSyncing ? 'Syncing...' : 'Sync All'),
      ),
    );
  }
}
