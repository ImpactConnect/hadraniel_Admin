import 'package:flutter/material.dart';
import '../../widgets/dashboard_layout.dart';
import '../../widgets/loading_indicator.dart';
import '../../core/services/sync_service.dart';
import '../../core/services/stock_intake_service.dart';
import '../../core/services/customer_service.dart';
import 'package:intl/intl.dart';
import 'dart:async';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final SyncService _syncService = SyncService();
  final StockIntakeService _stockIntakeService = StockIntakeService();
  final CustomerService _customerService = CustomerService();

  bool _isLoading = true;
  Map<String, dynamic> _dashboardData = {
    'salesRepsCount': 0,
    'outletsCount': 0,
    'productsCount': 0,
    'totalSales': 0.0,
    'stockValue': 0.0,
    'outstandingPayments': 0.0,
  };

  // Alert data
  List<Map<String, dynamic>> _lowStockItems = [];
  List<Map<String, dynamic>> _outstandingCustomers = [];
  List<Map<String, dynamic>> _recentSales = [];
  DateTime? _lastSyncTime;
  String? _syncError;
  Timer? _alertTimer;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
    _loadAlertData();
    _startAlertTimer();
  }

  @override
  void dispose() {
    _alertTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadDashboardData() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Fetch data from various services
      final salesMetrics = await _syncService.getSalesMetrics();
      final salesRepsCount = await _getSalesRepsCount();
      final outletsCount = await _getOutletsCount();
      final productsCount = await _getProductsCount();
      final stockValue = await _getStockValue();
      final salesCount = await _getSalesCount();

      setState(() {
        _dashboardData = {
          'salesRepsCount': salesRepsCount,
          'outletsCount': outletsCount,
          'productsCount': productsCount,
          'totalSales': salesMetrics['total_amount'] ?? 0.0,
          'stockValue': stockValue,
          'outstandingPayments': salesMetrics['total_outstanding'] ?? 0.0,
          'totalItemsSold': salesMetrics['total_items_sold'] ?? 0,
          'salesCount': salesCount,
        };
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading dashboard data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _startAlertTimer() {
    _alertTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      _loadAlertData();
    });
  }

  Future<void> _loadAlertData() async {
    try {
      final lowStock = await _getLowStockItems();
      final outstanding = await _getOutstandingCustomers();
      final recent = await _getRecentSales();
      final syncStatus = await _getSyncStatus();

      setState(() {
        _lowStockItems = lowStock;
        _outstandingCustomers = outstanding;
        _recentSales = recent;
        _lastSyncTime = syncStatus['lastSync'];
        _syncError = syncStatus['error'];
      });
    } catch (e) {
      print('Error loading alert data: $e');
    }
  }

  Future<List<Map<String, dynamic>>> _getLowStockItems() async {
    try {
      final db = await _syncService.database;
      final result = await db.rawQuery('''
        SELECT sb.product_id, p.product_name, sb.given_quantity, sb.balance_quantity, sb.last_updated,
               ROUND((sb.balance_quantity * 100.0 / sb.given_quantity), 2) as stock_percentage
        FROM stock_balances sb
        JOIN products p ON sb.product_id = p.id
        WHERE sb.given_quantity > 0 AND (sb.balance_quantity * 100.0 / sb.given_quantity) < 75
        ORDER BY stock_percentage ASC
        LIMIT 5
      ''');
      return result;
    } catch (e) {
      print('Error getting low stock items: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _getOutstandingCustomers() async {
    try {
      final customers = await _customerService.getCustomersWithOutstandingBalance();
      return customers.take(5).map((customer) => {
        'name': customer.fullName,
        'amount': customer.totalOutstanding,
        'phone': customer.phone ?? 'N/A',
      }).toList();
    } catch (e) {
      print('Error getting outstanding customers: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _getRecentSales() async {
    try {
      final sales = await _syncService.getSalesToday();
      return sales.take(5).toList();
    } catch (e) {
      print('Error getting recent sales: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> _getSyncStatus() async {
    try {
      // Check if online and get last sync time from preferences or database
      final isOnline = await _syncService.isOnline();
      return {
        'lastSync': DateTime.now().subtract(const Duration(minutes: 15)),
        'error': isOnline ? null : 'Offline - Unable to sync',
      };
    } catch (e) {
      return {
        'lastSync': null,
        'error': 'Sync error: ${e.toString()}',
      };
    }
  }

  Future<int> _getSalesRepsCount() async {
    try {
      final reps = await _syncService.getAllLocalReps();
      return reps.length;
    } catch (e) {
      print('Error getting sales reps count: $e');
      return 0;
    }
  }

  Future<int> _getOutletsCount() async {
    try {
      final outlets = await _syncService.getAllLocalOutlets();
      return outlets.length;
    } catch (e) {
      print('Error getting outlets count: $e');
      return 0;
    }
  }

  Future<int> _getProductsCount() async {
    try {
      final products = await _syncService.getAllLocalProducts();
      return products.length;
    } catch (e) {
      print('Error getting products count: $e');
      return 0;
    }
  }

  Future<double> _getStockValue() async {
    try {
      final intakes = await _stockIntakeService.getAllIntakes();
      double totalValue = 0.0;
      for (var intake in intakes) {
        totalValue += intake.totalCost;
      }
      return totalValue;
    } catch (e) {
      print('Error getting stock value: $e');
      return 0.0;
    }
  }

  Future<int> _getSalesCount() async {
    try {
      final sales = await _syncService.getAllLocalSales();
      return sales.length;
    } catch (e) {
      print('Error getting sales count: $e');
      return 0;
    }
  }

  Future<List<Map<String, dynamic>>> _getTopProductsByRevenue(
      {int limit = 5}) async {
    try {
      final db = await _syncService.database;
      final result = await db.rawQuery('''
        SELECT 
          p.product_name,
          SUM(si.quantity * si.unit_price) as total_revenue,
          SUM(si.quantity) as total_quantity_sold
        FROM sale_items si
        JOIN products p ON si.product_id = p.id
        GROUP BY si.product_id, p.product_name
        ORDER BY total_revenue DESC
        LIMIT ?
      ''', [limit]);

      return result
          .map((row) => {
                'product_name': row['product_name'] as String,
                'total_revenue': (row['total_revenue'] as num).toDouble(),
                'total_quantity_sold':
                    (row['total_quantity_sold'] as num).toDouble(),
              })
          .toList();
    } catch (e) {
      print('Error getting top products by revenue: $e');
      return [];
    }
  }

  Widget _buildSummaryCard(String title, String value, IconData icon,
      {Color? gradientStart, Color? gradientEnd}) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              gradientStart ?? Colors.blue.shade600,
              gradientEnd ?? Colors.blue.shade800,
            ],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 28, color: Colors.white),
            const SizedBox(height: 8),
            Flexible(
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
            const SizedBox(height: 4),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingSummaryCard(String title, IconData icon,
      {Color? gradientStart, Color? gradientEnd}) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              (gradientStart ?? Colors.blue.shade600).withOpacity(0.7),
              (gradientEnd ?? Colors.blue.shade800).withOpacity(0.7),
            ],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 28, color: Colors.white),
            const SizedBox(height: 8),
            Flexible(
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
            const SizedBox(height: 4),
            const SizedBox(
              width: 20,
              height: 20,
              child: LoadingIndicator(size: 20, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  String _formatCurrency(double amount) {
    if (amount >= 1000000) {
      return '₦${(amount / 1000000).toStringAsFixed(1)}M';
    } else if (amount >= 1000) {
      return '₦${(amount / 1000).toStringAsFixed(1)}K';
    } else {
      return '₦${amount.toStringAsFixed(0)}';
    }
  }

  Widget _buildSalesAnalyticsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Sales Analytics',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 24),
        if (_isLoading) _buildLoadingAnalytics() else _buildAnalyticsContent(),
      ],
    );
  }

  Widget _buildLoadingAnalytics() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              flex: 2,
              child: _buildLoadingCard('Sales Trends', 200),
            ),
            const SizedBox(width: 20),
            Expanded(
              flex: 1,
              child: _buildLoadingCard('Quick Stats', 200),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: _buildLoadingCard('Top Products', 180),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: _buildLoadingCard('Sales by Outlet', 180),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLoadingCard(String title, double height) {
    return Container(
      height: height,
      padding: const EdgeInsets.all(20),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsContent() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              flex: 2,
              child: _buildSalesTrendsCard(),
            ),
            const SizedBox(width: 20),
            Expanded(
              flex: 1,
              child: _buildQuickStatsCard(),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: _buildTopProductsCard(),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: _buildSalesByOutletCard(),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSalesTrendsCard() {
    return Container(
      height: 200,
      padding: const EdgeInsets.all(20),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.trending_up, color: Colors.green.shade600, size: 24),
              const SizedBox(width: 8),
              const Text(
                'Sales Trends',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.blue.shade50, Colors.blue.shade100],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _formatCurrency(_dashboardData['totalSales'] ?? 0),
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Total Sales This Period',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStatsCard() {
    final totalItems = _dashboardData['totalItemsSold'] ?? 0;
    final avgSaleValue = _dashboardData['totalSales'] != null &&
            _dashboardData['totalSales'] > 0
        ? (_dashboardData['totalSales'] / (_dashboardData['salesCount'] ?? 1))
        : 0.0;

    return Container(
      height: 200,
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.analytics, color: Colors.purple.shade600, size: 20),
              const SizedBox(width: 6),
              const Text(
                'Quick Stats',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildStatRow('Items Sold', '$totalItems', Icons.shopping_cart),
                _buildStatRow('Avg Sale', _formatCurrency(avgSaleValue),
                    Icons.attach_money),
                _buildStatRow(
                    'Outstanding',
                    _formatCurrency(_dashboardData['outstandingPayments'] ?? 0),
                    Icons.payment),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value, IconData icon) {
    return Flexible(
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.grey.shade600),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildTopProductsCard() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _getTopProductsByRevenue(),
      builder: (context, snapshot) {
        final topProducts = snapshot.data ?? [];

        // Build tooltip content
        String tooltipMessage = '';
        if (topProducts.isNotEmpty) {
          tooltipMessage = 'Top 5 Products by Revenue:\n\n';
          for (int i = 0; i < topProducts.length; i++) {
            final product = topProducts[i];
            tooltipMessage += '${i + 1}. ${product['product_name']}\n';
            tooltipMessage +=
                '   Revenue: ${_formatCurrency(product['total_revenue'])}\n';
            tooltipMessage +=
                '   Qty Sold: ${product['total_quantity_sold'].toInt()}\n\n';
          }
        } else {
          tooltipMessage = 'No sales data available';
        }

        return Tooltip(
          message: tooltipMessage,
          preferBelow: false,
          verticalOffset: 20,
          margin: const EdgeInsets.only(right: 20),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade800,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          textStyle: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            height: 1.4,
          ),
          child: Container(
            height: 180,
            padding: const EdgeInsets.all(20),
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.star, color: Colors.orange.shade600, size: 24),
                    const SizedBox(width: 8),
                    const Text(
                      'Top Products',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      Icons.info_outline,
                      size: 16,
                      color: Colors.grey.shade500,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Colors.orange.shade50, Colors.orange.shade100],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.inventory_2,
                            size: 24,
                            color: Colors.orange.shade600,
                          ),
                          const SizedBox(height: 4),
                          Flexible(
                            child: Text(
                              topProducts.isNotEmpty
                                  ? '${topProducts.length} Top Products'
                                  : '${_dashboardData['productsCount'] ?? 0} Products',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange.shade700,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Flexible(
                            child: Text(
                              topProducts.isNotEmpty
                                  ? 'Hover for details'
                                  : 'Available in inventory',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.orange.shade600,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
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
      },
    );
  }

  Widget _buildSalesByOutletCard() {
    return Container(
      height: 180,
      padding: const EdgeInsets.all(20),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.store, color: Colors.green.shade600, size: 24),
              const SizedBox(width: 8),
              const Text(
                'Sales by Outlet',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.green.shade50, Colors.green.shade100],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.business,
                      size: 24,
                      color: Colors.green.shade600,
                    ),
                    const SizedBox(height: 4),
                    Flexible(
                      child: Text(
                        '${_dashboardData['outletsCount'] ?? 0} Outlets',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade700,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Flexible(
                      child: Text(
                        'Active sales locations',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.green.shade600,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertsSection() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildLowStockAlert()),
            const SizedBox(width: 20),
            Expanded(child: _buildOutstandingPaymentsAlert()),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(child: _buildSyncStatusAlert()),
            const SizedBox(width: 20),
            Expanded(child: _buildRecentSalesAlert()),
          ],
        ),
      ],
    );
  }

  Widget _buildLowStockAlert() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(20.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.red.shade50, Colors.red.shade100],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.shade400,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.warning,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Low Stock Alert',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
                const Spacer(),
                if (_lowStockItems.length > 3)
                  TextButton(
                    onPressed: () {
                      Navigator.pushNamed(context, '/stock');
                    },
                    child: const Text(
                      'View All',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.red,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              height: 120,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: _lowStockItems.isEmpty
                  ? const Center(
                      child: Text(
                        'No low stock items',
                        style: TextStyle(
                          fontSize: 14,
                          fontStyle: FontStyle.italic,
                          color: Colors.grey,
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _lowStockItems.length > 3 ? 3 : _lowStockItems.length,
                      itemBuilder: (context, index) {
                        final item = _lowStockItems[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  item['product_name'] ?? 'Unknown',
                                  style: const TextStyle(fontSize: 12),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '${item['balance_quantity'] ?? 0}/${item['given_quantity'] ?? 0}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.red.shade600,
                                    ),
                                  ),
                                  Text(
                                    '${item['stock_percentage'] ?? 0}%',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.red.shade400,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOutstandingPaymentsAlert() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(20.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.orange.shade50, Colors.orange.shade100],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade400,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.payment,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Outstanding Payments',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                ),
                const Spacer(),
                if (_outstandingCustomers.length > 3)
                  TextButton(
                    onPressed: () {
                      Navigator.pushNamed(context, '/customers');
                    },
                    child: const Text(
                      'View All',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              height: 120,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: _outstandingCustomers.isEmpty
                  ? const Center(
                      child: Text(
                        'No outstanding payments',
                        style: TextStyle(
                          fontSize: 14,
                          fontStyle: FontStyle.italic,
                          color: Colors.grey,
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _outstandingCustomers.length > 3 ? 3 : _outstandingCustomers.length,
                      itemBuilder: (context, index) {
                        final customer = _outstandingCustomers[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  customer['name'] ?? 'Unknown',
                                  style: const TextStyle(fontSize: 12),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                _formatCurrency(customer['amount'] ?? 0),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange.shade600,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSyncStatusAlert() {
    final hasError = _syncError != null;
    final color = hasError ? Colors.red : Colors.green;
    
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(20.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color.shade50, color.shade100],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.shade400,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    hasError ? Icons.sync_problem : Icons.sync,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Sync Status',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              height: 120,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (hasError)
                    Text(
                      _syncError!,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.red.shade600,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  else
                    Text(
                      'System synchronized',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green.shade600,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  const SizedBox(height: 8),
                  if (_lastSyncTime != null)
                    Text(
                      'Last sync: ${DateFormat('MMM dd, HH:mm').format(_lastSyncTime!)}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.grey,
                      ),
                    ),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: () => _loadAlertData(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color.shade400,
                      minimumSize: const Size(double.infinity, 32),
                    ),
                    child: const Text(
                      'Refresh',
                      style: TextStyle(fontSize: 12, color: Colors.white),
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

  Widget _buildRecentSalesAlert() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(20.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.blue.shade50, Colors.blue.shade100],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade400,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.receipt,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Recent Sales',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              height: 120,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: _recentSales.isEmpty
                  ? const Center(
                      child: Text(
                        'No recent sales',
                        style: TextStyle(
                          fontSize: 14,
                          fontStyle: FontStyle.italic,
                          color: Colors.grey,
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _recentSales.length,
                      itemBuilder: (context, index) {
                        final sale = _recentSales[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Sale #${sale['id'] ?? index + 1}',
                                  style: const TextStyle(fontSize: 12),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                _formatCurrency(sale['total_amount'] ?? 0),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue.shade600,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DashboardLayout(
      title: 'Dashboard',
      child: RefreshIndicator(
        onRefresh: _loadDashboardData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Overview',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    if (!_isLoading)
                      IconButton(
                        onPressed: _loadDashboardData,
                        icon: const Icon(Icons.refresh, color: Colors.blue),
                        tooltip: 'Refresh Data',
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                LayoutBuilder(
                  builder: (context, constraints) {
                    int crossAxisCount = 4;
                    if (constraints.maxWidth < 1200) crossAxisCount = 3;
                    if (constraints.maxWidth < 900) crossAxisCount = 2;
                    if (constraints.maxWidth < 600) crossAxisCount = 1;

                    return GridView.count(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: 20,
                      mainAxisSpacing: 20,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      childAspectRatio: 1.2,
                      children: _isLoading
                          ? [
                              _buildLoadingSummaryCard(
                                  'Sales Reps', Icons.people,
                                  gradientStart: Colors.indigo.shade600,
                                  gradientEnd: Colors.indigo.shade800),
                              _buildLoadingSummaryCard('Outlets', Icons.store,
                                  gradientStart: Colors.green.shade600,
                                  gradientEnd: Colors.green.shade800),
                              _buildLoadingSummaryCard(
                                  'Products', Icons.inventory,
                                  gradientStart: Colors.orange.shade600,
                                  gradientEnd: Colors.orange.shade800),
                              _buildLoadingSummaryCard(
                                  'Total Sales', Icons.point_of_sale,
                                  gradientStart: Colors.purple.shade600,
                                  gradientEnd: Colors.purple.shade800),
                              if (crossAxisCount >= 3) ...[
                                _buildLoadingSummaryCard(
                                    'Stock Value', Icons.account_balance_wallet,
                                    gradientStart: Colors.teal.shade600,
                                    gradientEnd: Colors.teal.shade800),
                                _buildLoadingSummaryCard(
                                    'Outstanding', Icons.payment,
                                    gradientStart: Colors.red.shade600,
                                    gradientEnd: Colors.red.shade800),
                              ],
                            ]
                          : [
                              _buildSummaryCard(
                                  'Sales Reps',
                                  '${_dashboardData['salesRepsCount']}',
                                  Icons.people,
                                  gradientStart: Colors.indigo.shade600,
                                  gradientEnd: Colors.indigo.shade800),
                              _buildSummaryCard(
                                  'Outlets',
                                  '${_dashboardData['outletsCount']}',
                                  Icons.store,
                                  gradientStart: Colors.green.shade600,
                                  gradientEnd: Colors.green.shade800),
                              _buildSummaryCard(
                                  'Products',
                                  '${_dashboardData['productsCount']}',
                                  Icons.inventory,
                                  gradientStart: Colors.orange.shade600,
                                  gradientEnd: Colors.orange.shade800),
                              _buildSummaryCard(
                                  'Total Sales',
                                  _formatCurrency(_dashboardData['totalSales']),
                                  Icons.point_of_sale,
                                  gradientStart: Colors.purple.shade600,
                                  gradientEnd: Colors.purple.shade800),
                              if (crossAxisCount >= 3) ...[
                                _buildSummaryCard(
                                    'Stock Value',
                                    _formatCurrency(
                                        _dashboardData['stockValue']),
                                    Icons.account_balance_wallet,
                                    gradientStart: Colors.teal.shade600,
                                    gradientEnd: Colors.teal.shade800),
                                _buildSummaryCard(
                                    'Outstanding',
                                    _formatCurrency(
                                        _dashboardData['outstandingPayments']),
                                    Icons.payment,
                                    gradientStart: Colors.red.shade600,
                                    gradientEnd: Colors.red.shade800),
                              ],
                            ],
                    );
                  },
                ),
                const SizedBox(height: 40),
                _buildSalesAnalyticsSection(),
                const SizedBox(height: 40),
                const Text(
                  'Real-time Alerts',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 24),
                _buildAlertsSection(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
