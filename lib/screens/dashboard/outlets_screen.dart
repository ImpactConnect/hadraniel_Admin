import 'package:flutter/material.dart';
import '../../core/models/outlet_model.dart';
import '../../core/services/sync_service.dart';
import 'sidebar.dart';
import 'outlet_profile_screen.dart';

class OutletsScreen extends StatefulWidget {
  const OutletsScreen({super.key});

  @override
  State<OutletsScreen> createState() => _OutletsScreenState();
}

class _OutletsScreenState extends State<OutletsScreen> {
  final SyncService _syncService = SyncService();
  List<Outlet> _outlets = [];
  String _searchQuery = '';
  bool _isLoading = false;

  // Metrics
  int get totalOutlets => _outlets.length;
  int get activeOutlets =>
      _outlets.length; // TODO: Add active status to outlets

  @override
  void initState() {
    super.initState();
    _loadOutlets();
  }

  Future<void> _loadOutlets() async {
    setState(() => _isLoading = true);
    try {
      final outlets = await _syncService.getAllLocalOutlets();
      setState(() {
        _outlets = outlets;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading outlets: $e')));
      }
      setState(() => _isLoading = false);
    }
  }

  Future<void> _syncOutlets() async {
    setState(() => _isLoading = true);
    try {
      await _syncService.syncOutletsToLocalDb();
      await _loadOutlets();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Outlets synced successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error syncing outlets: $e')));
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showOutletDialog({Outlet? outlet}) {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: outlet?.name ?? '');
    final locationController = TextEditingController(
      text: outlet?.location ?? '',
    );
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(outlet == null ? 'Add New Outlet' : 'Edit Outlet'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Outlet Name'),
                  validator: (value) =>
                      value?.isEmpty ?? true ? 'Required field' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: locationController,
                  decoration: const InputDecoration(labelText: 'Location'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      if (formKey.currentState?.validate() ?? false) {
                        setState(() => isLoading = true);
                        try {
                          final newOutlet = Outlet(
                            id: outlet?.id ?? DateTime.now().toIso8601String(),
                            name: nameController.text,
                            location: locationController.text,
                            createdAt: outlet?.createdAt ?? DateTime.now(),
                          );

                          await _syncService.syncOutletsToLocalDb([newOutlet]);
                          Navigator.pop(context);
                          _loadOutlets();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                outlet == null
                                    ? 'Outlet created successfully'
                                    : 'Outlet updated successfully',
                              ),
                            ),
                          );
                        } catch (e) {
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text('Error: $e')));
                          setState(() => isLoading = false);
                        }
                      }
                    },
              child: isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(outlet == null ? 'Create' : 'Update'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget _buildMetricCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(color: color.withOpacity(0.7), fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    color: color,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
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
    final filteredOutlets = _outlets
        .where(
          (outlet) =>
              outlet.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              (outlet.location?.toLowerCase() ?? '').contains(
                _searchQuery.toLowerCase(),
              ),
        )
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Outlets'),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            onPressed: _isLoading ? null : _syncOutlets,
            tooltip: 'Sync Outlets',
          ),
        ],
      ),
      drawer: Sidebar(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      _buildMetricCard(
                        'Total Outlets',
                        totalOutlets.toString(),
                        Icons.store,
                        Colors.blue,
                      ),
                      const SizedBox(width: 16),
                      _buildMetricCard(
                        'Active Outlets',
                        activeOutlets.toString(),
                        Icons.store,
                        Colors.green,
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: TextField(
                    decoration: const InputDecoration(
                      labelText: 'Search Outlets',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) => setState(() => _searchQuery = value),
                  ),
                ),
                Expanded(
                  child: filteredOutlets.isEmpty
                      ? const Center(
                          child: Text(
                            'No outlets found',
                            style: TextStyle(fontSize: 16),
                          ),
                        )
                      : SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            columns: const [
                              DataColumn(label: Text('Name')),
                              DataColumn(label: Text('Location')),
                              DataColumn(label: Text('Date Created')),
                              DataColumn(label: Text('Actions')),
                            ],
                            rows: filteredOutlets.map((outlet) {
                              return DataRow(
                                cells: [
                                  DataCell(
                                    Text(outlet.name),
                                    onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            OutletProfileScreen(outlet: outlet),
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Text(outlet.location ?? 'No location'),
                                  ),
                                  DataCell(
                                    Text(
                                      outlet.createdAt.toString().split('.')[0],
                                    ),
                                  ),
                                  DataCell(
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.edit),
                                          onPressed: () =>
                                              _showOutletDialog(outlet: outlet),
                                          tooltip: 'Edit Outlet',
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showOutletDialog(),
        tooltip: 'Add New Outlet',
        child: const Icon(Icons.add),
      ),
    );
  }
}
