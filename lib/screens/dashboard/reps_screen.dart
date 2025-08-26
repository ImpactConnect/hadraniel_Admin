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
// Remove _syncData() call since the method doesn't exist and data is already loaded in _loadData()
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _navigateToRepForm(),
        tooltip: 'Add New Rep',
        icon: const Icon(Icons.person_add),
        label: const Text('Add Rep', style: TextStyle(color: Colors.white)),
        backgroundColor: colorScheme.primary,
        elevation: 4,
      ),
      child: Container(
        color: Colors.grey[50],
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton.icon(
                    icon: const Icon(Icons.sync),
                    label: const Text('Go to Sync Page'),
                    onPressed: () => Navigator.pushNamed(context, '/sync'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: Colors.white,
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
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
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Row(
                        children: [
                          _buildMetricCard(
                            'Total Reps',
                            totalReps.toString(),
                            Icons.people,
                            Colors.blue,
                            colorScheme,
                          ),
                          const SizedBox(width: 16),
                          _buildMetricCard(
                            'Admin Users',
                            totalAdmins.toString(),
                            Icons.admin_panel_settings,
                            Colors.purple,
                            colorScheme,
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: TextField(
                        decoration: InputDecoration(
                          labelText: 'Search Representatives',
                          hintText: 'Search by name, email or outlet',
                          prefixIcon: Icon(
                            Icons.search,
                            color: colorScheme.primary,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: colorScheme.primary,
                              width: 2,
                            ),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 16,
                            horizontal: 16,
                          ),
                        ),
                        onChanged: (value) =>
                            setState(() => _searchQuery = value),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: filteredReps.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.person_search,
                                      size: 64,
                                      color: Colors.grey[400],
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'No representatives found',
                                      style: TextStyle(
                                        fontSize: 18,
                                        color: Colors.grey[600],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    if (_searchQuery.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          top: 8.0,
                                        ),
                                        child: Text(
                                          'Try adjusting your search criteria',
                                          style: TextStyle(
                                            color: Colors.grey[500],
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              )
                            : Card(
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Center(
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: DataTable(
                                      headingRowColor:
                                          MaterialStateProperty.all(
                                        colorScheme.primary.withOpacity(
                                          0.05,
                                        ),
                                      ),
                                      dataRowMinHeight: 64,
                                      dataRowMaxHeight: 64,
                                      columns: [
                                        DataColumn(
                                          label: Text(
                                            'Name',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: colorScheme.primary,
                                            ),
                                          ),
                                        ),
                                        DataColumn(
                                          label: Text(
                                            'Outlet Assigned',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: colorScheme.primary,
                                            ),
                                          ),
                                        ),
                                        DataColumn(
                                          label: Text(
                                            'Date Created',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: colorScheme.primary,
                                            ),
                                          ),
                                        ),
                                        DataColumn(
                                          label: Text(
                                            'Actions',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: colorScheme.primary,
                                            ),
                                          ),
                                        ),
                                      ],
                                      rows: filteredReps.map((rep) {
                                        return DataRow(
                                          cells: [
                                            DataCell(
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Hero(
                                                    tag: 'rep-avatar-${rep.id}',
                                                    child: CircleAvatar(
                                                      radius: 16,
                                                      backgroundColor:
                                                          colorScheme.primary,
                                                      child: Text(
                                                        rep.fullName
                                                            .substring(0, 1)
                                                            .toUpperCase(),
                                                        style: const TextStyle(
                                                          color: Colors.white,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .center,
                                                    children: [
                                                      Text(
                                                        rep.fullName,
                                                        style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.w600,
                                                        ),
                                                      ),
                                                      Text(
                                                        rep.email,
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          color:
                                                              Colors.grey[600],
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                              onTap: () => _showRepDetails(rep),
                                            ),
                                            DataCell(
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 12,
                                                  vertical: 6,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: colorScheme.primary
                                                      .withOpacity(0.1),
                                                  borderRadius:
                                                      BorderRadius.circular(16),
                                                ),
                                                child: Text(
                                                  _getOutletName(rep.outletId),
                                                  style: TextStyle(
                                                    color: colorScheme.primary,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ),
                                              onTap: () => _showRepDetails(rep),
                                            ),
                                            DataCell(
                                              Text(
                                                rep.createdAt?.toString().split(
                                                          '.',
                                                        )[0] ??
                                                    'N/A',
                                              ),
                                              onTap: () => _showRepDetails(rep),
                                            ),
                                            DataCell(
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  IconButton(
                                                    icon: Icon(
                                                      Icons.visibility,
                                                      color:
                                                          colorScheme.primary,
                                                    ),
                                                    onPressed: () =>
                                                        _showRepDetails(rep),
                                                    tooltip: 'View Details',
                                                  ),
                                                  IconButton(
                                                    icon: Icon(
                                                      Icons.edit,
                                                      color: Colors.orange[700],
                                                    ),
                                                    onPressed: () =>
                                                        _navigateToRepForm(
                                                      rep: rep,
                                                    ),
                                                    tooltip: 'Edit Rep',
                                                  ),
                                                  IconButton(
                                                    icon: Icon(
                                                      Icons.delete,
                                                      color: Colors.red[700],
                                                    ),
                                                    onPressed: () =>
                                                        _deleteRep(rep),
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
                              ),
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

  Widget _buildMetricCard(
    String title,
    String value,
    IconData icon,
    MaterialColor color,
    ColorScheme colorScheme,
  ) {
    return Expanded(
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          padding: const EdgeInsets.all(20.0),
          decoration: BoxDecoration(
            color: color.shade50,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: color.shade100,
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: color.shade700,
                    ),
                  ),
                  Icon(icon, size: 28, color: color.shade400),
                ],
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: color.shade700,
                  ),
                ),
              ),
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
    // Navigate to the RepFormScreen instead of showing a dialog
    _navigateToRepForm();
  }
}
