import 'package:flutter/material.dart';
import '../../core/models/rep_model.dart';
import '../../core/services/rep_service.dart';
import '../../core/services/sync_service.dart';
import 'rep_form_screen.dart';
import 'sidebar.dart';

class RepsScreen extends StatefulWidget {
  const RepsScreen({super.key});

  @override
  State<RepsScreen> createState() => _RepsScreenState();
}

class _RepsScreenState extends State<RepsScreen> {
  final RepService _repService = RepService();
  final SyncService _syncService = SyncService();
  List<Rep> _reps = [];
  String _searchQuery = '';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadReps();
    _syncReps(); // Sync data when screen loads
  }

  Future<void> _loadReps() async {
    setState(() => _isLoading = true);
    try {
      final reps = await _repService.getAllReps();
      setState(() {
        _reps = reps;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading reps: $e')));
      }
      setState(() => _isLoading = false);
    }
  }

  Future<void> _syncReps() async {
    setState(() => _isLoading = true);
    try {
      await _syncService.syncRepsToLocalDb();
      await _loadReps();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reps synced successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error syncing reps: $e')));
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _navigateToRepForm({Rep? rep}) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => RepFormScreen(rep: rep)),
    );

    if (result == true) {
      _loadReps();
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
          _loadReps();
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
              (rep.outletId?.toLowerCase() ?? '').contains(
                _searchQuery.toLowerCase(),
              ),
        )
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sales Representatives'),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            onPressed: _isLoading ? null : _syncReps,
            tooltip: 'Sync Reps',
          ),
        ],
      ),
      drawer: Sidebar(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
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
                                    Text(rep.outletId ?? 'Not assigned'),
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
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddRepDialog,
        tooltip: 'Add New Rep',
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showRepDetails(Rep rep) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(rep.fullName),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Email: ${rep.email}'),
            const SizedBox(height: 8),
            Text('Outlet ID: ${rep.outletId ?? 'Not assigned'}'),
            const SizedBox(height: 8),
            Text(
              'Created: ${rep.createdAt?.toString().split('.')[0] ?? 'N/A'}',
            ),
            const SizedBox(height: 16),
            const Text(
              'Sales History:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const Text('Coming soon...'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
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
                            _loadReps();
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
