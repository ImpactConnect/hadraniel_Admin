import 'package:flutter/material.dart';
import '../../core/models/outlet_model.dart';
import '../../core/models/product_model.dart';
import '../../core/models/stock_balance_model.dart';
import '../../core/services/stock_service.dart';
import '../../core/services/sync_service.dart';
import '../../widgets/dashboard_layout.dart';
import '../../widgets/loading_overlay.dart';

class StockScreen extends StatefulWidget {
  const StockScreen({super.key});

  @override
  State<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends State<StockScreen> {
  final StockService _stockService = StockService();
  final SyncService _syncService = SyncService();
  
  List<StockBalance> _stockBalances = [];
  List<Outlet> _outlets = [];
  List<Product> _products = [];
  bool _isLoading = false;
  bool _isSyncing = false;
  
  // Filters
  String _searchQuery = '';
  String? _selectedOutletId;
  String? _selectedProductId;
  DateTime? _startDate;
  DateTime? _endDate;
  String _activeDateFilter = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final stockBalances = await _stockService.getStockBalances(
        startDate: _startDate,
        endDate: _endDate,
        outletId: _selectedOutletId,
        productId: _selectedProductId,
      );
      final outlets = await _syncService.getAllLocalOutlets();
      final products = await _syncService.getAllLocalProducts();

      setState(() {
        _stockBalances = stockBalances;
        _outlets = outlets;
        _products = products;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e')),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  Future<void> _syncData() async {
    setState(() => _isSyncing = true);
    try {
      await _syncService.syncStockBalancesToLocalDb();
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Stock data synced successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error syncing data: $e')),
        );
      }
    } finally {
      setState(() => _isSyncing = false);
    }
  }

  void _setDateFilter(String filter) {
    final now = DateTime.now();
    setState(() {
      _activeDateFilter = filter;
      switch (filter) {
        case 'Today':
          _startDate = DateTime(now.year, now.month, now.day);
          _endDate = now;
          break;
        case 'Yesterday':
          _startDate = DateTime(now.year, now.month, now.day - 1);
          _endDate = DateTime(now.year, now.month, now.day);
          break;
        case 'This week':
          _startDate = DateTime(now.year, now.month, now.day - now.weekday + 1);
          _endDate = now;
          break;
        case 'Last 7 days':
          _startDate = DateTime(now.year, now.month, now.day - 7);
          _endDate = now;
          break;
        case 'This month':
          _startDate = DateTime(now.year, now.month, 1);
          _endDate = now;
          break;
        case 'Last month':
          _startDate = DateTime(now.year, now.month - 1, 1);
          _endDate = DateTime(now.year, now.month, 0);
          break;
      }
      _loadData();
    });
  }

  void _clearDateFilter() {
    setState(() {
      _activeDateFilter = '';
      _startDate = null;
      _endDate = null;
      _loadData();
    });
  }

