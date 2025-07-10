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
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Column(
                      children: [
                        Hero(
                          tag: 'rep-avatar-${widget.rep.id}',
                          child: CircleAvatar(
                            radius: 50,
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.primary,
                            child: Text(
                              widget.rep.fullName.substring(0, 1).toUpperCase(),
                              style: const TextStyle(
                                fontSize: 36,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          widget.rep.fullName,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: widget.rep.isAdmin
                                ? Colors.purple.withOpacity(0.1)
                                : Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            widget.rep.isAdmin ? 'Admin' : 'Sales Rep',
                            style: TextStyle(
                              color: widget.rep.isAdmin
                                  ? Colors.purple
                                  : Colors.blue,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.person_outline),
                              const SizedBox(width: 8),
                              Text(
                                'Contact Information',
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          _buildInfoRow(
                            Icons.email_outlined,
                            'Email',
                            widget.rep.email,
                          ),
                          _buildInfoRow(
                            Icons.store_outlined,
                            'Assigned Outlet',
                            _outlet?.name ?? 'Not Assigned',
                          ),
                          _buildInfoRow(
                            Icons.location_on_outlined,
                            'Outlet Location',
                            _outlet?.location ?? 'N/A',
                          ),
                          _buildInfoRow(
                            Icons.calendar_today_outlined,
                            'Created',
                            widget.rep.createdAt?.toString().split('.')[0] ??
                                'N/A',
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.analytics_outlined),
                              const SizedBox(width: 8),
                              Text(
                                'Performance Metrics',
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              _buildMetricCard(
                                'Total Sales',
                                '₦0',
                                Icons.point_of_sale,
                                Colors.green,
                              ),
                              const SizedBox(width: 16),
                              _buildMetricCard(
                                'Products Sold',
                                '0',
                                Icons.inventory,
                                Colors.blue,
                              ),
                              const SizedBox(width: 16),
                              _buildMetricCard(
                                'Customers',
                                '0',
                                Icons.people,
                                Colors.orange,
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
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: Theme.of(context).colorScheme.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
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
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.shade100),
        ),
        child: Column(
          children: [
            Icon(icon, size: 32, color: color.shade700),
            const SizedBox(height: 12),
            Text(
              title,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: color.shade700,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: color.shade700,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
