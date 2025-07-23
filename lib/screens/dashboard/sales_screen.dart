import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../widgets/dashboard_layout.dart';
import '../../core/services/sync_service.dart';
import '../../core/models/outlet_model.dart';
import '../../core/models/rep_model.dart';
import '../../core/models/product_model.dart';
import '../../core/database/database_helper.dart';

class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  final SyncService _syncService = SyncService();
  bool _isLoading = true;
  List<Map<String, dynamic>> _sales = [];
  Map<String, dynamic> _metrics = {
    'total_sales': 0,
    'total_amount': 0.0,
    'total_paid': 0.0,
    'total_outstanding': 0.0,
    'total_items_sold': 0,
  };

  // Filter options
  String _selectedDateFilter = 'All Time';
  String? _selectedOutletId;
  String? _selectedRepId;
  String? _selectedProductId;

  // Lists for dropdowns
  List<Outlet> _outlets = [];
  List<Rep> _reps = [];
  List<Product> _products = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Load filter options
      await _loadFilterOptions();

      // Load sales with current filters
      await _applyFilters();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading data: $e')));
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadFilterOptions() async {
    final dbHelper = DatabaseHelper();
    final db = await dbHelper.database;

    // Load outlets
    final outletMaps = await db.query('outlets', orderBy: 'name');
    _outlets = outletMaps.map((map) => Outlet.fromMap(map)).toList();

    // Load reps
    final repMaps = await db.query('profiles', orderBy: 'full_name');
    _reps = repMaps.map((map) => Rep.fromMap(map)).toList();

    // Load products
    final productMaps = await db.query('products', orderBy: 'product_name');
    _products = productMaps.map((map) => Product.fromMap(map)).toList();
  }

  Future<void> _applyFilters() async {
    DateTime? startDate;
    DateTime? endDate;

    // Set date range based on selected filter
    final now = DateTime.now();
    switch (_selectedDateFilter) {
      case 'Today':
        startDate = DateTime(now.year, now.month, now.day);
        endDate = startDate.add(const Duration(days: 1));
        break;
      case 'Yesterday':
        startDate = DateTime(now.year, now.month, now.day - 1);
        endDate = DateTime(now.year, now.month, now.day);
        break;
      case 'Last 7 Days':
        startDate = DateTime(now.year, now.month, now.day - 7);
        endDate = DateTime(now.year, now.month, now.day + 1);
        break;
      case 'This Month':
        startDate = DateTime(now.year, now.month, 1);
        endDate = (now.month < 12)
            ? DateTime(now.year, now.month + 1, 1)
            : DateTime(now.year + 1, 1, 1);
        break;
      case 'Last Month':
        startDate = (now.month > 1)
            ? DateTime(now.year, now.month - 1, 1)
            : DateTime(now.year - 1, 12, 1);
        endDate = DateTime(now.year, now.month, 1);
        break;
      default: // All Time
        startDate = null;
        endDate = null;
    }

    // Get sales with applied filters
    _sales = await _syncService.getSalesWithDetails(
      startDate: startDate,
      endDate: endDate,
      outletId: _selectedOutletId,
      repId: _selectedRepId,
      productId: _selectedProductId,
    );

    // Get metrics with the same filters
    _metrics = await _syncService.getSalesMetrics(
      startDate: startDate,
      endDate: endDate,
      outletId: _selectedOutletId,
      repId: _selectedRepId,
      productId: _selectedProductId,
    );
  }

  @override
  Widget build(BuildContext context) {
    return DashboardLayout(
      title: 'Sales',
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: _loadData,
          tooltip: 'Refresh',
        ),
      ],
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildContent(),
    );
  }

  Widget _buildContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFilters(),
        _buildMetricsCards(),
        const SizedBox(height: 16),
        Expanded(child: _buildSalesTable()),
      ],
    );
  }

  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Filters',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              // Date filter
              DropdownButton<String>(
                value: _selectedDateFilter,
                hint: const Text('Date Range'),
                items:
                    [
                      'All Time',
                      'Today',
                      'Yesterday',
                      'Last 7 Days',
                      'This Month',
                      'Last Month',
                    ].map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                onChanged: (newValue) {
                  setState(() {
                    _selectedDateFilter = newValue!;
                  });
                  _applyFilters().then((_) {
                    setState(() {});
                  });
                },
              ),

              // Outlet filter
              DropdownButton<String>(
                value: _selectedOutletId,
                hint: const Text('All Outlets'),
                items: [
                  const DropdownMenuItem<String>(
                    value: null,
                    child: Text('All Outlets'),
                  ),
                  ..._outlets.map((outlet) {
                    return DropdownMenuItem<String>(
                      value: outlet.id,
                      child: Text(outlet.name),
                    );
                  }),
                ],
                onChanged: (newValue) {
                  setState(() {
                    _selectedOutletId = newValue;
                  });
                  _applyFilters().then((_) {
                    setState(() {});
                  });
                },
              ),

              // Rep filter
              DropdownButton<String>(
                value: _selectedRepId,
                hint: const Text('All Reps'),
                items: [
                  const DropdownMenuItem<String>(
                    value: null,
                    child: Text('All Reps'),
                  ),
                  ..._reps.map((rep) {
                    return DropdownMenuItem<String>(
                      value: rep.id,
                      child: Text(rep.fullName),
                    );
                  }),
                ],
                onChanged: (newValue) {
                  setState(() {
                    _selectedRepId = newValue;
                  });
                  _applyFilters().then((_) {
                    setState(() {});
                  });
                },
              ),

              // Product filter
              DropdownButton<String>(
                value: _selectedProductId,
                hint: const Text('All Products'),
                items: [
                  const DropdownMenuItem<String>(
                    value: null,
                    child: Text('All Products'),
                  ),
                  ..._products.map((product) {
                    return DropdownMenuItem<String>(
                      value: product.id,
                      child: Text(product.productName),
                    );
                  }),
                ],
                onChanged: (newValue) {
                  setState(() {
                    _selectedProductId = newValue;
                  });
                  _applyFilters().then((_) {
                    setState(() {});
                  });
                },
              ),

              // Clear filters button
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _selectedDateFilter = 'All Time';
                    _selectedOutletId = null;
                    _selectedRepId = null;
                    _selectedProductId = null;
                  });
                  _applyFilters().then((_) {
                    setState(() {});
                  });
                },
                icon: const Icon(Icons.clear),
                label: const Text('Clear Filters'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade100,
                  foregroundColor: Colors.red.shade900,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsCards() {
    final currencyFormat = NumberFormat.currency(symbol: '₦');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: GridView.count(
        crossAxisCount: MediaQuery.of(context).size.width > 1200 ? 5 : 3,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        shrinkWrap: true,
        childAspectRatio: 1.5,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _buildMetricCard(
            title: 'Total Sales',
            value: _metrics['total_sales'].toString(),
            icon: Icons.receipt_long,
            color: Colors.blue,
          ),
          _buildMetricCard(
            title: 'Total Revenue',
            value: currencyFormat.format(_metrics['total_amount'] ?? 0),
            icon: Icons.attach_money,
            color: Colors.green,
          ),
          _buildMetricCard(
            title: 'Amount Paid',
            value: currencyFormat.format(_metrics['total_paid'] ?? 0),
            icon: Icons.payments,
            color: Colors.purple,
          ),
          _buildMetricCard(
            title: 'Outstanding',
            value: currencyFormat.format(_metrics['total_outstanding'] ?? 0),
            icon: Icons.account_balance_wallet,
            color: Colors.orange,
          ),
          _buildMetricCard(
            title: 'Items Sold',
            value: _metrics['total_items_sold'].toString(),
            icon: Icons.shopping_cart,
            color: Colors.teal,
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 28),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSalesTable() {
    return _sales.isEmpty
        ? Center(child: Text('No sales found for the selected filters'))
        : Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Sales Records',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Column(
                        children: [
                          // Table header
                          Container(
                            color: Theme.of(context).primaryColor,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Row(
                              children: [
                                Expanded(flex: 2, child: _buildFlexHeaderCell('Date')),
                                Expanded(flex: 2, child: _buildFlexHeaderCell('Outlet')),
                                Expanded(flex: 2, child: _buildFlexHeaderCell('Customer')),
                                Expanded(flex: 3, child: _buildFlexHeaderCell('Product Name')),
                                Expanded(flex: 1, child: _buildFlexHeaderCell('Items')),
                                Expanded(flex: 2, child: _buildFlexHeaderCell('Total Amount')),
                                Expanded(flex: 2, child: _buildFlexHeaderCell('Amount Paid')),
                                Expanded(flex: 1, child: _buildFlexHeaderCell('Status')),
                              ],
                            ),
                          ),
                          // Table body
                          Expanded(
                            child: ListView.builder(
                              itemCount: _sales.length,
                              itemBuilder: (context, index) {
                                final sale = _sales[index];
                                final isEven = index % 2 == 0;
                                final dateFormat = DateFormat('MMM d, yyyy');
                                final currencyFormat = NumberFormat.currency(
                                  symbol: '₦',
                                );

                                return Container(
                                  color: isEven
                                      ? Colors.grey.shade50
                                      : Colors.white,
                                  child: Row(
                                    children: [
                                      Expanded(
                                        flex: 2,
                                        child: _buildFlexCell(
                                          sale['created_at'] != null
                                              ? dateFormat.format(
                                                  DateTime.parse(
                                                    sale['created_at'],
                                                  ),
                                                )
                                              : 'N/A',
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: _buildFlexCell(
                                          sale['outlet_name'] ?? 'Unknown',
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: _buildFlexCell(
                                          sale['customer_name'] ?? 'Walk-in',
                                        ),
                                      ),
                                      Expanded(
                                        flex: 3,
                                        child: _buildFlexCell(
                                          sale['product_names'] ?? 'N/A',
                                        ),
                                      ),
                                      Expanded(
                                        flex: 1,
                                        child: _buildFlexCell(
                                          sale['item_count'].toString(),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: _buildFlexCell(
                                          currencyFormat.format(
                                            sale['total_amount'] ?? 0,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: _buildFlexCell(
                                          currencyFormat.format(
                                            sale['amount_paid'] ?? 0,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 1,
                                        child: _buildFlexCell(
                                          sale['is_paid'] == 1
                                              ? 'Paid'
                                              : 'Unpaid',
                                          textColor: sale['is_paid'] == 1
                                              ? Colors.green
                                              : Colors.orange,
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
                  ),
                ),
              ],
            ),
          );
  }

  Widget _buildHeaderCell(String text, double width) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildFlexHeaderCell(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildCell(
    String text,
    double width, {
    Color? textColor,
    Widget? widget,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child:
          widget ??
          Text(
            text,
            style: TextStyle(color: textColor),
            overflow: TextOverflow.ellipsis,
          ),
    );
  }

  Widget _buildFlexCell(
    String text, {
    Color? textColor,
    Widget? widget,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
      child:
          widget ??
          Text(
            text,
            style: TextStyle(color: textColor),
            overflow: TextOverflow.ellipsis,
          ),
    );
  }

  void _showSaleDetails(Map<String, dynamic> sale) async {
    final saleId = sale['id'] as String;
    final saleItems = await _syncService.getSaleItemsWithProductDetails(saleId);
    final currencyFormat = NumberFormat.currency(symbol: '₦');
    final dateFormat = DateFormat('MMMM d, yyyy h:mm a');

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Sale Details - ${dateFormat.format(DateTime.parse(sale['created_at']))}',
        ),
        content: Container(
          width: MediaQuery.of(context).size.width * 0.6,
          height: MediaQuery.of(context).size.height * 0.6,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Sale info
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Outlet: ${sale['outlet_name']}',
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Customer: ${sale['customer_name'] ?? 'Walk-in'}',
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Sales Rep: ${sale['rep_name'] ?? 'N/A'}',
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Status: ${sale['is_paid'] == 1 ? 'Paid' : 'Unpaid'}',
                        style: TextStyle(
                          fontSize: 16,
                          color: sale['is_paid'] == 1
                              ? Colors.green
                              : Colors.orange,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),
              const Text(
                'Items',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),

              // Items table
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      // Table header
                      Container(
                        color: Theme.of(context).primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: _buildDetailHeaderCell('Product'),
                            ),
                            Expanded(child: _buildDetailHeaderCell('Quantity')),
                            Expanded(
                              child: _buildDetailHeaderCell('Unit Price'),
                            ),
                            Expanded(child: _buildDetailHeaderCell('Total')),
                          ],
                        ),
                      ),
                      // Table body
                      Expanded(
                        child: ListView.builder(
                          itemCount: saleItems.length,
                          itemBuilder: (context, index) {
                            final item = saleItems[index];
                            final isEven = index % 2 == 0;

                            return Container(
                              color: isEven
                                  ? Colors.grey.shade50
                                  : Colors.white,
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: _buildDetailCell(
                                      item['product_name'] ?? 'Unknown Product',
                                    ),
                                  ),
                                  Expanded(
                                    child: _buildDetailCell(
                                      item['quantity'].toString(),
                                    ),
                                  ),
                                  Expanded(
                                    child: _buildDetailCell(
                                      currencyFormat.format(item['unit_price'] ?? 0),
                                    ),
                                  ),
                                  Expanded(
                                    child: _buildDetailCell(
                                      currencyFormat.format(item['total'] ?? 0),
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
              ),

              const SizedBox(height: 16),

              // Summary
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Total Amount: ${currencyFormat.format(sale['total_amount'] ?? 0)}',
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Amount Paid: ${currencyFormat.format(sale['amount_paid'] ?? 0)}',
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Outstanding: ${currencyFormat.format(sale['outstanding_amount'] ?? 0)}',
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
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailHeaderCell(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildDetailCell(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Text(text),
    );
  }
}
