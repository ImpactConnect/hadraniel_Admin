import 'package:flutter/material.dart';
import '../../core/models/rep_model.dart';
import '../../core/models/outlet_model.dart';
import '../../core/services/sync_service.dart';

class RepProfileScreen extends StatefulWidget {
  final Rep rep;

  const RepProfileScreen({super.key, required this.rep});

  @override
  State<RepProfileScreen> createState() => _RepProfileScreenState();
}

class _RepProfileScreenState extends State<RepProfileScreen> {
  final SyncService _syncService = SyncService();
  Outlet? _outlet;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadOutlet();
  }

  Future<void> _loadOutlet() async {
    if (widget.rep.outletId != null) {
      final outlets = await _syncService.getAllLocalOutlets();
      final outlet = outlets.firstWhere(
        (o) => o.id == widget.rep.outletId,
        orElse: () => Outlet(
          id: 'unknown',
          name: 'Unknown Outlet',
          createdAt: DateTime.now(),
        ),
      );
      if (mounted) {
        setState(() {
          _outlet = outlet;
          _isLoading = false;
        });
      }
    } else {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.rep.fullName),
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              Navigator.pushNamed(context, '/rep-form', arguments: widget.rep);
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Container(
              color: Colors.grey[50],
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Profile Header with Avatar and Contact Information side by side
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Profile Header with Avatar - takes 60% of the width
                        Expanded(
                          flex: 6,
                          child: Card(
                            elevation: 4,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Container(
                              padding: const EdgeInsets.all(24.0),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    colorScheme.primary,
                                    colorScheme.primary.withOpacity(0.7),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Column(
                                children: [
                                  Hero(
                                    tag: 'rep-avatar-${widget.rep.id}',
                                    child: CircleAvatar(
                                      radius: 60,
                                      backgroundColor: Colors.white,
                                      child: Text(
                                        widget.rep.fullName.substring(0, 1).toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 48,
                                          color: colorScheme.primary,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  Text(
                                    widget.rep.fullName,
                                    style: const TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      widget.rep.isAdmin ? 'Admin' : 'Sales Rep',
                                      style: TextStyle(
                                        color: widget.rep.isAdmin
                                            ? Colors.purple
                                            : colorScheme.primary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        
                        const SizedBox(width: 16),
                        
                        // Contact Information Card - takes 40% of the width
                        Expanded(
                          flex: 4,
                          child: Card(
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.person_outline,
                                        color: colorScheme.primary,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          'Contact Information',
                                          style: theme.textTheme.titleLarge?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: colorScheme.primary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Divider(height: 32),
                                  _buildInfoRow(
                                    Icons.email_outlined,
                                    'Email',
                                    widget.rep.email,
                                    colorScheme,
                                  ),
                                  _buildInfoRow(
                                    Icons.store_outlined,
                                    'Assigned Outlet',
                                    _outlet?.name ?? 'Not Assigned',
                                    colorScheme,
                                  ),
                                  _buildInfoRow(
                                    Icons.location_on_outlined,
                                    'Outlet Location',
                                    _outlet?.location ?? 'N/A',
                                    colorScheme,
                                  ),
                                  _buildInfoRow(
                                    Icons.calendar_today_outlined,
                                    'Created',
                                    widget.rep.createdAt?.toString().split('.')[0] ??
                                        'N/A',
                                    colorScheme,
                                    isLast: true,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // Performance Metrics Card
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.analytics_outlined,
                                  color: colorScheme.primary,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Performance Metrics',
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: colorScheme.primary,
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 32),
                            Row(
                              children: [
                                _buildMetricCard(
                                  'Total Sales',
                                  '₦0',
                                  Icons.point_of_sale,
                                  Colors.green,
                                  colorScheme,
                                ),
                                const SizedBox(width: 16),
                                _buildMetricCard(
                                  'Products Sold',
                                  '0',
                                  Icons.inventory,
                                  Colors.blue,
                                  colorScheme,
                                ),
                                const SizedBox(width: 16),
                                _buildMetricCard(
                                  'Customers',
                                  '0',
                                  Icons.people,
                                  Colors.orange,
                                  colorScheme,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildInfoRow(
    IconData icon,
    String label,
    String value,
    ColorScheme colorScheme, {
    bool isLast = false,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 20.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: colorScheme.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
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
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
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
            Icon(icon, size: 36, color: color.shade700),
            const SizedBox(height: 16),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: color.shade700,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
