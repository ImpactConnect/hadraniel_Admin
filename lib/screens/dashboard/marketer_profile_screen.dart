import 'package:flutter/material.dart';
import '../../core/models/outlet_model.dart';
import '../../core/models/marketer_model.dart';
import '../../core/models/marketer_target_model.dart';
import '../../core/services/marketer_service.dart';
import '../../core/services/sync_service.dart';
import '../../widgets/loading_overlay.dart';
import '../../widgets/marketer_form_dialog.dart';
import 'marketer_target_assignment_screen.dart';
import 'marketer_sales_tracking_screen.dart';
import '../../widgets/marketer_target_assignment_dialog.dart';

class MarketerProfileScreen extends StatefulWidget {
  final Marketer marketer;

  const MarketerProfileScreen({super.key, required this.marketer});

  @override
  State<MarketerProfileScreen> createState() => _MarketerProfileScreenState();
}

class _MarketerProfileScreenState extends State<MarketerProfileScreen> {
  final MarketerService _marketerService = MarketerService();
  final SyncService _syncService = SyncService();

  late Marketer _marketer;
  Outlet? _outlet;
  List<MarketerTarget> _targets = [];
  bool _isLoading = false;

  // Metrics
  int get totalTargets => _targets.length;
  int get activeTargets => _targets.where((t) => t.isActive).length;
  int get completedTargets => _targets.where((t) => t.isCompleted).length;
  double get totalTargetRevenue =>
      _targets.fold(0.0, (sum, t) => sum + (t.targetRevenue ?? 0.0));
  double get currentRevenue =>
      _targets.fold(0.0, (sum, t) => sum + t.currentRevenue);
  double get overallProgress => totalTargetRevenue > 0
      ? (currentRevenue / totalTargetRevenue) * 100
      : 0.0;

  @override
  void initState() {
    super.initState();
    _marketer = widget.marketer;
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      setState(() => _isLoading = true);

      // Load outlet information
      final outlets = await _syncService.getAllLocalOutlets();
      _outlet = outlets.firstWhere(
        (o) => o.id == _marketer.outletId,
        orElse: () =>
            Outlet(id: _marketer.outletId, name: 'Unknown', createdAt: null),
      );

      // Load marketer targets
      _targets = await _marketerService.getMarketerTargets(_marketer.id);

      setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _navigateToEdit() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => MarketerFormDialog(marketer: _marketer),
    );

