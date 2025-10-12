import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/models/outlet_model.dart';
import '../../core/models/marketer_model.dart';
import '../../core/models/marketer_target_model.dart';
import '../../core/models/product_model.dart';
import '../../core/services/marketer_service.dart';
import '../../core/services/sync_service.dart';
import '../../widgets/loading_overlay.dart';
import '../../widgets/dashboard_layout.dart';
import '../../widgets/marketer_form_dialog.dart';
import 'marketer_profile_screen.dart';

class ChartDataPoint {
  final String label;
  final double value;

  ChartDataPoint({required this.label, required this.value});
}

class MarketersScreen extends StatefulWidget {
  const MarketersScreen({super.key});

  @override
  State<MarketersScreen> createState() => _MarketersScreenState();
}

class _MarketersScreenState extends State<MarketersScreen> {
  final MarketerService _marketerService = MarketerService();
  final SyncService _syncService = SyncService();

  List<Marketer> _marketers = [];
  List<Outlet> _outlets = [];
  List<Product> _products = [];
  List<MarketerTarget> _targets = [];
  bool _isLoading = false;
  String _searchQuery = '';
  String? _selectedProductId;
  String? _selectedMarketerId;

  // Metrics
  int get totalMarketers => _marketers.length;
  int get activeMarketers =>
      _marketers.where((m) => m.status == 'active').length;
  int get inactiveMarketers =>
      _marketers.where((m) => m.status != 'active').length;

  String _getOutletName(String outletId) {
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
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      await Future.wait([
        _loadMarketers(),
        _loadOutlets(),
        _loadProducts(),
        _loadTargets(),
      ]);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMarketers() async {
    try {
      _marketers = await _marketerService.getAllMarketers();
    } catch (e) {
      print('Error loading marketers: $e');
    }
  }

  Future<void> _loadOutlets() async {
    try {
      _outlets = await _syncService.getAllLocalOutlets();
    } catch (e) {
      print('Error loading outlets: $e');
    }
  }

  Future<void> _loadProducts() async {
    try {
      _products = await _syncService.getAllProducts();
    } catch (e) {
      print('Error loading products: $e');
    }
  }

  Future<void> _loadTargets() async {
    try {
      _targets = await _marketerService.getAllMarketerTargets();
    } catch (e) {
      print('Error loading targets: $e');
    }
  }

  Future<void> _navigateToMarketerForm({Marketer? marketer}) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => MarketerFormDialog(marketer: marketer),
    );

