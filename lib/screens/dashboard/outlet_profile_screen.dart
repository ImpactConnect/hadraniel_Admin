import 'package:flutter/material.dart';
import '../../core/models/outlet_model.dart';
import '../../core/models/product_model.dart';
import '../../core/models/rep_model.dart';
import '../../core/models/sale_model.dart';
import '../../core/services/sync_service.dart';

class OutletProfileScreen extends StatefulWidget {
  final Outlet outlet;

  const OutletProfileScreen({super.key, required this.outlet});

  @override
  State<OutletProfileScreen> createState() => _OutletProfileScreenState();
}

class _OutletProfileScreenState extends State<OutletProfileScreen> {
  final SyncService _syncService = SyncService();
  bool _isLoading = false;
  List<Rep> _reps = [];
  List<Product> _products = [];
  List<Sale> _sales = [];
  List<Product> _lowStockProducts = [];

  // Metrics
  double get totalRevenue =>
      _sales.fold(0, (sum, sale) => sum + (sale.totalAmount ?? 0));
  double get totalOutstanding => _sales
      .where((sale) => !(sale.isPaid ?? false))
      .fold(0, (sum, sale) => sum + (sale.totalAmount ?? 0));
  int get totalReps => _reps.length;
  int get totalProducts => _products.length;
  int get totalSales => _sales.length;
  double get operatingCost => 0; // TODO: Implement operating cost calculation
  int get totalCustomers => _sales
      .map((sale) => sale.customerId ?? '')
      .where((id) => id.isNotEmpty)
      .toSet()
      .length;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final reps = await _syncService.getAllLocalReps();
      final products = await _syncService.getAllLocalProducts();
      final sales = await _syncService.getAllLocalSales();

