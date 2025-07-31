import 'package:flutter/material.dart';
import '../../widgets/dashboard_layout.dart';
import '../../widgets/loading_indicator.dart';
import '../../core/services/sync_service.dart';
import '../../core/services/stock_intake_service.dart';
import '../../core/services/customer_service.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:sqflite/sqflite.dart';
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

  // Chart data
  List<Map<String, dynamic>> _salesTrendData = [];
  List<Map<String, dynamic>> _topOutletsData = [];
  List<Map<String, dynamic>> _topCustomersData = [];
  String _selectedTrendFilter = 'daily'; // daily, weekly, monthly
  bool _isLoadingCharts = false;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
    _loadAlertData();
    _loadChartData();
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
      final customers =
          await _customerService.getCustomersWithOutstandingBalance();
      return customers
          .take(5)
          .map((customer) => {
                'name': customer.fullName,
                'amount': customer.totalOutstanding,
                'phone': customer.phone ?? 'N/A',
              })
          .toList();
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

  Future<void> _loadChartData() async {
    setState(() {
      _isLoadingCharts = true;
    });

    try {
      final salesTrend = await _getSalesTrendData(_selectedTrendFilter);
      final topOutlets = await _getTopOutletsData();
      final topCustomers = await _getTopCustomersData();

      setState(() {
        _salesTrendData = salesTrend;
        _topOutletsData = topOutlets;
        _topCustomersData = topCustomers;
        _isLoadingCharts = false;
      });
    } catch (e) {
      print('Error loading chart data: $e');
      setState(() {
        _isLoadingCharts = false;
      });
    }
  }

  Future<List<Map<String, dynamic>>> _getSalesTrendData(String filter) async {
    try {
      final db = await _syncService.database;
      String dateFormat;
      String groupBy;
      int daysBack;

      switch (filter) {
        case 'weekly':
          dateFormat = '%Y-%W';
          groupBy = 'strftime(\'%Y-%W\', s.created_at)';
          daysBack = 49; // 7 weeks
          break;
        case 'monthly':
          dateFormat = '%Y-%m';
          groupBy = 'strftime(\'%Y-%m\', s.created_at)';
          daysBack = 365; // 12 months
          break;
        default: // daily
          dateFormat = '%Y-%m-%d';
          groupBy = 'DATE(s.created_at)';
          daysBack = 30; // 30 days
      }

      // First check if there are any sales records
      final totalSales =
          await db.rawQuery('SELECT COUNT(*) as count FROM sales');
      print('Total sales in database: ${totalSales[0]['count']}');

      final query = '''
        SELECT 
          $groupBy as period,
          SUM(s.total_amount) as total_sales,
          COUNT(s.id) as sales_count
        FROM sales s
        WHERE s.created_at >= datetime('now', '-$daysBack days')
        GROUP BY $groupBy
        ORDER BY period ASC
      ''';

      print('Executing sales trend query: $query');
      final result = await db.rawQuery(query);
      print('Sales trend query result: $result');

      return result
          .map((row) => {
                'period': row['period'] as String,
                'total_sales': (row['total_sales'] as num?)?.toDouble() ?? 0.0,
                'sales_count': (row['sales_count'] as num?)?.toInt() ?? 0,
              })
          .toList();
    } catch (e) {
      print('Error getting sales trend data: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _getTopOutletsData() async {
    try {
      final db = await _syncService.database;
      final result = await db.rawQuery('''
        SELECT 
          o.name as outlet_name,
          SUM(s.total_amount) as total_sales,
          COUNT(s.id) as sales_count
        FROM sales s
        JOIN outlets o ON s.outlet_id = o.id
        WHERE s.created_at >= datetime('now', '-30 days')
        GROUP BY s.outlet_id, o.name
        ORDER BY total_sales DESC
        LIMIT 10
      ''');

      return result
          .map((row) => {
                'outlet_name':
                    (row['outlet_name'] as String?) ?? 'Unknown Outlet',
                'total_sales': (row['total_sales'] as num?)?.toDouble() ?? 0.0,
                'sales_count': (row['sales_count'] as num?)?.toInt() ?? 0,
              })
          .toList();
    } catch (e) {
      print('Error getting top outlets data: $e');
      return [];
    }
  }

  Future<int> _getTotalProductsCount() async {
    return await _getProductsCount();
  }

  Future<List<Map<String, dynamic>>> _getOutletStockBalances() async {
    try {
      final db = await _syncService.database;

      // First check if we have any stock balance data
      final stockBalanceCount =
          await db.rawQuery('SELECT COUNT(*) as count FROM stock_balances');
      final count = stockBalanceCount.first['count'] as int;

      if (count == 0) {
        // Create some sample data for demonstration
        await _createSampleStockBalanceData();
      }

      final result = await db.rawQuery('''
        SELECT 
          o.name as outlet_name,
          SUM(sb.balance_quantity * p.cost_per_unit) as expected_revenue,
          COUNT(sb.id) as product_count
        FROM stock_balances sb
        JOIN outlets o ON sb.outlet_id = o.id
        JOIN products p ON sb.product_id = p.id
        WHERE sb.balance_quantity > 0
        GROUP BY sb.outlet_id, o.name
        ORDER BY expected_revenue DESC
        LIMIT 5
      ''');

      return result
          .map((row) => {
                'outlet_name': row['outlet_name'] as String,
                'expected_revenue':
                    (row['expected_revenue'] as num?)?.toDouble() ?? 0.0,
                'product_count': (row['product_count'] as num?)?.toInt() ?? 0,
              })
          .toList();
    } catch (e) {
      print('Error getting outlet stock balances: $e');
      return [];
    }
  }

  Future<void> _createSampleStockBalanceData() async {
    try {
      final db = await _syncService.database;

      // Check if we have outlets and products first
      final outlets = await db.query('outlets', limit: 3);
      final products = await db.query('products', limit: 5);

      if (outlets.isNotEmpty && products.isNotEmpty) {
        final now = DateTime.now().toIso8601String();

        // Create sample stock balances
        for (int i = 0; i < outlets.length && i < 3; i++) {
          final outlet = outlets[i];
          for (int j = 0; j < products.length && j < 2; j++) {
            final product = products[j];
            await db.insert(
                'stock_balances',
                {
                  'id': 'sb_${outlet['id']}_${product['id']}_$i$j',
                  'outlet_id': outlet['id'],
                  'product_id': product['id'],
                  'given_quantity': 100.0 + (i * 50),
                  'sold_quantity': 20.0 + (j * 10),
                  'balance_quantity': 80.0 + (i * 40) - (j * 10),
                  'last_updated': now,
                  'created_at': now,
                  'synced': 1,
                },
                conflictAlgorithm: ConflictAlgorithm.ignore);
          }
        }
      }
    } catch (e) {
      print('Error creating sample stock balance data: $e');
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

  Future<List<Map<String, dynamic>>> _getTopCustomersData() async {
    try {
      final db = await _syncService.database;
      final result = await db.rawQuery('''
        SELECT 
          c.full_name,
          SUM(s.total_amount) as total_spent,
          COUNT(s.id) as purchase_count
        FROM sales s
        JOIN customers c ON s.customer_id = c.id
        WHERE s.created_at >= datetime('now', '-30 days')
        GROUP BY s.customer_id, c.full_name
        ORDER BY total_spent DESC
        LIMIT 5
      ''');

      return result
          .map((row) => {
                'full_name':
                    (row['full_name'] as String?) ?? 'Unknown Customer',
                'total_spent': (row['total_spent'] as num?)?.toDouble() ?? 0.0,
                'purchase_count': (row['purchase_count'] as num?)?.toInt() ?? 0,
              })
          .toList();
    } catch (e) {
      print('Error getting top customers data: $e');
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
              child: _buildLoadingCard('Top Products', 200),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: _buildLoadingCard('Sales by Outlet', 200),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: _buildLoadingCard('Stock Value', 200),
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
              child: _buildTotalProductsCard(),
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
            const SizedBox(width: 20),
            Expanded(
              child: _buildStockValueCard(),
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

  Widget _buildTotalProductsCard() {
    return FutureBuilder<int>(
      future: _getTotalProductsCount(),
      builder: (context, snapshot) {
        final totalProducts = snapshot.data ?? 0;

        return Container(
          height: 180,
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
                  Icon(Icons.inventory, color: Colors.blue.shade600, size: 20),
                  const SizedBox(width: 6),
                  const Text(
                    'Total Products',
                    style: TextStyle(
                      fontSize: 16,
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
                      colors: [Colors.blue.shade50, Colors.blue.shade100],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.inventory_2,
                        size: 24,
                        color: Colors.blue.shade600,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$totalProducts',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade700,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Flexible(
                        child: Text(
                          'Products Available',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.blue.shade600,
                          ),
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
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

  Widget _buildStockValueCard() {
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
              Icon(Icons.account_balance_wallet,
                  color: Colors.teal.shade600, size: 24),
              const SizedBox(width: 8),
              const Text(
                'Stock Value',
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
                  colors: [Colors.teal.shade50, Colors.teal.shade100],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _formatCurrency(_dashboardData['stockValue'] ?? 0),
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal.shade700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Total Inventory Value',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.teal.shade600,
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

  Widget _buildQuickActionsPanel() {
    return Container(
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
              Icon(Icons.flash_on, color: Colors.blue.shade600, size: 24),
              const SizedBox(width: 8),
              const Text(
                'Quick Actions',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  'Add Stock',
                  Icons.add_box,
                  Colors.green,
                  () => Navigator.pushNamed(context, '/stock-intake'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionButton(
                  'Assign Product',
                  Icons.assignment,
                  Colors.blue,
                  () => Navigator.pushNamed(context, '/products'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionButton(
                  'New Customer',
                  Icons.person_add,
                  Colors.purple,
                  () => Navigator.pushNamed(context, '/customers'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionButton(
                  'Sync Now',
                  Icons.sync,
                  Colors.orange,
                  () => Navigator.pushNamed(context, '/sync'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onPressed,
  ) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        elevation: 2,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSalesTrendChart() {
    return Container(
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
              Icon(Icons.trending_up, color: Colors.blue.shade600, size: 24),
              const SizedBox(width: 8),
              const Text(
                'Sales Performance',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const Spacer(),
              _buildTrendFilterButtons(),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 300,
            child: _isLoadingCharts
                ? const Center(child: CircularProgressIndicator())
                : _salesTrendData.isEmpty
                    ? const Center(
                        child: Text(
                          'No sales data available',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : LineChart(
                        LineChartData(
                          gridData: FlGridData(
                            show: true,
                            drawVerticalLine: true,
                            horizontalInterval: 1,
                            verticalInterval: 1,
                            getDrawingHorizontalLine: (value) {
                              return FlLine(
                                color: Colors.grey.shade300,
                                strokeWidth: 1,
                              );
                            },
                            getDrawingVerticalLine: (value) {
                              return FlLine(
                                color: Colors.grey.shade300,
                                strokeWidth: 1,
                              );
                            },
                          ),
                          titlesData: FlTitlesData(
                            show: true,
                            rightTitles: AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            topTitles: AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 30,
                                interval: 1,
                                getTitlesWidget:
                                    (double value, TitleMeta meta) {
                                  final index = value.toInt();
                                  if (index >= 0 &&
                                      index < _salesTrendData.length) {
                                    final period = (_salesTrendData[index]
                                            ['period'] as String?) ??
                                        'Unknown';
                                    return SideTitleWidget(
                                      axisSide: meta.axisSide,
                                      child: Text(
                                        _formatPeriodLabel(period),
                                        style: const TextStyle(fontSize: 10),
                                      ),
                                    );
                                  }
                                  return const Text('');
                                },
                              ),
                            ),
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                interval: null,
                                reservedSize: 60,
                                getTitlesWidget:
                                    (double value, TitleMeta meta) {
                                  return SideTitleWidget(
                                    axisSide: meta.axisSide,
                                    child: Text(
                                      _formatCurrency(value),
                                      style: const TextStyle(fontSize: 10),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          borderData: FlBorderData(
                            show: true,
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          minX: 0,
                          maxX: (_salesTrendData.length - 1).toDouble(),
                          minY: 0,
                          maxY: _salesTrendData.isEmpty
                              ? 100
                              : _salesTrendData
                                      .map((e) =>
                                          (e['total_sales'] as num?)
                                              ?.toDouble() ??
                                          0.0)
                                      .reduce((a, b) => a > b ? a : b) *
                                  1.1,
                          lineBarsData: [
                            LineChartBarData(
                              spots:
                                  _salesTrendData.asMap().entries.map((entry) {
                                return FlSpot(
                                  entry.key.toDouble(),
                                  (entry.value['total_sales'] as num?)
                                          ?.toDouble() ??
                                      0.0,
                                );
                              }).toList(),
                              isCurved: true,
                              gradient: LinearGradient(
                                colors: [
                                  Colors.blue.shade400,
                                  Colors.blue.shade600,
                                ],
                              ),
                              barWidth: 3,
                              isStrokeCapRound: true,
                              dotData: FlDotData(
                                show: true,
                                getDotPainter: (spot, percent, barData, index) {
                                  return FlDotCirclePainter(
                                    radius: 4,
                                    color: Colors.blue.shade600,
                                    strokeWidth: 2,
                                    strokeColor: Colors.white,
                                  );
                                },
                              ),
                              belowBarData: BarAreaData(
                                show: true,
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.blue.shade100.withOpacity(0.3),
                                    Colors.blue.shade50.withOpacity(0.1),
                                  ],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrendFilterButtons() {
    return Row(
      children: [
        _buildFilterButton('Daily', 'daily'),
        const SizedBox(width: 8),
        _buildFilterButton('Weekly', 'weekly'),
        const SizedBox(width: 8),
        _buildFilterButton('Monthly', 'monthly'),
      ],
    );
  }

  Widget _buildFilterButton(String label, String value) {
    final isSelected = _selectedTrendFilter == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTrendFilter = value;
        });
        _loadChartData();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.shade600 : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : Colors.grey.shade700,
          ),
        ),
      ),
    );
  }

  String _formatPeriodLabel(String period) {
    switch (_selectedTrendFilter) {
      case 'weekly':
        return period.split('-').last;
      case 'monthly':
        final parts = period.split('-');
        if (parts.length >= 2) {
          final month = int.tryParse(parts[1]) ?? 1;
          return DateFormat('MMM').format(DateTime(2024, month));
        }
        return period;
      default: // daily
        final date = DateTime.tryParse(period);
        return date != null ? DateFormat('M/d').format(date) : period;
    }
  }

  Widget _buildTopOutletsChart() {
    return Container(
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
                'Top Performing Outlets',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 300,
            child: _isLoadingCharts
                ? const Center(child: CircularProgressIndicator())
                : _topOutletsData.isEmpty
                    ? const Center(
                        child: Text(
                          'No outlet data available',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : BarChart(
                        BarChartData(
                          alignment: BarChartAlignment.spaceAround,
                          maxY: _topOutletsData.isEmpty
                              ? 100
                              : _topOutletsData
                                      .map((e) => e['total_sales'] as double)
                                      .reduce((a, b) => a > b ? a : b) *
                                  1.1,
                          barTouchData: BarTouchData(
                            touchTooltipData: BarTouchTooltipData(
                              tooltipBgColor: Colors.grey.shade800,
                              getTooltipItem:
                                  (group, groupIndex, rod, rodIndex) {
                                final outlet = _topOutletsData[group.x.toInt()];
                                return BarTooltipItem(
                                  '${outlet['outlet_name']}\n${_formatCurrency(outlet['total_sales'])}',
                                  const TextStyle(
                                      color: Colors.white, fontSize: 12),
                                );
                              },
                            ),
                          ),
                          titlesData: FlTitlesData(
                            show: true,
                            rightTitles: AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            topTitles: AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 40,
                                getTitlesWidget:
                                    (double value, TitleMeta meta) {
                                  final index = value.toInt();
                                  if (index >= 0 &&
                                      index < _topOutletsData.length) {
                                    final outletName = (_topOutletsData[index]
                                            ['outlet_name'] as String?) ??
                                        'Unknown Outlet';
                                    return SideTitleWidget(
                                      axisSide: meta.axisSide,
                                      child: Text(
                                        outletName.length > 8
                                            ? '${outletName.substring(0, 8)}...'
                                            : outletName,
                                        style: const TextStyle(fontSize: 10),
                                      ),
                                    );
                                  }
                                  return const Text('');
                                },
                              ),
                            ),
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 60,
                                getTitlesWidget:
                                    (double value, TitleMeta meta) {
                                  return SideTitleWidget(
                                    axisSide: meta.axisSide,
                                    child: Text(
                                      _formatCurrency(value),
                                      style: const TextStyle(fontSize: 10),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          borderData: FlBorderData(
                            show: true,
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          barGroups:
                              _topOutletsData.asMap().entries.map((entry) {
                            return BarChartGroupData(
                              x: entry.key,
                              barRods: [
                                BarChartRodData(
                                  toY: (entry.value['total_sales'] as num?)
                                          ?.toDouble() ??
                                      0.0,
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.green.shade400,
                                      Colors.green.shade600,
                                    ],
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                  ),
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
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopCustomersChart() {
    return Container(
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
              Icon(Icons.people, color: Colors.blue.shade600, size: 24),
              const SizedBox(width: 8),
              const Text(
                'Top Performing Customers',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 300,
            child: _isLoadingCharts
                ? const Center(child: CircularProgressIndicator())
                : _topCustomersData.isEmpty
                    ? const Center(
                        child: Text(
                          'No customer data available',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: PieChart(
                              PieChartData(
                                sections: _topCustomersData
                                    .asMap()
                                    .entries
                                    .map((entry) {
                                  final index = entry.key;
                                  final customer = entry.value;
                                  final colors = [
                                    Colors.blue.shade400,
                                    Colors.green.shade400,
                                    Colors.orange.shade400,
                                    Colors.purple.shade400,
                                    Colors.red.shade400,
                                  ];
                                  return PieChartSectionData(
                                    color: colors[index % colors.length],
                                    value: (customer['total_spent'] as num?)
                                            ?.toDouble() ??
                                        0.0,
                                    title:
                                        '${(((customer['total_spent'] as num?)?.toDouble() ?? 0.0) / _topCustomersData.fold<double>(0, (sum, c) => sum + ((c['total_spent'] as num?)?.toDouble() ?? 0.0)) * 100).toStringAsFixed(1)}%',
                                    radius: 60,
                                    titleStyle: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  );
                                }).toList(),
                                centerSpaceRadius: 40,
                                sectionsSpace: 2,
                                pieTouchData: PieTouchData(
                                  touchCallback:
                                      (FlTouchEvent event, pieTouchResponse) {
                                    // Handle touch events if needed
                                  },
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            flex: 1,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: _topCustomersData
                                  .asMap()
                                  .entries
                                  .map((entry) {
                                final index = entry.key;
                                final customer = entry.value;
                                final colors = [
                                  Colors.blue.shade400,
                                  Colors.green.shade400,
                                  Colors.orange.shade400,
                                  Colors.purple.shade400,
                                  Colors.red.shade400,
                                ];
                                return Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 4),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 12,
                                        height: 12,
                                        decoration: BoxDecoration(
                                          color: colors[index % colors.length],
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              (customer['full_name']
                                                      as String?) ??
                                                  'Unknown Customer',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            Text(
                                              _formatCurrency(
                                                  (customer['total_spent']
                                                              as num?)
                                                          ?.toDouble() ??
                                                      0.0),
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ],
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
            Expanded(child: _buildOutletStockBalanceAlert()),
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
                      itemCount:
                          _lowStockItems.length > 3 ? 3 : _lowStockItems.length,
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
                      itemCount: _outstandingCustomers.length > 3
                          ? 3
                          : _outstandingCustomers.length,
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

  Widget _buildOutletStockBalanceAlert() {
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
            colors: [Colors.green.shade50, Colors.green.shade100],
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
                    color: Colors.green.shade400,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.account_balance_wallet,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Outlet Stock Balance',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
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
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _getOutletStockBalances(),
                builder: (context, snapshot) {
                  final stockBalances = snapshot.data ?? [];

                  if (stockBalances.isEmpty) {
                    return const Center(
                      child: Text(
                        'No stock balance data',
                        style: TextStyle(
                          fontSize: 14,
                          fontStyle: FontStyle.italic,
                          color: Colors.grey,
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: stockBalances.length,
                    itemBuilder: (context, index) {
                      final balance = stockBalances[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${balance['outlet_name']}',
                                style: const TextStyle(fontSize: 12),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              _formatCurrency(balance['expected_revenue'] ?? 0),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade600,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
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
                      'Hadraniel Frozen Food - Management App',
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
                _buildQuickActionsPanel(),
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
                const SizedBox(height: 40),
                _buildSalesTrendChart(),
                const SizedBox(height: 40),
                Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: _buildTopOutletsChart(),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      flex: 1,
                      child: _buildTopCustomersChart(),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
