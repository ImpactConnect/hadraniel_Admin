import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/models/product_model.dart';
import '../../core/models/outlet_model.dart';
import '../../core/services/sync_service.dart';
import 'sidebar.dart';
import 'product_detail_popup.dart';
import 'add_product_dialog.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final SyncService _syncService = SyncService();
  List<Product> _products = [];
  String _searchQuery = '';
  String? _selectedOutlet;
  String? _selectedUnit;
  bool _isSyncing = false;
  DateTime? _selectedStartDate;
  DateTime? _selectedEndDate;

  String get _activeDateFilter {
    if (_selectedStartDate == null && _selectedEndDate == null) return '';
    if (_selectedStartDate != null && _selectedEndDate != null) {
      return 'Custom Range';
    }
    return 'Custom';
  }

  Future<void> _syncProducts() async {
    setState(() => _isSyncing = true);
    try {
      await _syncService.syncProductsToLocalDb();
      await _loadProducts();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Products synced successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error syncing products: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _loadProducts();
    _loadOutlets();
  }

  Future<void> _loadOutlets() async {
    try {
      await _syncService.syncOutletsToLocalDb();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading outlets: $e')));
      }
    }
  }

  Future<void> _deleteProduct(Product product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Product'),
        content: Text(
          'Are you sure you want to delete ${product.productName}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed ?? false) {
      try {
        await _syncService.deleteProduct(product.id);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Product deleted successfully')),
        );
        _loadProducts(); // Refresh the list
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error deleting product: $e')));
      }
    }
  }

  Future<void> _loadProducts() async {
    try {
      final products = await _syncService.getAllLocalProducts();
      if (mounted) {
        setState(() {
          _products = products;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading products: $e')));
      }
    }
  }

  void _showProductDialog({Product? product}) {
    showDialog(
      context: context,
      builder: (context) =>
          AddProductDialog(product: product, onProductSaved: _loadProducts),
    );
  }

  @override
  Widget build(BuildContext context) {
    var filteredProducts = _products.where(
      (product) => product.productName.toLowerCase().contains(
        _searchQuery.toLowerCase(),
      ),
    );

    if (_selectedStartDate != null && _selectedEndDate != null) {
      filteredProducts = filteredProducts.where((product) {
        return product.dateAdded.isAfter(_selectedStartDate!) &&
            product.dateAdded.isBefore(
              _selectedEndDate!.add(const Duration(days: 1)),
            );
      });
    }

    if (_selectedOutlet != null) {
      filteredProducts = filteredProducts.where(
        (product) => product.outletId == _selectedOutlet,
      );
    }

    if (_selectedUnit != null) {
      filteredProducts = filteredProducts.where(
        (product) => product.unit == _selectedUnit,
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Products'),
        actions: [
          IconButton(
            icon: _isSyncing
                ? const CircularProgressIndicator(color: Colors.white)
                : const Icon(Icons.sync),
            onPressed: _isSyncing ? null : _syncProducts,
          ),
        ],
      ),
      drawer: Sidebar(),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ...[
                        'Today',
                        'Yesterday',
                        'This week',
                        'Last 7 days',
                        'This month',
                        'Last month',
                      ].map(
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
                            _activeDateFilter.isEmpty
                                ? 'Select Date'
                                : _activeDateFilter,
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
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Search Products',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (value) => setState(() => _searchQuery = value),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: FutureBuilder<List<Outlet>>(
                        future: _syncService.getAllLocalOutlets(),
                        builder: (context, snapshot) {
                          if (snapshot.hasError) {
                            return const Text('Error loading outlets');
                          }
                          final outlets = snapshot.data ?? [];
                          return DropdownButtonFormField<String>(
                            value: _selectedOutlet,
                            decoration: const InputDecoration(
                              labelText: 'Filter by Outlet',
                            ),
                            items: [
                              const DropdownMenuItem(
                                value: null,
                                child: Text('All Outlets'),
                              ),
                              ...outlets.map(
                                (outlet) => DropdownMenuItem(
                                  value: outlet.id,
                                  child: Text(outlet.name),
                                ),
                              ),
                            ],
                            onChanged: (value) =>
                                setState(() => _selectedOutlet = value),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedUnit,
                        decoration: const InputDecoration(
                          labelText: 'Filter by Unit',
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('All Units'),
                          ),
                          ...['KG', 'PCS', 'Carton', 'Paint', 'Cup'].map(
                            (unit) => DropdownMenuItem(
                              value: unit,
                              child: Text(unit),
                            ),
                          ),
                        ],
                        onChanged: (value) =>
                            setState(() => _selectedUnit = value),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: PrimaryScrollController(
              controller: ScrollController(),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SingleChildScrollView(
                  controller: ScrollController(),
                  child: Theme(
                    data: Theme.of(context).copyWith(
                      dataTableTheme: DataTableThemeData(
                        headingRowColor: MaterialStateProperty.all(
                          Theme.of(
                            context,
                          ).colorScheme.primary.withOpacity(0.1),
                        ),
                      ),
                    ),
                    child: DataTable(
                      columnSpacing: 24,
                      columns: const [
                        DataColumn(
                          label: Text('Product Name'),
                          tooltip: 'Click on product name to view details',
                        ),
                        DataColumn(label: Text('Unit')),
                        DataColumn(label: Text('Quantity')),
                        DataColumn(label: Text('Cost/Unit')),
                        DataColumn(label: Text('Assigned Outlet')),
                        DataColumn(label: Text('Total Cost')),
                        DataColumn(label: Text('Date Added')),
                        DataColumn(label: Text('Date Updated')),
                        DataColumn(label: Text('Sync Status')),
                      ],
                      rows: filteredProducts.map((product) {
                        final totalCost =
                            product.quantity * product.costPerUnit;
                        return DataRow(
                          cells: [
                            DataCell(
                              InkWell(
                                onTap: () => showDialog(
                                  context: context,
                                  builder: (context) => ProductDetailPopup(
                                    product: product,
                                    onEdit: () =>
                                        _showProductDialog(product: product),
                                    onDelete: () => _deleteProduct(product),
                                  ),
                                ),
                                child: Container(
                                  constraints: const BoxConstraints(
                                    maxWidth: 300,
                                  ),
                                  child: Text(
                                    product.productName,
                                    style: const TextStyle(
                                      color: Colors.blue,
                                      decoration: TextDecoration.underline,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ),
                            DataCell(Text(product.unit)),
                            DataCell(Text(product.quantity.toString())),
                            DataCell(
                              Text(
                                '\$${product.costPerUnit.toStringAsFixed(2)}',
                              ),
                            ),
                            DataCell(
                              FutureBuilder<String>(
                                future: _syncService.getOutletName(
                                  product.outletId,
                                ),
                                builder: (context, snapshot) {
                                  if (snapshot.hasData) {
                                    return Text(snapshot.data!);
                                  }
                                  return const Text('Loading...');
                                },
                              ),
                            ),
                            DataCell(Text('\$${totalCost.toStringAsFixed(2)}')),
                            DataCell(
                              Text(
                                DateFormat(
                                  'yyyy-MM-dd',
                                ).format(product.dateAdded),
                              ),
                            ),
                            DataCell(
                              Text(
                                DateFormat(
                                  'yyyy-MM-dd',
                                ).format(product.createdAt),
                              ),
                            ),
                            DataCell(
                              Icon(
                                product.isSynced
                                    ? Icons.cloud_done
                                    : Icons.cloud_off,
                                color: product.isSynced
                                    ? Colors.green
                                    : Colors.grey,
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showProductDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _clearDateFilter() {
    setState(() {
      _selectedStartDate = null;
      _selectedEndDate = null;
    });
  }

  void _setDateFilter(String filter) {
    final now = DateTime.now();
    setState(() {
      switch (filter) {
        case 'Today':
          _selectedStartDate = DateTime(now.year, now.month, now.day);
          _selectedEndDate = now;
          break;
        case 'Yesterday':
          final yesterday = now.subtract(const Duration(days: 1));
          _selectedStartDate = DateTime(
            yesterday.year,
            yesterday.month,
            yesterday.day,
          );
          _selectedEndDate = DateTime(
            yesterday.year,
            yesterday.month,
            yesterday.day,
            23,
            59,
            59,
          );
          break;
        case 'This week':
          _selectedStartDate = now.subtract(Duration(days: now.weekday - 1));
          _selectedEndDate = now;
          break;
        case 'Last 7 days':
          _selectedStartDate = now.subtract(const Duration(days: 7));
          _selectedEndDate = now;
          break;
        case 'This month':
          _selectedStartDate = DateTime(now.year, now.month, 1);
          _selectedEndDate = now;
          break;
        case 'Last month':
          final lastMonth = DateTime(now.year, now.month - 1);
          _selectedStartDate = DateTime(lastMonth.year, lastMonth.month, 1);
          _selectedEndDate = DateTime(now.year, now.month, 0, 23, 59, 59);
          break;
      }
    });
  }

  Future<void> _showDateRangePicker() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _selectedStartDate != null && _selectedEndDate != null
          ? DateTimeRange(start: _selectedStartDate!, end: _selectedEndDate!)
          : null,
    );
    if (picked != null) {
      setState(() {
        _selectedStartDate = picked.start;
        _selectedEndDate = picked.end;
      });
    }
  }
}
