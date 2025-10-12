import 'package:flutter/material.dart';
import '../../core/models/marketer_model.dart';
import '../../core/models/marketer_target_model.dart';
import '../../core/models/sale_model.dart';
import '../../core/models/sale_item_model.dart';
import '../../core/models/product_model.dart';
import '../../core/services/marketer_service.dart';
import '../../core/services/sync_service.dart';
import '../../widgets/loading_overlay.dart';

class MarketerSalesTrackingScreen extends StatefulWidget {
  final Marketer marketer;

  const MarketerSalesTrackingScreen({super.key, required this.marketer});

  @override
  State<MarketerSalesTrackingScreen> createState() =>
      _MarketerSalesTrackingScreenState();
}

class _MarketerSalesTrackingScreenState
    extends State<MarketerSalesTrackingScreen> {
  final MarketerService _marketerService = MarketerService();
  final SyncService _syncService = SyncService();

  List<MarketerTarget> _targets = [];
  List<Product> _products = [];
  List<Sale> _recentSales = [];
  Map<String, List<SaleItem>> _saleItemsMap = {};
  bool _isLoading = false;
  String _selectedPeriod = 'all';

  // Metrics
  double get totalRevenue =>
      _targets.fold(0.0, (sum, t) => sum + t.currentRevenue);
  int get totalQuantitySold =>
      _targets.fold(0, (sum, t) => sum + t.currentQuantity.toInt());
  double get averageProgress => _targets.isEmpty
      ? 0.0
      : _targets.fold(0.0, (sum, t) => sum + t.progressPercentage) /
          _targets.length;
  int get targetsOnTrack =>
      _targets.where((t) => t.progressPercentage >= 75.0).length;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      setState(() => _isLoading = true);

      // Load marketer targets
      _targets = await _marketerService.getMarketerTargets(widget.marketer.id);

      // Load products
      final products = await _syncService.getAllLocalProducts();
      _products = products
          .where((p) => p.outletId == widget.marketer.outletId)
          .toList();

      // Load recent sales and their items
      final sales = await _syncService.getAllLocalSales();
      final allSaleItems = <SaleItem>[];

      // Get all sale items for all sales
      for (final sale in sales) {
        final saleItems = await _syncService.getSaleItems(sale.id);
        allSaleItems.addAll(saleItems);
      }

      // Group sale items by sale ID
      _saleItemsMap = {};
      for (final item in allSaleItems) {
        if (!_saleItemsMap.containsKey(item.saleId)) {
          _saleItemsMap[item.saleId] = [];
        }
        _saleItemsMap[item.saleId]!.add(item);
      }

      // Filter sales that contain products assigned to this marketer
      _recentSales = sales.where((sale) {
        final saleItems = _saleItemsMap[sale.id] ?? [];
        return _targets.any((target) =>
            saleItems.any((item) => item.productId == target.productId));
      }).toList();

      // Sort by date (most recent first)
      _recentSales.sort((a, b) => b.createdAt!.compareTo(a.createdAt!));

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

  String _getProductName(String productId) {
    final product = _products.firstWhere(
      (p) => p.id == productId,
      orElse: () => Product(
        id: productId,
        productName: 'Unknown Product',
        quantity: 0.0,
        unit: 'unit',
        costPerUnit: 0.0,
        totalCost: 0.0,
        dateAdded: DateTime.now(),
        outletId: widget.marketer.outletId,
        createdAt: DateTime.now(),
      ),
    );
    return product.productName;
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
                fontSize: 18,
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

  Widget _buildOverallProgress() {
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
                'Average Progress',
                style: TextStyle(
                  color: colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
              Text(
                '${averageProgress.toStringAsFixed(1)}%',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: averageProgress / 100,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Revenue',
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                    Text(
                      '₦${totalRevenue.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'Units Sold',
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                    Text(
                      totalQuantitySold.toString(),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'On Track',
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                    Text(
                      '$targetsOnTrack/${_targets.length}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTargetsList() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_targets.isEmpty) {
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
          children: [
            Icon(
              Icons.track_changes,
              size: 48,
              color: colorScheme.onSurface.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No targets assigned',
              style: TextStyle(
                fontSize: 16,
                color: colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Assign targets to start tracking sales progress',
              style: TextStyle(
                color: colorScheme.onSurface.withOpacity(0.4),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

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
            'Target Progress',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _targets.length,
            separatorBuilder: (context, index) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final target = _targets[index];
              final productName = _getProductName(target.productId);
              final isOnTrack = target.progressPercentage >= 75.0;
              final isCompleted = target.isCompleted;

              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isCompleted
                        ? Colors.green[200]!
                        : isOnTrack
                            ? Colors.blue[200]!
                            : Colors.orange[200]!,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            productName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: isCompleted
                                ? Colors.green.withOpacity(0.1)
                                : isOnTrack
                                    ? Colors.blue.withOpacity(0.1)
                                    : Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            isCompleted
                                ? 'COMPLETED'
                                : isOnTrack
                                    ? 'ON TRACK'
                                    : 'BEHIND',
                            style: TextStyle(
                              color: isCompleted
                                  ? Colors.green[700]
                                  : isOnTrack
                                      ? Colors.blue[700]
                                      : Colors.orange[700],
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Target',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: colorScheme.onSurface.withOpacity(0.6),
                                ),
                              ),
                              Text(
                                target.targetType == 'quantity'
                                    ? '${target.targetQuantity ?? 0} units'
                                    : '₦${(target.targetRevenue ?? 0.0).toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Current',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: colorScheme.onSurface.withOpacity(0.6),
                                ),
                              ),
                              Text(
                                target.targetType == 'quantity'
                                    ? '${target.currentQuantity} units'
                                    : '₦${target.currentRevenue.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'Progress',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: colorScheme.onSurface.withOpacity(0.6),
                                ),
                              ),
                              Text(
                                '${target.progressPercentage.toStringAsFixed(1)}%',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isCompleted
                                      ? Colors.green[700]
                                      : isOnTrack
                                          ? Colors.blue[700]
                                          : Colors.orange[700],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: target.progressPercentage / 100,
                      backgroundColor: Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isCompleted
                            ? Colors.green
                            : isOnTrack
                                ? Colors.blue
                                : Colors.orange,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Period: ${target.startDate.day}/${target.startDate.month} - ${target.endDate.day}/${target.endDate.month}',
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                        Text(
                          target.isActive ? 'Active' : 'Inactive',
                          style: TextStyle(
                            fontSize: 12,
                            color: target.isActive
                                ? Colors.green[600]
                                : Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRecentSales() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_recentSales.isEmpty) {
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
          children: [
            Icon(
              Icons.receipt_long,
              size: 48,
              color: colorScheme.onSurface.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No recent sales',
              style: TextStyle(
                fontSize: 16,
                color: colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Sales will appear here once products are sold',
              style: TextStyle(
                color: colorScheme.onSurface.withOpacity(0.4),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

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
            'Recent Sales',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _recentSales.take(10).length, // Show only last 10 sales
            separatorBuilder: (context, index) => const Divider(),
            itemBuilder: (context, index) {
              final sale = _recentSales[index];
              final saleItems = _saleItemsMap[sale.id] ?? [];
              final relevantItems = saleItems
                  .where((item) => _targets
                      .any((target) => target.productId == item.productId))
                  .toList();

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.receipt,
                        color: colorScheme.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Sale #${sale.id.substring(0, 8)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            relevantItems
                                .map((item) =>
                                    '${_getProductName(item.productId)} (${item.quantity})')
                                .join(', '),
                            style: TextStyle(
                              color: colorScheme.onSurface.withOpacity(0.6),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '₦${sale.totalAmount.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          sale.createdAt != null
                              ? '${sale.createdAt!.day}/${sale.createdAt!.month}/${sale.createdAt!.year}'
                              : 'Unknown',
                          style: TextStyle(
                            color: colorScheme.onSurface.withOpacity(0.6),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ],
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
        title: Text('Sales Tracking - ${widget.marketer.fullName}'),
        backgroundColor: colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Refresh Data',
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
                            widget.marketer.fullName.isNotEmpty
                                ? widget.marketer.fullName[0].toUpperCase()
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
                                widget.marketer.fullName,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                'Sales Tracking',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: colorScheme.onSurface.withOpacity(0.6),
                                ),
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
                          icon: Icons.dashboard,
                          title: 'Overview',
                          isSelected: true,
                          onTap: () {},
                        ),
                        _buildSidebarItem(
                          icon: Icons.track_changes,
                          title: 'Targets Progress',
                          onTap: () {
                            // TODO: Navigate to targets section
                          },
                        ),
                        _buildSidebarItem(
                          icon: Icons.receipt_long,
                          title: 'Recent Sales',
                          onTap: () {
                            // TODO: Navigate to sales section
                          },
                        ),
                        _buildSidebarItem(
                          icon: Icons.analytics,
                          title: 'Performance Analytics',
                          onTap: () {
                            // TODO: Navigate to analytics
                          },
                        ),
                        _buildSidebarItem(
                          icon: Icons.trending_up,
                          title: 'Trends',
                          onTap: () {
                            // TODO: Navigate to trends
                          },
                        ),
                        const Divider(height: 32),
                        _buildSidebarItem(
                          icon: Icons.filter_list,
                          title: 'Filters',
                          onTap: () {
                            _showFilterDialog();
                          },
                        ),
                        _buildSidebarItem(
                          icon: Icons.download,
                          title: 'Export Data',
                          onTap: () {
                            // TODO: Export functionality
                          },
                        ),
                      ],
                    ),
                  ),
                  // Sidebar Footer - Quick Stats
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
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Total Targets',
                              style: TextStyle(
                                fontSize: 12,
                                color: colorScheme.onSurface.withOpacity(0.6),
                              ),
                            ),
                            Text(
                              _targets.length.toString(),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'On Track',
                              style: TextStyle(
                                fontSize: 12,
                                color: colorScheme.onSurface.withOpacity(0.6),
                              ),
                            ),
                            Text(
                              targetsOnTrack.toString(),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Revenue',
                              style: TextStyle(
                                fontSize: 12,
                                color: colorScheme.onSurface.withOpacity(0.6),
                              ),
                            ),
                            Text(
                              '₦${totalRevenue.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
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
                    // Metrics Row
                    Row(
                      children: [
                        _buildMetricCard(
                          'Total Revenue',
                          '₦${totalRevenue.toStringAsFixed(0)}',
                          Icons.attach_money,
                          Colors.green,
                        ),
                        const SizedBox(width: 12),
                        _buildMetricCard(
                          'Units Sold',
                          totalQuantitySold.toString(),
                          Icons.inventory,
                          Colors.blue,
                        ),
                        const SizedBox(width: 12),
                        _buildMetricCard(
                          'Avg Progress',
                          '${averageProgress.toStringAsFixed(1)}%',
                          Icons.trending_up,
                          Colors.orange,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Overall Progress
                    _buildOverallProgress(),
                    const SizedBox(height: 20),

                    // Targets List
                    _buildTargetsList(),
                    const SizedBox(height: 20),

                    // Recent Sales
                    _buildRecentSales(),
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

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter Options'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('All Time'),
              leading: Radio<String>(
                value: 'all',
                groupValue: _selectedPeriod,
                onChanged: (value) {
                  setState(() => _selectedPeriod = value!);
                  Navigator.pop(context);
                  _loadData();
                },
              ),
            ),
            ListTile(
              title: const Text('This Month'),
              leading: Radio<String>(
                value: 'month',
                groupValue: _selectedPeriod,
                onChanged: (value) {
                  setState(() => _selectedPeriod = value!);
                  Navigator.pop(context);
                  _loadData();
                },
              ),
            ),
            ListTile(
              title: const Text('This Week'),
              leading: Radio<String>(
                value: 'week',
                groupValue: _selectedPeriod,
                onChanged: (value) {
                  setState(() => _selectedPeriod = value!);
                  Navigator.pop(context);
                  _loadData();
                },
              ),
            ),
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
}