    if (result == true) {
      // Reload marketer data
      try {
        final updatedMarketer =
            await _marketerService.getMarketerById(_marketer.id);
        if (updatedMarketer != null) {
          setState(() => _marketer = updatedMarketer);
        }
        _loadData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error refreshing data: $e')),
          );
        }
      }
    }
  }

  Future<void> _navigateToTargetAssignment() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => MarketerTargetAssignmentDialog(marketer: _marketer),
    );

    if (result == true) {
      _loadData();
    }
  }

  Future<void> _navigateToSalesTracking() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MarketerSalesTrackingScreen(marketer: _marketer),
      ),
    );
  }

  Widget _buildInfoCard() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: colorScheme.primary.withOpacity(0.1),
                child: Text(
                  _marketer.fullName.isNotEmpty
                      ? _marketer.fullName[0].toUpperCase()
                      : 'M',
                  style: TextStyle(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 32,
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _marketer.fullName,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _marketer.email,
                      style: TextStyle(
                        fontSize: 16,
                        color: colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                    if (_marketer.phone != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        _marketer.phone!,
                        style: TextStyle(
                          fontSize: 16,
                          color: colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _marketer.status == 'active'
                      ? Colors.green.withOpacity(0.1)
                      : Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  _marketer.status.toUpperCase(),
                  style: TextStyle(
                    color: _marketer.status == 'active'
                        ? Colors.green[700]
                        : Colors.orange[700],
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(
                Icons.business,
                color: colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Assigned Outlet: ',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
              Expanded(
                child: Text(
                  _outlet?.name ?? 'Unknown',
                  style: TextStyle(
                    color: colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                Icons.calendar_today,
                color: colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Joined: ',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
              Expanded(
                child: Text(
                  _marketer.createdAt != null
                      ? '${_marketer.createdAt!.day}/${_marketer.createdAt!.month}/${_marketer.createdAt!.year}'
                      : 'Unknown',
                  style: TextStyle(
                    color: colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

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
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressCard() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Overall Performance',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Progress',
                style: TextStyle(
                  color: colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
              Text(
                '${overallProgress.toStringAsFixed(1)}%',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: overallProgress / 100,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Current Revenue',
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                  Text(
                    '₦${currentRevenue.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Target Revenue',
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                  Text(
                    '₦${totalTargetRevenue.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
    required Color color,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                spreadRadius: 1,
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: Colors.grey[400],
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Marketer Profile'),
        backgroundColor: colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: _navigateToEdit,
            tooltip: 'Edit Marketer',
          ),
        ],
      ),
      body: LoadingOverlay(
        isLoading: _isLoading,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sidebar
            Container(
              width: 280,
              height: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 4,
                    offset: const Offset(2, 0),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Sidebar Header
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withOpacity(0.1),
                      border: Border(
                        bottom: BorderSide(
                          color: colorScheme.outline.withOpacity(0.2),
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: colorScheme.primary.withOpacity(0.2),
                          child: Text(
                            _marketer.fullName.isNotEmpty
                                ? _marketer.fullName[0].toUpperCase()
                                : 'M',
                            style: TextStyle(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _marketer.fullName,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                _marketer.email,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: colorScheme.onSurface.withOpacity(0.6),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Navigation Items
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      children: [
                        _buildSidebarItem(
                          icon: Icons.person,
                          title: 'Profile Overview',
                          isSelected: true,
                          onTap: () {},
                        ),
                        _buildSidebarItem(
                          icon: Icons.assignment,
                          title: 'Assign Targets',
                          onTap: _navigateToTargetAssignment,
                        ),
                        _buildSidebarItem(
                          icon: Icons.analytics,
                          title: 'Sales Tracking',
                          onTap: _navigateToSalesTracking,
                        ),
                        _buildSidebarItem(
                          icon: Icons.track_changes,
                          title: 'Performance',
                          onTap: () {
                            // TODO: Navigate to performance details
                          },
                        ),
                        _buildSidebarItem(
                          icon: Icons.history,
                          title: 'Activity History',
                          onTap: () {
                            // TODO: Navigate to activity history
                          },
                        ),
                        const Divider(height: 32),
                        _buildSidebarItem(
                          icon: Icons.edit,
                          title: 'Edit Profile',
                          onTap: _navigateToEdit,
                        ),
                        _buildSidebarItem(
                          icon: Icons.settings,
                          title: 'Settings',
                          onTap: () {
                            // TODO: Navigate to settings
                          },
                        ),
                      ],
                    ),
                  ),
                  // Sidebar Footer
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(
                          color: colorScheme.outline.withOpacity(0.2),
                        ),
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.circle,
                              size: 8,
                              color: _marketer.status == 'active'
                                  ? Colors.green
                                  : Colors.red,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _marketer.status?.toUpperCase() ?? 'UNKNOWN',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: _marketer.status == 'active'
                                    ? Colors.green
                                    : Colors.red,
                              ),
                            ),
                          ],
                        ),
                        if (_outlet != null) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.store,
                                size: 12,
                                color: colorScheme.onSurface.withOpacity(0.6),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _outlet!.name,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color:
                                        colorScheme.onSurface.withOpacity(0.6),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Main Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildInfoCard(),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        _buildMetricCard(
                          'Total Targets',
                          totalTargets.toString(),
                          Icons.track_changes,
                          Colors.blue,
                        ),
                        const SizedBox(width: 12),
                        _buildMetricCard(
                          'Active',
                          activeTargets.toString(),
                          Icons.play_circle,
                          Colors.green,
                        ),
                        const SizedBox(width: 12),
                        _buildMetricCard(
                          'Completed',
                          completedTargets.toString(),
                          Icons.check_circle,
                          Colors.orange,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _buildProgressCard(),
                    const SizedBox(height: 20),
                    Text(
                      'Quick Actions',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildActionButton(
                      title: 'Assign Products & Targets',
                      subtitle: 'Set product assignments and sales targets',
                      icon: Icons.assignment,
                      onTap: _navigateToTargetAssignment,
                      color: Colors.blue,
                    ),
                    _buildActionButton(
                      title: 'Sales Tracking',
                      subtitle: 'View detailed sales progress and analytics',
                      icon: Icons.analytics,
                      onTap: _navigateToSalesTracking,
                      color: Colors.green,
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

  Widget _buildSidebarItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isSelected = false,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? colorScheme.primary.withOpacity(0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: isSelected
                ? Border.all(color: colorScheme.primary.withOpacity(0.3))
                : null,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected
                    ? colorScheme.primary
                    : colorScheme.onSurface.withOpacity(0.7),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.normal,
                    color: isSelected
                        ? colorScheme.primary
                        : colorScheme.onSurface.withOpacity(0.8),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
