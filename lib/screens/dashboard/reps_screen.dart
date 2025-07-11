import 'package:flutter/material.dart';
import '../../core/models/outlet_model.dart';
import '../../core/models/rep_model.dart';
import '../../core/services/rep_service.dart';
import '../../core/services/sync_service.dart';
import '../../widgets/loading_overlay.dart';
import '../../widgets/dashboard_layout.dart';
import 'rep_form_screen.dart';
import 'rep_profile_screen.dart';

class RepsScreen extends StatefulWidget {
  const RepsScreen({super.key});

  @override
  State<RepsScreen> createState() => _RepsScreenState();
}

class _RepsScreenState extends State<RepsScreen> {
  final RepService _repService = RepService();
  final SyncService _syncService = SyncService();
  List<Rep> _reps = [];
  List<Rep> _filteredReps = [];
  List<Outlet> _outlets = [];
  String _searchQuery = '';
  bool _isLoading = false;
  bool _isSyncing = false;

  // Metrics
  int get totalReps => _reps.where((rep) => !rep.isAdmin).length;
  int get totalAdmins => _reps.where((rep) => rep.isAdmin).length;

  String _getOutletName(String? outletId) {
    if (outletId == null) return 'Not assigned';
    final outlet = _outlets.firstWhere(
      (o) => o.id == outletId,
      orElse: () => Outlet(id: outletId, name: 'Unknown', createdAt: null),
    );
    return outlet.name;
  }

  @override
  void initState() {
    super.initState();
    _loadData();
    _syncData();
  }

  Future<void> _loadData() async {
    try {
      setState(() => _isLoading = true);
      final reps = await _repService.getAllReps();
      final outlets = await _syncService.getAllLocalOutlets();
      setState(() {
        _reps = reps;
        _filteredReps = reps;
        _outlets = outlets;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading data: $e')));
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _syncData() async {
    try {
      setState(() => _isSyncing = true);
      await _syncService.syncRepsToLocalDb();
      await _syncService.syncOutletsToLocalDb();
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Data synced successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error syncing data: $e')));
      }
    } finally {
      setState(() => _isSyncing = false);
    }
  }

  Future<void> _navigateToRepForm({Rep? rep}) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => RepFormScreen(rep: rep)),
    );

    if (result == true) {
      _loadData();
    }
  }

  Future<void> _deleteRep(Rep rep) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: Text('Are you sure you want to delete ${rep.fullName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);
      try {
        final success = await _repService.deleteRep(rep.id);
        if (success) {
          _loadData();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Rep deleted successfully')),
            );
          }
        } else {
          throw Exception('Failed to delete rep');
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error deleting rep: $e')));
        }
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredReps = _reps
        .where(
          (rep) =>
              rep.fullName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              rep.email.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              _getOutletName(
                rep.outletId,
              ).toLowerCase().contains(_searchQuery.toLowerCase()),
        )
        .toList();

    return DashboardLayout(
      title: 'Sales Representatives',
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: const Icon(Icons.sync),
                  onPressed: _isLoading ? null : _syncData,
                  tooltip: 'Sync Data',
                ),
              ],
            ),
          ),
          Expanded(
            child: LoadingOverlay(
              isLoading: _isLoading,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  _buildMetricCard(
                    'Total Reps',
                    totalReps.toString(),
                    Icons.people,
                  ),
                  const SizedBox(width: 16),
                  _buildMetricCard(
                    'Admin Users',
                    totalAdmins.toString(),
                    Icons.admin_panel_settings,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                decoration: const InputDecoration(
                  labelText: 'Search Reps',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) => setState(() => _searchQuery = value),
              ),
            ),
            Expanded(
              child: filteredReps.isEmpty
                  ? const Center(
                      child: Text(
                        'No representatives found',
                        style: TextStyle(fontSize: 16),
                      ),
                    )
                  : SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columns: const [
                          DataColumn(label: Text('Name')),
                          DataColumn(label: Text('Outlet Assigned')),
                          DataColumn(label: Text('Date Created')),
                          DataColumn(label: Text('Actions')),
                        ],
                        rows: filteredReps.map((rep) {
                          return DataRow(
                            cells: [
                              DataCell(
                                Text(rep.fullName),
                                onTap: () => _showRepDetails(rep),
                              ),
                              DataCell(
                                Text(_getOutletName(rep.outletId)),
                                onTap: () => _showRepDetails(rep),
                              ),
                              DataCell(
                                Text(
                                  rep.createdAt?.toString().split('.')[0] ??
                                      'N/A',
                                ),
                                onTap: () => _showRepDetails(rep),
                              ),
                              DataCell(
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit),
                                      onPressed: () =>
                                          _navigateToRepForm(rep: rep),
                                      tooltip: 'Edit Rep',
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete),
                                      onPressed: () => _deleteRep(rep),
                                      tooltip: 'Delete Rep',
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
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddRepDialog,
        tooltip: 'Add New Rep',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon) {
    return Expanded(
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Icon(icon, size: 32, color: Theme.of(context).primaryColor),
              const SizedBox(height: 8),
              Text(
                value,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: Theme.of(context).primaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(title, style: TextStyle(color: Colors.grey[600])),
            ],
          ),
        ),
      ),
    );
  }

  void _showRepDetails(Rep rep) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => RepProfileScreen(rep: rep)),
    );
  }

  Future<void> _showAddRepDialog() async {
    final _formKey = GlobalKey<FormState>();
    final _fullNameController = TextEditingController();
    final _emailController = TextEditingController();
    final _passwordController = TextEditingController();
    String? _selectedOutletId;
    final _outlets = await _syncService.getAllLocalOutlets();
    bool _isLoading = false;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add New Rep'),
          content: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: _fullNameController,
                    decoration: const InputDecoration(labelText: 'Full Name'),
                    validator: (value) =>
                        value?.isEmpty ?? true ? 'Required field' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(labelText: 'Email'),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) =>
                        value?.isEmpty ?? true ? 'Required field' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    decoration: const InputDecoration(labelText: 'Password'),
                    obscureText: true,
                    validator: (value) =>
                        value?.isEmpty ?? true ? 'Required field' : null,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _selectedOutletId,
                    decoration: const InputDecoration(labelText: 'Outlet'),
                    items: _outlets.map((outlet) {
                      return DropdownMenuItem(
                        value: outlet.id,
                        child: Text(outlet.name),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedOutletId = value;
                      });
                    },
                    validator: (value) =>
                        value == null ? 'Please select an outlet' : null,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: _isLoading
                  ? null
                  : () async {
                      if (_formKey.currentState!.validate()) {
                        setState(() => _isLoading = true);
                        try {
                          final rep = await _repService.createRep(
                            fullName: _fullNameController.text,
                            email: _emailController.text,
                            password: _passwordController.text,
                            outletId: _selectedOutletId,
                          );

                          if (rep != null) {
                            Navigator.pop(context, true);
                            _loadData();
                          } else {
                            throw Exception('Failed to create rep');
                          }
                        } catch (e) {
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text('Error: $e')));
                          setState(() => _isLoading = false);
                        }
                      }
                    },
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }
}
