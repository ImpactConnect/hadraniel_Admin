import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:csv/csv.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:calendar_date_picker2/calendar_date_picker2.dart';
import 'dart:async';
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
  DateTime? _customStartDate;
  DateTime? _customEndDate;

  // Product search
  final TextEditingController _productSearchController =
      TextEditingController();
  List<Product> _filteredProducts = [];
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;

  // Lists for dropdowns
  List<Outlet> _outlets = [];
  List<Rep> _reps = [];
  List<Product> _products = [];

  @override
  void initState() {
    super.initState();
    _loadData();

    // Setup product search listener
    _productSearchController.addListener(_filterProducts);
  }

  @override
  void dispose() {
    _productSearchController.removeListener(_filterProducts);
    _productSearchController.dispose();
    _removeOverlay();
    super.dispose();
  }

  void _showOverlay() {
    _removeOverlay(); // Remove existing overlay if any

    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: 300,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: const Offset(0, 45),
          child: Material(
            elevation: 24,
            borderRadius: BorderRadius.circular(4),
            clipBehavior: Clip.antiAlias,
            child: Container(
              constraints: const BoxConstraints(maxHeight: 200),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _filteredProducts.length,
                itemBuilder: (context, index) {
                  final product = _filteredProducts[index];
                  return ListTile(
                    dense: true,
                    title: Text(
                      product.productName,
                      style: const TextStyle(fontSize: 13),
                    ),
                    subtitle: Text(
                      'Qty: ${product.quantity} ${product.unit}',
                      style: const TextStyle(fontSize: 11),
                    ),
                    onTap: () {
                      setState(() {
                        _selectedProductId = product.id;
                        _productSearchController.text = product.productName;
                        _filteredProducts = [];
                      });
                      _removeOverlay();
                      _applyFilters().then((_) {
                        setState(() {});
                      });
                    },
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _filterProducts() {
    final query = _productSearchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredProducts = [];
        _removeOverlay();
      } else {
        _filteredProducts = _products
            .where(
                (product) => product.productName.toLowerCase().contains(query))
            .toList();
        if (_filteredProducts.isNotEmpty) {
          _showOverlay();
        } else {
          _removeOverlay();
        }
      }
    });
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

    // Use custom date range if available
    if (_customStartDate != null && _customEndDate != null) {
      startDate = _customStartDate;
      endDate = _customEndDate;
    } else {
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
        PopupMenuButton<String>(
          icon: const Icon(Icons.file_download),
          tooltip: 'Export',
          onSelected: (String value) {
            if (value == 'csv') {
              _exportToCSV();
            } else if (value == 'pdf') {
              _exportToPDF();
            }
          },
          itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
            const PopupMenuItem<String>(
              value: 'csv',
              child: ListTile(
                leading: Icon(Icons.table_chart),
                title: Text('Export as CSV'),
              ),
            ),
            const PopupMenuItem<String>(
              value: 'pdf',
              child: ListTile(
                leading: Icon(Icons.picture_as_pdf),
                title: Text('Export as PDF'),
              ),
            ),
          ],
        ),
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
        const SizedBox(height: 16),
        _buildMetricsCards(),
        const SizedBox(height: 16),
        _buildFilters(),
        const SizedBox(height: 8),
        Expanded(child: _buildSalesTable()),
      ],
    );
  }

  Widget _buildFilters() {
    final hasActiveFilters = _selectedDateFilter != 'All Time' ||
        _selectedOutletId != null ||
        _selectedRepId != null ||
        _selectedProductId != null ||
        _customStartDate != null ||
        _customEndDate != null;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Filters',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                if (hasActiveFilters)
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _selectedDateFilter = 'All Time';
                        _selectedOutletId = null;
                        _selectedRepId = null;
                        _selectedProductId = null;
                        _customStartDate = null;
                        _customEndDate = null;
                        _productSearchController.clear();
                        _filteredProducts = [];
                      });
                      _applyFilters().then((_) {
                        setState(() {});
                      });
                    },
                    icon:
                        Icon(Icons.clear, size: 16, color: Colors.red.shade700),
                    label: Text(
                      'Clear All',
                      style:
                          TextStyle(fontSize: 13, color: Colors.red.shade700),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            // Single row layout for all filters
            Row(
              children: [
                // Date filter
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    value: _selectedDateFilter,
                    decoration: InputDecoration(
                      labelText: 'Date',
                      labelStyle:
                          TextStyle(color: Theme.of(context).primaryColor),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide:
                            BorderSide(color: Theme.of(context).primaryColor),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                      isDense: true,
                      filled: true,
                      fillColor: Colors.grey.shade50,
                    ),
                    items: [
                      'All Time',
                      'Today',
                      'Yesterday',
                      'Last 7 Days',
                      'This Month',
                      'Last Month',
                      'Custom',
                    ].map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child:
                            Text(value, style: const TextStyle(fontSize: 13)),
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
                    icon: Icon(Icons.arrow_drop_down,
                        color: Theme.of(context).primaryColor),
                    dropdownColor: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),

                // Outlet filter
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    value: _selectedOutletId,
                    decoration: InputDecoration(
                      labelText: 'Outlet',
                      labelStyle:
                          TextStyle(color: Theme.of(context).primaryColor),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide:
                            BorderSide(color: Theme.of(context).primaryColor),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                      isDense: true,
                      filled: true,
                      fillColor: Colors.grey.shade50,
                    ),
                    items: [
                      const DropdownMenuItem<String>(
                        value: null,
                        child:
                            Text('All Outlets', style: TextStyle(fontSize: 13)),
                      ),
                      ..._outlets.map((outlet) {
                        return DropdownMenuItem<String>(
                          value: outlet.id,
                          child: Text(outlet.name,
                              style: const TextStyle(fontSize: 13)),
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
                    icon: Icon(Icons.arrow_drop_down,
                        color: Theme.of(context).primaryColor),
                    dropdownColor: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),

                // Rep filter
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    value: _selectedRepId,
                    decoration: InputDecoration(
                      labelText: 'Rep',
                      labelStyle:
                          TextStyle(color: Theme.of(context).primaryColor),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide:
                            BorderSide(color: Theme.of(context).primaryColor),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                      isDense: true,
                      filled: true,
                      fillColor: Colors.grey.shade50,
                    ),
                    items: [
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Text('All Reps', style: TextStyle(fontSize: 13)),
                      ),
                      ..._reps.map((rep) {
                        return DropdownMenuItem<String>(
                          value: rep.id,
                          child: Text(rep.fullName,
                              style: const TextStyle(fontSize: 13)),
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
                    icon: Icon(Icons.arrow_drop_down,
                        color: Theme.of(context).primaryColor),
                    dropdownColor: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),

                // Product search filter
                Expanded(
                  flex: 3,
                  child: CompositedTransformTarget(
                    link: _layerLink,
                    child: TextField(
                      controller: _productSearchController,
                      decoration: InputDecoration(
                        labelText: 'Search Product',
                        labelStyle:
                            TextStyle(color: Theme.of(context).primaryColor),
                        hintText: 'Type to search...',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8)),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:
                              BorderSide(color: Theme.of(context).primaryColor),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 12),
                        isDense: true,
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        prefixIcon: const Icon(Icons.search, size: 18),
                        suffixIcon: _productSearchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 16),
                                onPressed: () {
                                  _productSearchController.clear();
                                  setState(() {
                                    _selectedProductId = null;
                                  });
                                  _applyFilters().then((_) {
                                    setState(() {});
                                  });
                                },
                              )
                            : null,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Calendar date range filter icon
                if (_selectedDateFilter == 'Custom')
                  Tooltip(
                    message: _getDateRangeText(),
                    child: IconButton(
                      onPressed: _showDateRangePicker,
                      icon: const Icon(Icons.calendar_today),
                      style: IconButton.styleFrom(
                        backgroundColor:
                            Theme.of(context).primaryColor.withOpacity(0.1),
                        foregroundColor: Theme.of(context).primaryColor,
                        padding: const EdgeInsets.all(12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
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
                                Expanded(
                                    flex: 2,
                                    child: _buildFlexHeaderCell('Date')),
                                Expanded(
                                    flex: 2,
                                    child: _buildFlexHeaderCell('Outlet')),
                                Expanded(
                                    flex: 2,
                                    child: _buildFlexHeaderCell('Customer')),
                                Expanded(
                                    flex: 3,
                                    child:
                                        _buildFlexHeaderCell('Product Name')),
                                Expanded(
                                    flex: 1,
                                    child: _buildFlexHeaderCell('Qty')),
                                Expanded(
                                    flex: 2,
                                    child:
                                        _buildFlexHeaderCell('Total Amount')),
                                Expanded(
                                    flex: 2,
                                    child: _buildFlexHeaderCell('Amount Paid')),
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

                                return InkWell(
                                  onTap: () => _showSaleDetails(sale),
                                  child: Container(
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
                                          child: _buildProductCell(sale),
                                        ),
                                        Expanded(
                                          flex: 1,
                                          child: _buildQuantityCell(sale),
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
                                      ],
                                    ),
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
      child: widget ??
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
      child: widget ??
          Text(
            text,
            style: TextStyle(color: textColor),
            overflow: TextOverflow.ellipsis,
          ),
    );
  }

  Widget _buildProductCell(Map<String, dynamic> sale) {
    // First try to use product_names which is more reliable
    final productNames = sale['product_names'] as String? ?? 'No Items';

    if (productNames == 'No Items') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
        child: const Text('No Items', overflow: TextOverflow.ellipsis),
      );
    }

    final products = productNames.split(', ');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
      child: products.length > 1
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: products
                  .map((product) => Text(
                        product,
                        style: const TextStyle(fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ))
                  .toList(),
            )
          : Text(
              products.first,
              overflow: TextOverflow.ellipsis,
            ),
    );
  }

  Widget _buildQuantityCell(Map<String, dynamic> sale) {
    // First check if we have items_detail which contains quantity information
    final itemsDetail = sale['items_detail'] as String? ?? 'No Items';

    if (itemsDetail == 'No Items') {
      // If no items, display 0
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
        child: const Text('0'),
      );
    }

    final items = itemsDetail.split(', ');

    // Extract just the quantity from each item (format: "X x Product Name")
    final quantities = items.map((item) {
      final parts = item.split(' x ');
      return parts.isNotEmpty ? parts[0] : '0';
    }).toList();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
      child: quantities.length > 1
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: quantities
                  .map((qty) => Text(
                        qty,
                        style: const TextStyle(fontSize: 12),
                      ))
                  .toList(),
            )
          : Text(
              quantities.first,
            ),
    );
  }

  String _getDateRangeText() {
    if (_customStartDate != null && _customEndDate != null) {
      final dateFormat = DateFormat('MMM d, yyyy');
      return '${dateFormat.format(_customStartDate!)} - ${dateFormat.format(_customEndDate!)}';
    }
    return 'Custom Date Range';
  }

  Future<void> _showDateRangePicker() async {
    final picked = await showDialog(
      context: context,
      builder: (BuildContext context) {
        DateTime? startDate = _customStartDate;
        DateTime? endDate = _customEndDate;

        return Dialog(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.4,
              maxHeight: MediaQuery.of(context).size.height * 0.7,
            ),
            child: Container(
              padding: const EdgeInsets.all(16.0),
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
                  Flexible(
                    child: CalendarDatePicker2(
                      config: CalendarDatePicker2Config(
                        calendarType: CalendarDatePicker2Type.range,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                        selectedDayHighlightColor:
                            Theme.of(context).colorScheme.primary,
                        weekdayLabelTextStyle: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                        controlsTextStyle: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      value: startDate != null && endDate != null
                          ? [startDate, endDate]
                          : [],
                      onValueChanged: (dates) {
                        if (dates.length == 2 &&
                            dates[0] != null &&
                            dates[1] != null) {
                          startDate = dates[0]!;
                          endDate = dates[1]!;
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () {
                          if (startDate != null && endDate != null) {
                            Navigator.pop(
                              context,
                              DateTimeRange(start: startDate!, end: endDate!),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              Theme.of(context).colorScheme.primary,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Apply'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (picked != null) {
      setState(() {
        _customStartDate = picked.start;
        _customEndDate = picked.end;
        _selectedDateFilter = 'Custom';
      });
      await _applyFilters();
      setState(() {});
    }
  }

  Future<void> _exportToCSV() async {
    try {
      final csvData = _generateCSVList();
      final csvString = const ListToCsvConverter().convert(csvData);

      // Get downloads directory
      Directory? downloadsDir;
      if (Platform.isWindows) {
        final userProfile = Platform.environment['USERPROFILE'];
        if (userProfile != null) {
          downloadsDir = Directory('$userProfile\\Downloads');
        }
      } else {
        downloadsDir = await getDownloadsDirectory();
      }

      if (downloadsDir == null || !await downloadsDir.exists()) {
        downloadsDir = await getApplicationDocumentsDirectory();
      }

      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final fileName = 'sales_export_$timestamp.csv';
      final file = File('${downloadsDir.path}/$fileName');

      await file.writeAsString(csvString);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('CSV exported successfully to ${file.path}'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
  }

  Future<void> _exportToPDF() async {
    try {
      final pdf = pw.Document();
      final csvData = _generateCSVList();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(20),
          build: (pw.Context context) {
            return [
              pw.Header(
                level: 0,
                child: pw.Text(
                  'Sales Export Report',
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Text(
                'Generated on: ${DateFormat('MMMM d, yyyy h:mm a').format(DateTime.now())}',
                style: const pw.TextStyle(fontSize: 12),
              ),
              pw.SizedBox(height: 20),
              pw.Table.fromTextArray(
                context: context,
                data: csvData,
                headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 10,
                ),
                cellStyle: const pw.TextStyle(fontSize: 9),
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColors.grey300,
                ),
                cellHeight: 25,
                cellAlignments: {
                  0: pw.Alignment.centerLeft,
                  1: pw.Alignment.centerLeft,
                  2: pw.Alignment.centerLeft,
                  3: pw.Alignment.centerLeft,
                  4: pw.Alignment.centerLeft,
                  5: pw.Alignment.centerRight,
                  6: pw.Alignment.centerRight,
                },
              ),
            ];
          },
        ),
      );

      // Get downloads directory
      Directory? downloadsDir;
      if (Platform.isWindows) {
        final userProfile = Platform.environment['USERPROFILE'];
        if (userProfile != null) {
          downloadsDir = Directory('$userProfile\\Downloads');
        }
      } else {
        downloadsDir = await getDownloadsDirectory();
      }

      if (downloadsDir == null || !await downloadsDir.exists()) {
        downloadsDir = await getApplicationDocumentsDirectory();
      }

      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final fileName = 'sales_export_$timestamp.pdf';
      final file = File('${downloadsDir.path}/$fileName');

      await file.writeAsBytes(await pdf.save());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF exported successfully to ${file.path}'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF export failed: $e')),
        );
      }
    }
  }

  List<List<String>> _generateCSVList() {
    final data = <List<String>>[];

    // CSV Header
    data.add([
      'Date',
      'Sales ID',
      'Customer',
      'Product ID',
      'Product Name',
      'Quantity',
      'Amount Paid'
    ]);

    // CSV Data
    for (final sale in _sales) {
      final date =
          DateFormat('yyyy-MM-dd').format(DateTime.parse(sale['created_at']));
      final saleId = sale['id'] ?? '';
      final customer = sale['customer_name'] ?? 'Walk-in';
      final productNames = sale['product_names'] ?? 'N/A';
      final products = productNames.split(', ');
      final itemCount = sale['item_count'] ?? 0;
      final amountPaid = sale['amount_paid'] ?? 0;

      // For multiple products, create separate rows
      if (products.length > 1) {
        for (int i = 0; i < products.length; i++) {
          final productName = products[i].trim();
          final quantity = (itemCount / products.length).round();
          data.add([
            date,
            saleId,
            customer,
            '',
            productName,
            quantity.toString(),
            amountPaid.toString()
          ]);
        }
      } else {
        data.add([
          date,
          saleId,
          customer,
          '',
          productNames,
          itemCount.toString(),
          amountPaid.toString()
        ]);
      }
    }

    return data;
  }

  void _showSaleDetails(Map<String, dynamic> sale) async {
    final saleId = sale['id'] as String;
    final saleItems = await _syncService.getSaleItemsWithProductDetails(saleId);
    final currencyFormat = NumberFormat.currency(symbol: '₦');
    final dateFormat = DateFormat('MMMM d, yyyy h:mm a');

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.7,
          height: MediaQuery.of(context).size.height * 0.8,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.blue.shade50,
                Colors.white,
              ],
            ),
          ),
          child: Column(
            children: [
              // Modern Header
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade600, Colors.blue.shade800],
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.receipt_long,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Sale Details',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            dateFormat
                                .format(DateTime.parse(sale['created_at'])),
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ],
                ),
              ),

              // Content
              Expanded(
                  child: Padding(
                padding: const EdgeInsets.all(24),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Sale Information Cards
                      Row(
                        children: [
                          Expanded(
                            child: _buildInfoCard(
                              'Outlet',
                              sale['outlet_name'] ?? 'N/A',
                              Icons.store,
                              Colors.purple,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildInfoCard(
                              'Customer',
                              sale['customer_name'] ?? 'Walk-in',
                              Icons.person,
                              Colors.green,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildInfoCard(
                              'Sales Rep',
                              sale['rep_name'] ?? 'N/A',
                              Icons.badge,
                              Colors.orange,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // Items Section
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.1),
                              spreadRadius: 2,
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    Icons.shopping_cart,
                                    color: Colors.blue.shade700,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Text(
                                  'Items Purchased',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade50,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    '${saleItems.length} items',
                                    style: TextStyle(
                                      color: Colors.blue.shade700,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // Items List
                            Container(
                              height: 150,
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade200),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                children: [
                                  // Table header
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade100,
                                      borderRadius: const BorderRadius.only(
                                        topLeft: Radius.circular(8),
                                        topRight: Radius.circular(8),
                                      ),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          flex: 3,
                                          child:
                                              _buildModernHeaderCell('Product'),
                                        ),
                                        Expanded(
                                            child:
                                                _buildModernHeaderCell('Qty')),
                                        Expanded(
                                          child: _buildModernHeaderCell(
                                              'Unit Price'),
                                        ),
                                        Expanded(
                                            child: _buildModernHeaderCell(
                                                'Total')),
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
                                                child: _buildModernCell(
                                                  item['product_name'] ??
                                                      'Unknown Product',
                                                ),
                                              ),
                                              Expanded(
                                                child: _buildModernCell(
                                                  item['quantity'].toString(),
                                                ),
                                              ),
                                              Expanded(
                                                child: _buildModernCell(
                                                  currencyFormat.format(
                                                      item['unit_price'] ?? 0),
                                                ),
                                              ),
                                              Expanded(
                                                child: _buildModernCell(
                                                  currencyFormat.format(
                                                      item['total'] ?? 0),
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
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Summary Section
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.blue.shade50, Colors.blue.shade100],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade600,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.summarize,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Payment Summary',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue.shade800,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _buildSummaryRow(
                              'Total Amount:',
                              currencyFormat.format(sale['total_amount'] ?? 0),
                              Colors.blue.shade700,
                            ),
                            const SizedBox(height: 8),
                            _buildSummaryRow(
                              'Amount Paid:',
                              currencyFormat.format(sale['amount_paid'] ?? 0),
                              Colors.green.shade700,
                            ),
                            const SizedBox(height: 8),
                            _buildSummaryRow(
                              'Outstanding Amount:',
                              currencyFormat
                                  .format(sale['outstanding_amount'] ?? 0),
                              (sale['outstanding_amount'] ?? 0) > 0
                                  ? Colors.red.shade700
                                  : Colors.green.shade700,
                            ),
                            if ((sale['amount_paid'] ?? 0) >
                                (sale['total_amount'] ?? 0)) ...[
                              const SizedBox(height: 8),
                              _buildSummaryRow(
                                'Overpayment:',
                                currencyFormat.format(
                                    (sale['amount_paid'] ?? 0) -
                                        (sale['total_amount'] ?? 0)),
                                Colors.blue.shade700,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard(
      String title, String value, IconData icon, Color color) {
    return Container(
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
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 20,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard(String title, String value, bool isPaid) {
    return Container(
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
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color:
                      (isPaid ? Colors.green : Colors.orange).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isPaid ? Icons.check_circle : Icons.pending,
                  color: isPaid ? Colors.green : Colors.orange,
                  size: 20,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: (isPaid ? Colors.green : Colors.orange).withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isPaid ? Colors.green : Colors.orange,
                width: 1,
              ),
            ),
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isPaid ? Colors.green.shade700 : Colors.orange.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernHeaderCell(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      child: Text(
        text,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.grey.shade700,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildModernCell(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
      child: Text(
        text,
        style: const TextStyle(fontSize: 13),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade700,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
        ),
      ],
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
