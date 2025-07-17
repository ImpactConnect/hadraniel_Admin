import 'package:flutter/material.dart';
import 'package:sticky_headers/sticky_headers.dart';
import 'package:calendar_date_picker2/calendar_date_picker2.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import '../../core/models/outlet_model.dart';
import '../../core/models/product_model.dart';
import '../../core/models/stock_balance_model.dart';
import '../../core/services/stock_service.dart';
import '../../core/services/sync_service.dart';
import '../../widgets/dashboard_layout.dart';
import '../../widgets/loading_overlay.dart';
import 'stock_detail_dialog.dart';

class StockScreen extends StatefulWidget {
  const StockScreen({super.key});

  @override
  State<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends State<StockScreen> {
  Widget _buildHeaderCell(String text, double width) {
    return Container(
      width: width,
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildContentCell(String text, double width) {
    return Container(
      width: width,
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: TextStyle(color: Colors.grey.shade800, fontSize: 14),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildMetricCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [color.withOpacity(0.8), color.withOpacity(0.6)],
            ),
          ),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: Colors.white, size: 24),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading data: $e')));
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error syncing data: $e')));
      }
    } finally {
      setState(() => _isSyncing = false);
    }
  }

  Future<void> _exportStockToCSV() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final path =
          '${directory.path}/stock_balances_${DateTime.now().millisecondsSinceEpoch}.csv';
      final file = File(path);

      // Create CSV data
      List<List<dynamic>> rows = [];

      // Add header row
      rows.add([
        'Product Name',
        'Outlet',
        'Given Quantity',
        'Sold Quantity',
        'Balance Quantity',
        'Given Value',
        'Balance Value',
        'Last Updated',
      ]);

      // Add data rows
      for (var stock in _stockBalances.where((stock) {
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
            isSynced: false,
          ),
        );
        final outlet = _outlets.firstWhere(
          (o) => o.id == stock.outletId,
          orElse: () =>
              Outlet(id: stock.outletId, name: 'Unknown', createdAt: null),
        );

        return product.productName.toLowerCase().contains(
              _searchQuery.toLowerCase(),
            ) ||
            outlet.name.toLowerCase().contains(_searchQuery.toLowerCase());
      })) {
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
            isSynced: false,
          ),
        );
        final outlet = _outlets.firstWhere(
          (o) => o.id == stock.outletId,
          orElse: () =>
              Outlet(id: stock.outletId, name: 'Unknown', createdAt: null),
        );

        rows.add([
          product.productName,
          outlet.name,
          stock.givenQuantity.toString(),
          stock.soldQuantity.toString(),
          stock.balanceQuantity.toString(),
          stock.totalGivenValue?.toStringAsFixed(2) ?? '0.00',
          stock.balanceValue?.toStringAsFixed(2) ?? '0.00',
          stock.lastUpdated != null
              ? DateFormat('yyyy-MM-dd').format(stock.lastUpdated!)
              : 'N/A',
        ]);
      }

      // Convert to CSV
      String csv = const ListToCsvConverter().convert(rows);

      // Write to file
      await file.writeAsString(csv);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('CSV exported to: $path')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error exporting CSV: $e')));
    }
  }

  Future<void> _exportStockToPDF() async {
    try {
      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          header: (pw.Context context) {
            return pw.Header(
              level: 0,
              child: pw.Text(
                'Stock Balance Report',
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            );
          },
          footer: (pw.Context context) {
            return pw.Footer(
              trailing: pw.Text(
                'Page ${context.pageNumber} of ${context.pagesCount}',
                style: pw.TextStyle(fontSize: 10),
              ),
            );
          },
          build: (pw.Context context) => [
            pw.Table.fromTextArray(
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              headerDecoration: pw.BoxDecoration(color: PdfColors.grey300),
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.centerLeft,
                2: pw.Alignment.center,
                3: pw.Alignment.center,
                4: pw.Alignment.center,
                5: pw.Alignment.center,
                6: pw.Alignment.center,
                7: pw.Alignment.center,
              },
              headers: [
                'Product Name',
                'Outlet',
                'Given Quantity',
                'Sold Quantity',
                'Balance Quantity',
                'Given Value',
                'Balance Value',
                'Last Updated',
              ],
              data: _stockBalances
                  .where((stock) {
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
                        isSynced: false,
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

                    return product.productName.toLowerCase().contains(
                          _searchQuery.toLowerCase(),
                        ) ||
                        outlet.name.toLowerCase().contains(
                          _searchQuery.toLowerCase(),
                        );
                  })
                  .map((stock) {
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
                        isSynced: false,
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

                    return [
                      product.productName,
                      outlet.name,
                      stock.givenQuantity.toString(),
                      stock.soldQuantity.toString(),
                      stock.balanceQuantity.toString(),
                      stock.totalGivenValue?.toStringAsFixed(2) ?? '0.00',
                      stock.balanceValue?.toStringAsFixed(2) ?? '0.00',
                      stock.lastUpdated != null
                          ? DateFormat('yyyy-MM-dd').format(stock.lastUpdated!)
                          : 'N/A',
                    ];
                  })
                  .toList(),
            ),
          ],
        ),
      );

      final directory = await getApplicationDocumentsDirectory();
      final path =
          '${directory.path}/stock_balances_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final file = File(path);
      await file.writeAsBytes(await pdf.save());

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('PDF exported to: $path')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error exporting PDF: $e')));
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
    final picked = await showDialog(
      context: context,
      builder: (BuildContext context) {
        DateTime? startDate = _startDate;
        DateTime? endDate = _endDate;

        return Dialog(
          child: Container(
            width: 300, // Reduced width for the calendar popup
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CalendarDatePicker2(
                  config: CalendarDatePicker2Config(
                    calendarType: CalendarDatePicker2Type.range,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
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

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
        _activeDateFilter =
            '${picked.start.toString().split(' ')[0]} to '
            '${picked.end.toString().split(' ')[0]}';
        _loadData();
      });
    }
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
          isSynced: false,
        ),
      );
      final outlet = _outlets.firstWhere(
        (o) => o.id == stock.outletId,
        orElse: () =>
            Outlet(id: stock.outletId, name: 'Unknown', createdAt: null),
      );

      return product.productName.toLowerCase().contains(
            _searchQuery.toLowerCase(),
          ) ||
          outlet.name.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return DashboardLayout(
      title: 'Stock Management',
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: _loadData,
          tooltip: 'Refresh',
        ),
        IconButton(
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
          onPressed: _isSyncing ? null : _syncData,
          tooltip: 'Sync Stock',
        ),
        IconButton(
          icon: const Icon(Icons.file_download),
          onPressed: _exportStockToCSV,
          tooltip: 'Export to CSV',
        ),
        IconButton(
          icon: const Icon(Icons.picture_as_pdf),
          onPressed: _exportStockToPDF,
          tooltip: 'Export to PDF',
        ),
        const SizedBox(width: 8),
      ],
      child: Column(
        children: [
          // Spacing at the top
          const SizedBox(height: 8),
          if (_isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Metric cards with improved spacing
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 8.0,
                    ),
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
                          filteredStockBalances
                              .fold(
                                0.0,
                                (sum, stock) => sum + stock.givenQuantity,
                              )
                              .toString(),
                          Icons.shopping_cart,
                          Colors.green,
                        ),
                        const SizedBox(width: 16),
                        _buildMetricCard(
                          'Total Sold Quantity',
                          filteredStockBalances
                              .fold(
                                0.0,
                                (sum, stock) => sum + stock.soldQuantity,
                              )
                              .toString(),
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

                  // Unified filter section with card styling
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 8.0),
                    child: Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Filter section title and date filters in a single row
                            Row(
                              children: [
                                Text(
                                  'Filters',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                      ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Row(
                                      children: [
                                        ...[
                                          "Today",
                                          "Yesterday",
                                          "This week",
                                          "Last 7 days",
                                          "This month",
                                          "Last month",
                                        ].map(
                                          (filter) => Padding(
                                            padding: const EdgeInsets.only(
                                              right: 8.0,
                                            ),
                                            child: FilterChip(
                                              label: Text(filter),
                                              selected:
                                                  _activeDateFilter == filter,
                                              selectedColor: Theme.of(context)
                                                  .colorScheme
                                                  .primary
                                                  .withOpacity(0.2),
                                              checkmarkColor: Theme.of(
                                                context,
                                              ).colorScheme.primary,
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
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.primary,
                                            ),
                                            label: Text(
                                              _activeDateFilter.isEmpty
                                                  ? 'Select Date'
                                                  : _activeDateFilter,
                                            ),
                                            onPressed: _showDateRangePicker,
                                          ),
                                        ),
                                        if (_activeDateFilter.isNotEmpty)
                                          ActionChip(
                                            avatar: Icon(
                                              Icons.clear,
                                              size: 18,
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.error,
                                            ),
                                            label: const Text('Clear Filter'),
                                            onPressed: _clearDateFilter,
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 12),

                            // Search and dropdown filters in a single row
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    decoration: InputDecoration(
                                      isDense: true,
                                      labelText: 'Search Stock',
                                      prefixIcon: const Icon(Icons.search),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            vertical: 10,
                                            horizontal: 12,
                                          ),
                                    ),
                                    onChanged: (value) =>
                                        setState(() => _searchQuery = value),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    value: _selectedOutletId,
                                    decoration: InputDecoration(
                                      isDense: true,
                                      labelText: 'Filter by Outlet',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            vertical: 10,
                                            horizontal: 12,
                                          ),
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
                                const SizedBox(width: 12),
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    value: _selectedProductId,
                                    decoration: InputDecoration(
                                      isDense: true,
                                      labelText: 'Filter by Product',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            vertical: 10,
                                            horizontal: 12,
                                          ),
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
                    ),
                  ),

                  // Table with sticky header and centered content
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          children: [
                            // Sticky header
                            Container(
                              color: Theme.of(context).colorScheme.primary,
                              height: 48,
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: [
                                    _buildHeaderCell('Product Name', 200),
                                    _buildHeaderCell('Outlet', 150),
                                    _buildHeaderCell('Given Qty', 100),
                                    _buildHeaderCell('Sold Qty', 100),
                                    _buildHeaderCell('Balance', 100),
                                    _buildHeaderCell('Cost Price', 120),
                                    _buildHeaderCell('Total Value', 120),
                                  ],
                                ),
                              ),
                            ),
                            // Scrollable content
                            Expanded(
                              child: SingleChildScrollView(
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Column(
                                    children: filteredStockBalances.map((
                                      stock,
                                    ) {
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
                                          isSynced: false,
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

                                      return InkWell(
                                        onTap: () {
                                          showDialog(
                                            context: context,
                                            builder: (context) =>
                                                StockDetailDialog(
                                                  stock: stock,
                                                  product: product,
                                                  outlet: outlet,
                                                ),
                                          );
                                        },
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            border: Border(
                                              bottom: BorderSide(
                                                color: Colors.grey.shade200,
                                              ),
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              _buildContentCell(
                                                product.productName,
                                                200,
                                              ),
                                              _buildContentCell(
                                                outlet.name,
                                                150,
                                              ),
                                              _buildContentCell(
                                                stock.givenQuantity.toString(),
                                                100,
                                              ),
                                              _buildContentCell(
                                                stock.soldQuantity.toString(),
                                                100,
                                              ),
                                              _buildContentCell(
                                                stock.balanceQuantity
                                                    .toString(),
                                                100,
                                              ),
                                              _buildContentCell(
                                                '₦${product.costPerUnit}',
                                                120,
                                              ),
                                              _buildContentCell(
                                                '₦${(stock.givenQuantity * product.costPerUnit).toStringAsFixed(2)}',
                                                120,
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
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
        ],
      ),
    );
  }
}
