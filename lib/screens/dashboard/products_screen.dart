import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:calendar_date_picker2/calendar_date_picker2.dart';
import '../../core/models/product_model.dart';
import '../../core/models/outlet_model.dart';
import '../../core/services/sync_service.dart';
import '../../widgets/dashboard_layout.dart';
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
      await _syncService.migrateProductUnits(); // Migrate product units
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

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return DashboardLayout(
      title: 'Products',
      child: Container(
        color: Colors.grey[50],
        height: double.infinity,
        child: Column(
          children: [
            // Header section with sync button and filters
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top row with title and sync button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Product Inventory',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      ElevatedButton.icon(
                        icon: _isSyncing
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.sync),
                        label: Text(
                          _isSyncing ? 'Syncing...' : 'Sync Products',
                        ),
                        onPressed: _isSyncing ? null : _syncProducts,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          foregroundColor: Colors.white,
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Search and filter section
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.grey.shade200),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Search, Outlet and Unit filters in a single row
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Search field
                              Expanded(
                                flex: 2,
                                child: TextField(
                                  decoration: InputDecoration(
                                    labelText: 'Search Products',
                                    prefixIcon: Icon(
                                      Icons.search,
                                      color: colorScheme.primary,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: Colors.grey[300]!,
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: Colors.grey[300]!,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: colorScheme.primary,
                                      ),
                                    ),
                                    filled: true,
                                    fillColor: Colors.white,
                                    contentPadding: const EdgeInsets.symmetric(
                                      vertical: 12.0,
                                      horizontal: 16.0,
                                    ),
                                  ),
                                  onChanged: (value) =>
                                      setState(() => _searchQuery = value),
                                ),
                              ),
                              const SizedBox(width: 16),

                              // Outlet filter
                              Expanded(
                                flex: 1,
                                child: FutureBuilder<List<Outlet>>(
                                  future: _syncService.getAllLocalOutlets(),
                                  builder: (context, snapshot) {
                                    if (snapshot.hasError) {
                                      return const Text(
                                        'Error loading outlets',
                                      );
                                    }
                                    final outlets = snapshot.data ?? [];
                                    return DropdownButtonFormField<String>(
                                      value: _selectedOutlet,
                                      decoration: InputDecoration(
                                        labelText: 'Filter by Outlet',
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 8,
                                            ),
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
                                      onChanged: (value) => setState(
                                        () => _selectedOutlet = value,
                                      ),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(width: 16),

                              // Unit filter
                              Expanded(
                                flex: 1,
                                child: DropdownButtonFormField<String>(
                                  value: _selectedUnit,
                                  decoration: InputDecoration(
                                    labelText: 'Filter by Unit',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                  ),
                                  items: [
                                    const DropdownMenuItem(
                                      value: null,
                                      child: Text('All Units'),
                                    ),
                                    ...[
                                      'KG',
                                      'PCS',
                                      'Carton',
                                      'Paint',
                                      'Cup',
                                    ].map(
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
                          const SizedBox(height: 16),

                          // Filter section
                          Text(
                            'Filters',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Date filter chips in a horizontal scrollable row
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Date Range',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
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
                                        padding: const EdgeInsets.only(
                                          right: 8.0,
                                        ),
                                        child: FilterChip(
                                          label: Text(filter),
                                          selected: _activeDateFilter == filter,
                                          selectedColor: colorScheme.primary
                                              .withOpacity(0.2),
                                          checkmarkColor: colorScheme.primary,
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
                                      padding: const EdgeInsets.only(
                                        right: 8.0,
                                      ),
                                      child: ActionChip(
                                        avatar: Icon(
                                          Icons.date_range,
                                          size: 18,
                                          color: colorScheme.primary,
                                        ),
                                        label: Text(
                                          _activeDateFilter.isEmpty
                                              ? 'Custom Date'
                                              : _activeDateFilter,
                                          style: TextStyle(
                                            color: colorScheme.primary,
                                          ),
                                        ),
                                        backgroundColor: colorScheme.primary
                                            .withOpacity(0.1),
                                        onPressed: _showDateRangePicker,
                                      ),
                                    ),
                                    if (_activeDateFilter.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          right: 8.0,
                                        ),
                                        child: ActionChip(
                                          avatar: const Icon(
                                            Icons.clear,
                                            size: 18,
                                            color: Colors.red,
                                          ),
                                          label: const Text(
                                            'Clear Filter',
                                            style: TextStyle(color: Colors.red),
                                          ),
                                          backgroundColor: Colors.red
                                              .withOpacity(0.1),
                                          onPressed: _clearDateFilter,
                                        ),
                                      ),
                                  ],
                                ),
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

            // Table section with sticky header
            Expanded(
              child: Container(
                margin: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 5,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Sticky header
                    Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 16.0,
                        horizontal: 24.0,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withOpacity(0.1),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(12),
                          topRight: Radius.circular(12),
                        ),
                      ),
                      child: Row(
                        children: const [
                          Expanded(
                            flex: 3,
                            child: Text(
                              'Product Name',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              'Unit',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              'Quantity',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              'Cost/Unit',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              'Assigned Outlet',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              'Total Cost',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              'Date Added',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              'Date Updated',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          SizedBox(
                            width: 40,
                            child: Text(
                              'Sync',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Scrollable table content
                    Expanded(
                      child: SingleChildScrollView(
                        child: ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: filteredProducts.length,
                          separatorBuilder: (context, index) =>
                              const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final product = filteredProducts.elementAt(index);
                            final totalCost =
                                product.quantity * product.costPerUnit;

                            return InkWell(
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
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12.0,
                                  horizontal: 24.0,
                                ),
                                color: index % 2 == 0
                                    ? Colors.white
                                    : Colors.grey[50],
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 3,
                                      child: Text(
                                        product.productName,
                                        style: TextStyle(
                                          color: colorScheme.primary,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Expanded(child: Text(product.unit)),
                                    Expanded(
                                      child: Text(product.quantity.toString()),
                                    ),
                                    Expanded(
                                      child: Text(
                                        '\$${product.costPerUnit.toStringAsFixed(2)}',
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: FutureBuilder<String>(
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
                                    Expanded(
                                      child: Text(
                                        '\$${totalCost.toStringAsFixed(2)}',
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        DateFormat(
                                          'yyyy-MM-dd',
                                        ).format(product.dateAdded),
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        DateFormat(
                                          'yyyy-MM-dd',
                                        ).format(product.createdAt),
                                      ),
                                    ),
                                    SizedBox(
                                      width: 40,
                                      child: Icon(
                                        product.isSynced
                                            ? Icons.cloud_done
                                            : Icons.cloud_off,
                                        color: product.isSynced
                                            ? Colors.green
                                            : Colors.grey,
                                        size: 20,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showProductDialog(),
        tooltip: 'Add New Product',
        icon: const Icon(Icons.add),
        label: const Text('Add Product', style: TextStyle(color: Colors.white)),
        backgroundColor: Theme.of(context).colorScheme.primary,
        elevation: 4,
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
    final picked = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            padding: const EdgeInsets.all(16),
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Select Date Range',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 400,
                  child: CalendarDatePicker2(
                    config: CalendarDatePicker2Config(
                      calendarType: CalendarDatePicker2Type.range,
                      selectedDayHighlightColor: Theme.of(
                        context,
                      ).colorScheme.primary,
                    ),
                    value:
                        _selectedStartDate != null && _selectedEndDate != null
                        ? [_selectedStartDate!, _selectedEndDate!]
                        : [],
                    onValueChanged: (dates) {
                      if (dates.isNotEmpty &&
                          dates.length >= 2 &&
                          dates[0] != null &&
                          dates[1] != null) {
                        Navigator.of(context).pop([dates[0], dates[1]]);
                      }
                    },
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        'Cancel',
                        style: TextStyle(color: Theme.of(context).colorScheme.primary),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        if (_selectedStartDate != null &&
                            _selectedEndDate != null) {
                          Navigator.of(
                            context,
                          ).pop([_selectedStartDate, _selectedEndDate]);
                        } else {
                          Navigator.of(context).pop();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Apply'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (picked != null && picked is List && picked.length >= 2) {
      setState(() {
        _selectedStartDate = picked[0];
        _selectedEndDate = picked[1];
      });
    }
  }
}
