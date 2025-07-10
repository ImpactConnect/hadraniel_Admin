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
  double get totalRevenue => _sales.fold(0, (sum, sale) => sum + (sale.totalAmount ?? 0));
  double get totalOutstanding => _sales.where((sale) => !(sale.isPaid ?? false)).fold(0, (sum, sale) => sum + (sale.totalAmount ?? 0));
  int get totalReps => _reps.length;
  int get totalProducts => _products.length;
  int get totalSales => _sales.length;
  double get operatingCost => 0; // TODO: Implement operating cost calculation
  int get totalCustomers => _sales.map((sale) => sale.customerId ?? '').where((id) => id.isNotEmpty).toSet().length;

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
        _sales = sales.where((sale) => sale.outletId == widget.outlet.id).toList();
        _lowStockProducts = products.where((product) => (product.quantity ?? 0) < 10).toList();
      });
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

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.outlet.name),
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
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Outlet Information',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const Divider(),
                          ListTile(
                            leading: const Icon(Icons.location_on),
                            title: const Text('Location'),
                            subtitle: Text(widget.outlet.location ?? 'Not specified'),
                          ),
                          ListTile(
                            leading: const Icon(Icons.calendar_today),
                            title: const Text('Created'),
                            subtitle: Text(
                              widget.outlet.createdAt?.toString().split('.')[0] ?? 'Not specified',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Metrics Grid
                  GridView.count(
                    crossAxisCount: 4,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
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
                  const SizedBox(height: 24),

                  // Low Stock Products Section
                  Text(
                    'Low Stock Products',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: _lowStockProducts.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Text('No low stock products'),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _lowStockProducts.length,
                            itemBuilder: (context, index) {
                              final product = _lowStockProducts[index];
                              return ListTile(
                                title: Text(product.name),
                                subtitle: Text('Quantity: ${product.quantity}'),
                                leading: const Icon(Icons.warning, color: Colors.orange),
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 24),

                  // Sales Records Section
                  Text(
                    'Recent Sales',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columns: const [
                          DataColumn(label: Text('Date')),
                          DataColumn(label: Text('Customer')),
                          DataColumn(label: Text('Amount')),
                          DataColumn(label: Text('Status')),
                        ],
                        rows: _sales.map((sale) {
                          return DataRow(
                            cells: [
                              DataCell(Text(sale.createdAt?.toString().split('.')[0] ?? 'No date')),
                              DataCell(Text(sale.customerId ?? 'Unknown')),
                              DataCell(Text('₦${(sale.totalAmount ?? 0).toStringAsFixed(2)}')),
                              DataCell(
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: (sale.isPaid ?? false) ? Colors.green[100] : Colors.red[100],
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    (sale.isPaid ?? false) ? 'Paid' : 'Unpaid',
                                    style: TextStyle(
                                      color: (sale.isPaid ?? false) ? Colors.green[900] : Colors.red[900],
                                    ),
                                  ),
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
            ),
    );
  }
}