      setState(() {
        _reps = reps.where((rep) => rep.outletId == widget.outlet.id).toList();
        _products = products;
        _sales =
            sales.where((sale) => sale.outletId == widget.outlet.id).toList();
        _lowStockProducts =
            products.where((product) => (product.quantity ?? 0) < 10).toList();
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

  // Helper method to build section titles
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 24, 0, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildMetricCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      elevation: 2,
      shadowColor: color.withOpacity(0.2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color.withOpacity(0.7), color.withOpacity(0.5)],
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, size: 18, color: Colors.white),
              ),
              const SizedBox(height: 6),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                title,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontWeight: FontWeight.w500,
                  fontSize: 10,
                ),
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
    final primaryColor = theme.colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.outlet.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: primaryColor,
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Outlet Info Card
                  Card(
                    elevation: 4,
                    shadowColor: Colors.black.withOpacity(0.1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: primaryColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.store,
                                  size: 32,
                                  color: primaryColor,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Outlet Information',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: primaryColor,
                                      ),
                                    ),
                                    Text(
                                      'Details about this outlet',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 24),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: ListTile(
                                  leading: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.location_on,
                                      color: Colors.blue,
                                    ),
                                  ),
                                  title: const Text(
                                    'Location',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                      fontSize: 16,
                                    ),
                                  ),
                                  subtitle: Text(
                                    widget.outlet.location ?? 'Not specified',
                                    style: const TextStyle(fontSize: 15),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: ListTile(
                                  leading: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.calendar_today,
                                      color: Colors.orange,
                                    ),
                                  ),
                                  title: const Text(
                                    'Created',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                      fontSize: 16,
                                    ),
                                  ),
                                  subtitle: Text(
                                    widget.outlet.createdAt?.toString().split(
                                              '.',
                                            )[0] ??
                                        'Not specified',
                                    style: const TextStyle(fontSize: 15),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: ListTile(
                                  leading: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.green.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.people,
                                      color: Colors.green,
                                    ),
                                  ),
                                  title: const Text(
                                    'Assigned Reps',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                      fontSize: 16,
                                    ),
                                  ),
                                  subtitle: _reps.isEmpty
                                      ? const Text(
                                          'No reps assigned',
                                          style: TextStyle(fontSize: 15),
                                        )
                                      : Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: _reps
                                              .map(
                                                (rep) => Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                    bottom: 4,
                                                  ),
                                                  child: Text(
                                                    rep.fullName ??
                                                        'Unnamed Rep',
                                                    style: const TextStyle(
                                                      fontSize: 15,
                                                    ),
                                                  ),
                                                ),
                                              )
                                              .toList(),
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Metrics Section
                  _buildSectionTitle('Performance Metrics'),

                  // Metrics Grid
                  GridView.count(
                    crossAxisCount: 5,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 1.1,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _buildMetricCard(
                        'Total Revenue',
                        '₦${totalRevenue.toStringAsFixed(2)}',
                        Icons.attach_money,
                        Colors.green,
                      ),
                      _buildMetricCard(
                        'Outstanding',
                        '₦${totalOutstanding.toStringAsFixed(2)}',
                        Icons.money_off,
                        Colors.red,
                      ),
                      _buildMetricCard(
                        'Total Reps',
                        totalReps.toString(),
                        Icons.people,
                        Colors.blue,
                      ),
                      _buildMetricCard(
                        'Total Products',
                        totalProducts.toString(),
                        Icons.inventory,
                        Colors.orange,
                      ),
                      _buildMetricCard(
                        'Total Sales',
                        totalSales.toString(),
                        Icons.point_of_sale,
                        Colors.purple,
                      ),
                      _buildMetricCard(
                        'Operating Cost',
                        '₦${operatingCost.toStringAsFixed(2)}',
                        Icons.account_balance_wallet,
                        Colors.brown,
                      ),
                      _buildMetricCard(
                        'Customers',
                        totalCustomers.toString(),
                        Icons.group,
                        Colors.teal,
                      ),
                    ],
                  ),

                  // Low Stock Products Section
                  _buildSectionTitle('Low Stock Products'),
                  Card(
                    elevation: 3,
                    shadowColor: Colors.black.withOpacity(0.1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: _lowStockProducts.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Center(
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.inventory_2_outlined,
                                    size: 48,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No low stock products',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey[600],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'All products have sufficient stock levels',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[500],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _lowStockProducts.length,
                            itemBuilder: (context, index) {
                              final product = _lowStockProducts[index];
                              return ListTile(
                                title: Text(
                                  product.productName ?? 'Unnamed Product',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                subtitle: Text('Quantity: ${product.quantity}'),
                                leading: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.warning,
                                    color: Colors.orange,
                                  ),
                                ),
                                trailing: product.quantity == 0
                                    ? Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.red.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: const Text(
                                          'Out of Stock',
                                          style: TextStyle(
                                            color: Colors.red,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      )
                                    : Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.orange.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: const Text(
                                          'Low Stock',
                                          style: TextStyle(
                                            color: Colors.orange,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                              );
                            },
                          ),
                  ),

                  // Sales Records Section
                  _buildSectionTitle('Recent Sales'),
                  Card(
                    elevation: 3,
                    shadowColor: Colors.black.withOpacity(0.1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: _sales.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Center(
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.point_of_sale_outlined,
                                    size: 48,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No sales records',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey[600],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Sales will appear here once they are made',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[500],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : Column(
                            children: [
                              // Table Header
                              Container(
                                decoration: BoxDecoration(
                                  color: primaryColor,
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(16),
                                    topRight: Radius.circular(16),
                                  ),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                  horizontal: 16,
                                ),
                                child: Row(
                                  children: const [
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        'Date',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        'Customer',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        'Amount',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Table Body
                              ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _sales.length,
                                itemBuilder: (context, index) {
                                  final sale = _sales[index];
                                  final isEven = index % 2 == 0;

                                  return Container(
                                    color: isEven
                                        ? Colors.grey.shade50
                                        : Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                      horizontal: 16,
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          flex: 2,
                                          child: Text(
                                            sale.createdAt?.toString().split(
                                                      '.',
                                                    )[0] ??
                                                'No date',
                                          ),
                                        ),
                                        Expanded(
                                          flex: 2,
                                          child: Text(
                                            sale.customerId ?? 'Unknown',
                                          ),
                                        ),
                                        Expanded(
                                          flex: 2,
                                          child: Text(
                                            '₦${(sale.totalAmount ?? 0).toStringAsFixed(2)}',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w500,
                                              color: (sale.totalAmount ?? 0) > 0
                                                  ? Colors.green[700]
                                                  : Colors.grey[600],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}