  Future<void> _showDateRangePicker() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
        _activeDateFilter = '${picked.start.toString().split(' ')[0]} to '
            '${picked.end.toString().split(' ')[0]}';
        _loadData();
      });
    }
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: color, size: 24),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: TextStyle(color: color.withOpacity(0.8)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(color: color, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredStockBalances = _stockBalances.where((stock) {
      final product = _products.firstWhere(
        (p) => p.id == stock.productId,
        orElse: () => Product(
          id: stock.productId,
          productName: 'Unknown',
          quantity: 0,
          unit: 'N/A',
          costPerUnit: 0,
          totalCost: 0,
          dateAdded: DateTime.now(),
          outletId: '',
          createdAt: DateTime.now(),
          isSynced: false
        ),
      );
      final outlet = _outlets.firstWhere(
        (o) => o.id == stock.outletId,
        orElse: () => Outlet(
          id: stock.outletId,
          name: 'Unknown',
          createdAt: null,
        ),
      );
      
      return product.productName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          outlet.name.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return DashboardLayout(
      title: 'Stock Management',
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: _isSyncing
                      ? const CircularProgressIndicator()
                      : const Icon(Icons.sync),
                  onPressed: _isSyncing ? null : _syncData,
                  tooltip: 'Sync Stock Data',
                ),
              ],
            ),
          ),
          if (_isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        _buildMetricCard(
                          'Total Stock Value',
                          '₦${filteredStockBalances.fold(0.0, (sum, stock) => sum + (stock.totalGivenValue ?? 0)).toStringAsFixed(2)}',
                          Icons.inventory,
                          Colors.blue,
                        ),
                        const SizedBox(width: 16),
                        _buildMetricCard(
                          'Total Stock Quantity',
                          filteredStockBalances.fold(0.0, (sum, stock) => sum + stock.givenQuantity).toString(),
                          Icons.shopping_cart,
                          Colors.green,
                        ),
                        const SizedBox(width: 16),
                        _buildMetricCard(
                          'Total Sold Quantity',
                          filteredStockBalances.fold(0.0, (sum, stock) => sum + stock.soldQuantity).toString(),
                          Icons.point_of_sale,
                          Colors.orange,
                        ),
                        const SizedBox(width: 16),
                        _buildMetricCard(
                          'Balance Value',
                          '₦${filteredStockBalances.fold(0.0, (sum, stock) => sum + (stock.balanceValue ?? 0)).toStringAsFixed(2)}',
                          Icons.account_balance_wallet,
                          Colors.purple,
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              ...["Today", "Yesterday", "This week", "Last 7 days", "This month", "Last month"].map(
                                (filter) => Padding(
                                  padding: const EdgeInsets.only(right: 8.0),
                                  child: FilterChip(
                                    label: Text(filter),
                                    selected: _activeDateFilter == filter,
                                    onSelected: (selected) {
                                      if (selected) {
                                        _setDateFilter(filter);
                                      } else {
                                        _clearDateFilter();
                                      }
                                    },
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: ActionChip(
                                  avatar: const Icon(Icons.date_range, size: 18),
                                  label: Text(
                                    _activeDateFilter.isEmpty ? 'Select Date' : _activeDateFilter,
                                  ),
                                  onPressed: _showDateRangePicker,
                                ),
                              ),
                              if (_activeDateFilter.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(right: 8.0),
                                  child: ActionChip(
                                    avatar: const Icon(Icons.clear, size: 18),
                                    label: const Text('Clear Filter'),
                                    onPressed: _clearDateFilter,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                decoration: const InputDecoration(
                                  labelText: 'Search Stock',
                                  prefixIcon: Icon(Icons.search),
                                  border: OutlineInputBorder(),
                                ),
                                onChanged: (value) => setState(() => _searchQuery = value),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _selectedOutletId,
                                decoration: const InputDecoration(
                                  labelText: 'Filter by Outlet',
                                  border: OutlineInputBorder(),
                                ),
                                items: [
                                  const DropdownMenuItem(
                                    value: null,
                                    child: Text('All Outlets'),
                                  ),
                                  ..._outlets.map(
                                    (outlet) => DropdownMenuItem(
                                      value: outlet.id,
                                      child: Text(outlet.name),
                                    ),
                                  ),
                                ],
                                onChanged: (value) {
                                  setState(() {
                                    _selectedOutletId = value;
                                    _loadData();
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _selectedProductId,
                                decoration: const InputDecoration(
                                  labelText: 'Filter by Product',
                                  border: OutlineInputBorder(),
                                ),
                                items: [
                                  const DropdownMenuItem(
                                    value: null,
                                    child: Text('All Products'),
                                  ),
                                  ..._products.map(
                                    (product) => DropdownMenuItem(
                                      value: product.id,
                                      child: Text(product.productName),
                                    ),
                                  ),
                                ],
                                onChanged: (value) {
                                  setState(() {
                                    _selectedProductId = value;
                                    _loadData();
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SingleChildScrollView(
                        child: DataTable(
                          columns: const [
                            DataColumn(label: Text('Product Name')),
                            DataColumn(label: Text('Outlet')),
                            DataColumn(label: Text('Given Qty')),
                            DataColumn(label: Text('Sold Qty')),
                            DataColumn(label: Text('Balance')),
                            DataColumn(label: Text('Cost/Unit')),
                            DataColumn(label: Text('Total Value')),
                            DataColumn(label: Text('Date Updated')),
                          ],
                          rows: filteredStockBalances.map((stock) {
                            final product = _products.firstWhere(
                              (p) => p.id == stock.productId,
                              orElse: () => Product(
                                id: stock.productId,
                                productName: 'Unknown',
                                quantity: 0,
                                unit: 'N/A',
                                costPerUnit: 0,
                                totalCost: 0,
                                dateAdded: DateTime.now(),
                                outletId: '',
                                createdAt: DateTime.now(),
                                isSynced: false
                              ),
                            );
                            final outlet = _outlets.firstWhere(
                              (o) => o.id == stock.outletId,
                              orElse: () => Outlet(
                                id: stock.outletId,
                                name: 'Unknown',
                                createdAt: null,
                              ),
                            );

                            return DataRow(
                              cells: [
                                DataCell(Text(product.productName)),
                                DataCell(Text(outlet.name)),
                                DataCell(Text(stock.givenQuantity.toString())),
                                DataCell(Text(stock.soldQuantity.toString())),
                                DataCell(Text(stock.balanceQuantity.toString())),
                                DataCell(Text('₦${product.costPerUnit}')),
                                DataCell(Text('₦${stock.totalGivenValue?.toStringAsFixed(2) ?? '0.00'}')),
                                DataCell(Text(stock.lastUpdated?.toString().split('.')[0] ?? 'N/A')),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