    if (result == true) {
      _loadData();
    }
  }

  Future<void> _navigateToMarketerProfile(Marketer marketer) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MarketerProfileScreen(marketer: marketer),
      ),
    );
    _loadData(); // Refresh data when returning
  }

  Future<void> _deleteMarketer(Marketer marketer) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: Text(
            'Are you sure you want to delete ${marketer.fullName}? This will also delete all their targets.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);
      try {
        final success = await _marketerService.deleteMarketer(marketer.id);
        if (success) {
          _loadData();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Marketer deleted successfully')),
            );
          }
        } else {
          throw Exception('Failed to delete marketer');
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting marketer: $e')),
          );
        }
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _syncData() async {
    setState(() => _isLoading = true);
    try {
      await _marketerService.fullSync();
      _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sync completed successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sync failed: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildMetricCard(
    String title,
    String value,
    IconData icon,
    Color color,
    ColorScheme colorScheme,
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
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    title,
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
    );
  }

  Widget _buildMarketersTable(
      List<Marketer> marketers, ColorScheme colorScheme) {
    return Container(
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
          // Sticky Header
          Container(
            decoration: BoxDecoration(
              color: colorScheme.primary.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Table(
              columnWidths: const {
                0: FlexColumnWidth(2.5), // Name
                1: FlexColumnWidth(2.5), // Email
                2: FlexColumnWidth(2), // Phone
                3: FlexColumnWidth(2), // Outlet
                4: FlexColumnWidth(1.5), // Status
                5: FlexColumnWidth(1), // Actions
              },
              children: [
                TableRow(
                  children: [
                    _buildTableHeader('Name', colorScheme),
                    _buildTableHeader('Email', colorScheme),
                    _buildTableHeader('Phone', colorScheme),
                    _buildTableHeader('Outlet', colorScheme),
                    _buildTableHeader('Status', colorScheme),
                    _buildTableHeader('Actions', colorScheme),
                  ],
                ),
              ],
            ),
          ),
          // Table Body
          Expanded(
            child: SingleChildScrollView(
              child: Table(
                columnWidths: const {
                  0: FlexColumnWidth(2.5), // Name
                  1: FlexColumnWidth(2.5), // Email
                  2: FlexColumnWidth(2), // Phone
                  3: FlexColumnWidth(2), // Outlet
                  4: FlexColumnWidth(1.5), // Status
                  5: FlexColumnWidth(1), // Actions
                },
                children: marketers.map((marketer) {
                  return TableRow(
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: Colors.grey.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                    ),
                    children: [
                      _buildClickableTableCell(
                          marketer.fullName, colorScheme, marketer),
                      _buildClickableTableCell(
                          marketer.email, colorScheme, marketer),
                      _buildClickableTableCell(marketer.phone ?? 'Not Provided',
                          colorScheme, marketer),
                      _buildClickableTableCell(
                          _getOutletName(marketer.outletId),
                          colorScheme,
                          marketer),
                      _buildClickableStatusCell(
                          marketer.status, colorScheme, marketer),
                      _buildActionsCell(marketer, colorScheme),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeader(String title, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: colorScheme.primary,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildTableCell(String content, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Text(
        content,
        style: TextStyle(
          color: colorScheme.onSurface,
          fontSize: 13,
        ),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildClickableTableCell(
      String content, ColorScheme colorScheme, Marketer marketer) {
    return InkWell(
      onTap: () => _navigateToMarketerProfile(marketer),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Text(
          content,
          style: TextStyle(
            color: colorScheme.onSurface,
            fontSize: 13,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _buildStatusCell(String status, ColorScheme colorScheme) {
    final isActive = status.toLowerCase() == 'active';
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isActive
              ? Colors.green.withOpacity(0.1)
              : Colors.orange.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive ? Colors.green : Colors.orange,
            width: 1,
          ),
        ),
        child: Text(
          status,
          style: TextStyle(
            color: isActive ? Colors.green[700] : Colors.orange[700],
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildClickableStatusCell(
      String status, ColorScheme colorScheme, Marketer marketer) {
    final isActive = status.toLowerCase() == 'active';
    return InkWell(
      onTap: () => _navigateToMarketerProfile(marketer),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isActive
                ? Colors.green.withOpacity(0.1)
                : Colors.orange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isActive ? Colors.green : Colors.orange,
              width: 1,
            ),
          ),
          child: Text(
            status,
            style: TextStyle(
              color: isActive ? Colors.green[700] : Colors.orange[700],
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  Widget _buildActionsCell(Marketer marketer, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: PopupMenuButton<String>(
        icon: Icon(
          Icons.more_vert,
          color: colorScheme.primary,
          size: 20,
        ),
        onSelected: (value) {
          switch (value) {
            case 'edit':
              _navigateToMarketerForm(marketer: marketer);
              break;
            case 'delete':
              _deleteMarketer(marketer);
              break;
          }
        },
        itemBuilder: (context) => [
          const PopupMenuItem(
            value: 'edit',
            child: Row(
              children: [
                Icon(Icons.edit, size: 16),
                SizedBox(width: 8),
                Text('Edit'),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'delete',
            child: Row(
              children: [
                Icon(Icons.delete, size: 16, color: Colors.red),
                SizedBox(width: 8),
                Text('Delete', style: TextStyle(color: Colors.red)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsSection(ColorScheme colorScheme) {
    return Container(
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
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.analytics,
                  color: colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  'Performance Analytics',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
                const Spacer(),
                // Product Filter
                Container(
                  width: 200,
                  child: DropdownButtonFormField<String>(
                    value: _selectedProductId,
                    decoration: InputDecoration(
                      labelText: 'Select Product',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    items: [
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Text('All Products'),
                      ),
                      ..._products.map((product) => DropdownMenuItem<String>(
                            value: product.id,
                            child: Text(product.productName),
                          )),
                    ],
                    onChanged: (value) {
                      setState(() => _selectedProductId = value);
                    },
                  ),
                ),
                const SizedBox(width: 16),
                // Marketer Filter
                Container(
                  width: 200,
                  child: DropdownButtonFormField<String>(
                    value: _selectedMarketerId,
                    decoration: InputDecoration(
                      labelText: 'Select Marketer',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    items: [
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Text('All Marketers'),
                      ),
                      ..._marketers.map((marketer) => DropdownMenuItem<String>(
                            value: marketer.id,
                            child: Text(marketer.fullName),
                          )),
                    ],
                    onChanged: (value) {
                      setState(() => _selectedMarketerId = value);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 300,
              child: _buildPerformanceChart(colorScheme),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPerformanceChart(ColorScheme colorScheme) {
    final chartData = _getChartData();

    if (chartData.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.bar_chart,
              size: 64,
              color: colorScheme.onSurface.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No performance data available',
              style: TextStyle(
                fontSize: 16,
                color: colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add targets and sales data to see analytics',
              style: TextStyle(
                color: colorScheme.onSurface.withOpacity(0.4),
              ),
            ),
          ],
        ),
      );
    }

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY:
            chartData.map((e) => e.value).reduce((a, b) => a > b ? a : b) * 1.2,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            tooltipBgColor: colorScheme.surface,
            tooltipBorder: BorderSide(color: colorScheme.outline),
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              return BarTooltipItem(
                '${chartData[group.x.toInt()].label}\n',
                TextStyle(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                ),
                children: [
                  TextSpan(
                    text: '${rod.toY.toStringAsFixed(1)}%',
                    style: TextStyle(
                      color: colorScheme.primary,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                if (value.toInt() >= 0 && value.toInt() < chartData.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      chartData[value.toInt()].label,
                      style: TextStyle(
                        color: colorScheme.onSurface.withOpacity(0.7),
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  );
                }
                return const Text('');
              },
              reservedSize: 40,
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                return Text(
                  '${value.toInt()}%',
                  style: TextStyle(
                    color: colorScheme.onSurface.withOpacity(0.7),
                    fontSize: 12,
                  ),
                );
              },
              reservedSize: 40,
            ),
          ),
        ),
        borderData: FlBorderData(
          show: false,
        ),
        barGroups: chartData.asMap().entries.map((entry) {
          return BarChartGroupData(
            x: entry.key,
            barRods: [
              BarChartRodData(
                toY: entry.value.value,
                color: _getBarColor(entry.value.value, colorScheme),
                width: 20,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(4),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Color _getBarColor(double value, ColorScheme colorScheme) {
    if (value >= 80) return Colors.green;
    if (value >= 60) return Colors.blue;
    if (value >= 40) return Colors.orange;
    return Colors.red;
  }

  List<ChartDataPoint> _getChartData() {
    List<ChartDataPoint> data = [];

    // Filter targets based on selected filters
    var filteredTargets = _targets.where((target) {
      bool matchesProduct =
          _selectedProductId == null || target.productId == _selectedProductId;
      bool matchesMarketer = _selectedMarketerId == null ||
          target.marketerId == _selectedMarketerId;
      return matchesProduct && matchesMarketer;
    }).toList();

    if (_selectedProductId != null && _selectedMarketerId == null) {
      // Show performance by marketer for selected product
      final marketerPerformance = <String, List<MarketerTarget>>{};

      for (var target in filteredTargets) {
        marketerPerformance
            .putIfAbsent(target.marketerId, () => [])
            .add(target);
      }

      for (var entry in marketerPerformance.entries) {
        final marketer = _marketers.firstWhere(
          (m) => m.id == entry.key,
          orElse: () => Marketer(
            id: entry.key,
            fullName: 'Unknown',
            email: '',
            outletId: '',
          ),
        );

        final avgProgress = entry.value.isEmpty
            ? 0.0
            : entry.value
                    .map((t) => t.progressPercentage)
                    .reduce((a, b) => a + b) /
                entry.value.length;

        data.add(ChartDataPoint(
          label: marketer.fullName.length > 10
              ? '${marketer.fullName.substring(0, 10)}...'
              : marketer.fullName,
          value: avgProgress,
        ));
      }
    } else if (_selectedMarketerId != null && _selectedProductId == null) {
      // Show performance by product for selected marketer
      final productPerformance = <String, List<MarketerTarget>>{};

      for (var target in filteredTargets) {
        productPerformance.putIfAbsent(target.productId, () => []).add(target);
      }

      for (var entry in productPerformance.entries) {
        final product = _products.firstWhere(
          (p) => p.id == entry.key,
          orElse: () => Product(
            id: entry.key,
            productName: 'Unknown',
            quantity: 0,
            unit: '',
            costPerUnit: 0,
            totalCost: 0,
            dateAdded: DateTime.now(),
            outletId: '',
            createdAt: DateTime.now(),
          ),
        );

        final avgProgress = entry.value.isEmpty
            ? 0.0
            : entry.value
                    .map((t) => t.progressPercentage)
                    .reduce((a, b) => a + b) /
                entry.value.length;

        data.add(ChartDataPoint(
          label: product.productName.length > 10
              ? '${product.productName.substring(0, 10)}...'
              : product.productName,
          value: avgProgress,
        ));
      }
    } else {
      // Show overall performance by marketer
      final marketerPerformance = <String, List<MarketerTarget>>{};

      for (var target in filteredTargets) {
        marketerPerformance
            .putIfAbsent(target.marketerId, () => [])
            .add(target);
      }

      for (var entry in marketerPerformance.entries) {
        final marketer = _marketers.firstWhere(
          (m) => m.id == entry.key,
          orElse: () => Marketer(
            id: entry.key,
            fullName: 'Unknown',
            email: '',
            outletId: '',
          ),
        );

        final avgProgress = entry.value.isEmpty
            ? 0.0
            : entry.value
                    .map((t) => t.progressPercentage)
                    .reduce((a, b) => a + b) /
                entry.value.length;

        data.add(ChartDataPoint(
          label: marketer.fullName.length > 10
              ? '${marketer.fullName.substring(0, 10)}...'
              : marketer.fullName,
          value: avgProgress,
        ));
      }
    }

    return data;
  }

  Widget _buildMarketerCard(Marketer marketer) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _navigateToMarketerProfile(marketer),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: colorScheme.primary.withOpacity(0.1),
                child: Text(
                  marketer.fullName.isNotEmpty
                      ? marketer.fullName[0].toUpperCase()
                      : 'M',
                  style: TextStyle(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      marketer.fullName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      marketer.email,
                      style: TextStyle(
                        color: colorScheme.onSurface.withOpacity(0.6),
                        fontSize: 14,
                      ),
                    ),
                    if (marketer.phone != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        marketer.phone!,
                        style: TextStyle(
                          color: colorScheme.onSurface.withOpacity(0.6),
                          fontSize: 14,
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.business,
                          size: 16,
                          color: colorScheme.onSurface.withOpacity(0.6),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _getOutletName(marketer.outletId),
                          style: TextStyle(
                            color: colorScheme.onSurface.withOpacity(0.6),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: marketer.status == 'active'
                          ? Colors.green.withOpacity(0.1)
                          : Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      marketer.status.toUpperCase(),
                      style: TextStyle(
                        color: marketer.status == 'active'
                            ? Colors.green[700]
                            : Colors.orange[700],
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      switch (value) {
                        case 'edit':
                          _navigateToMarketerForm(marketer: marketer);
                          break;
                        case 'delete':
                          _deleteMarketer(marketer);
                          break;
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit, size: 16),
                            SizedBox(width: 8),
                            Text('Edit'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, size: 16, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Delete', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                    child: Icon(
                      Icons.more_vert,
                      color: colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ],
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

    final filteredMarketers = _marketers
        .where((marketer) =>
            marketer.fullName
                .toLowerCase()
                .contains(_searchQuery.toLowerCase()) ||
            marketer.email.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            _getOutletName(marketer.outletId)
                .toLowerCase()
                .contains(_searchQuery.toLowerCase()))
        .toList();

    return DashboardLayout(
      title: 'Marketers Target',
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _navigateToMarketerForm(),
        tooltip: 'Add New Marketer',
        icon: const Icon(Icons.person_add),
        label:
            const Text('Add Marketer', style: TextStyle(color: Colors.white)),
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
                    label: const Text('Sync Data'),
                    onPressed: _syncData,
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
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Row(
                          children: [
                            _buildMetricCard(
                              'Total Marketers',
                              totalMarketers.toString(),
                              Icons.people,
                              Colors.blue,
                              colorScheme,
                            ),
                            const SizedBox(width: 16),
                            _buildMetricCard(
                              'Active',
                              activeMarketers.toString(),
                              Icons.check_circle,
                              Colors.green,
                              colorScheme,
                            ),
                            const SizedBox(width: 16),
                            _buildMetricCard(
                              'Inactive',
                              inactiveMarketers.toString(),
                              Icons.pause_circle,
                              Colors.orange,
                              colorScheme,
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: TextField(
                          decoration: InputDecoration(
                            labelText: 'Search Marketers',
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
                      // Marketers Table Section
                      Container(
                        height: 400, // Fixed height for the table
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: filteredMarketers.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.person_search,
                                      size: 64,
                                      color: colorScheme.onSurface
                                          .withOpacity(0.3),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      _searchQuery.isEmpty
                                          ? 'No marketers found'
                                          : 'No marketers match your search',
                                      style: TextStyle(
                                        fontSize: 18,
                                        color: colorScheme.onSurface
                                            .withOpacity(0.6),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      _searchQuery.isEmpty
                                          ? 'Add your first marketer to get started'
                                          : 'Try adjusting your search terms',
                                      style: TextStyle(
                                        color: colorScheme.onSurface
                                            .withOpacity(0.4),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : _buildMarketersTable(
                                filteredMarketers, colorScheme),
                      ),
                      // Analytics Chart Section - Now appears after the table
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: _buildAnalyticsSection(colorScheme),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
