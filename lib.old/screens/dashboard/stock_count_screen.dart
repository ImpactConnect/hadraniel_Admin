import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:csv/csv.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';
import '../../widgets/dashboard_layout.dart';
import '../../core/services/stock_count_service.dart';
import '../../core/services/sync_service.dart';
import '../../core/models/stock_count_model.dart';
import '../../core/models/stock_count_item_model.dart';
import '../../core/models/stock_adjustment_model.dart';
import '../../core/models/outlet_model.dart';

class StockCountScreen extends StatefulWidget {
  const StockCountScreen({super.key});

  @override
  State<StockCountScreen> createState() => _StockCountScreenState();
}

class _StockCountScreenState extends State<StockCountScreen>
    with TickerProviderStateMixin {
  final StockCountService _stockCountService = StockCountService();
  final SyncService _syncService = SyncService();

  late TabController _tabController;

  List<StockCount> _stockCounts = [];
  List<Outlet> _outlets = [];
  String? _selectedOutletId;
  bool _isLoading = false;

  // Current stock count session
  StockCount? _currentStockCount;
  List<StockCountItem> _currentItems = [];
  Map<String, double> _stockedInQuantities = {};
  Map<String, double> _soldQuantities = {};

  // Analytics data
  Map<String, dynamic> _analyticsData = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _initializeService();
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _initializeService() async {
    // Tables are now automatically initialized by DatabaseHelper
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final outlets = await _syncService.getAllLocalOutlets();
      final stockCounts =
          await _stockCountService.getStockCountHistory(limit: 20);
      final analytics = await _stockCountService.getVarianceAnalysisReport();

      setState(() {
        _outlets = outlets;
        _stockCounts = stockCounts;
        _analyticsData = analytics;
        if (_outlets.isNotEmpty && _selectedOutletId == null) {
          _selectedOutletId = _outlets.first.id;
        }
      });
    } catch (e) {
      _showErrorSnackBar('Error loading data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _startNewStockCount() async {
    if (_selectedOutletId == null) {
      _showErrorSnackBar('Please select an outlet first');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final stockCount = await _stockCountService.createStockCount(
        outletId: _selectedOutletId!,
        createdBy: 'Admin', // TODO: Get from auth service
        notes: 'Stock count session started',
      );

      final items = await _stockCountService.initializeStockCountItems(
        stockCount.id,
        _selectedOutletId!,
      );

      // Load actual stocked-in and sold quantities
      final stockedInQuantities =
          await _stockCountService.getStockedInQuantities(_selectedOutletId!);
      final soldQuantities =
          await _stockCountService.getSoldQuantities(_selectedOutletId!);

      setState(() {
        _currentStockCount = stockCount;
        _currentItems = items;
        _stockedInQuantities = stockedInQuantities;
        _soldQuantities = soldQuantities;
        _tabController.animateTo(1); // Switch to count entry tab
      });

      _showSuccessSnackBar('Stock count session started successfully');
    } catch (e) {
      _showErrorSnackBar('Error starting stock count: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateItemQuantity(String itemId, double quantity) async {
    try {
      final updatedItem =
          await _stockCountService.updateActualQuantity(itemId, quantity);

      setState(() {
        final index = _currentItems.indexWhere((item) => item.id == itemId);
        if (index != -1) {
          _currentItems[index] = updatedItem;
        }
      });
    } catch (e) {
      _showErrorSnackBar('Error updating quantity: $e');
    }
  }

  Future<void> _completeStockCount() async {
    if (_currentStockCount == null) return;

    try {
      await _stockCountService.completeStockCount(
        _currentStockCount!.id,
        notes: 'Stock count completed',
      );

      // Create adjustments for significant variances
      await _stockCountService.createAdjustmentsFromCount(
        _currentStockCount!.id,
        'Admin', // TODO: Get from auth service
      );

      setState(() {
        _currentStockCount = null;
        _currentItems = [];
        _stockedInQuantities = {};
        _soldQuantities = {};
        _tabController.animateTo(0); // Switch back to overview
      });

      _loadData(); // Refresh data
      _showSuccessSnackBar('Stock count completed successfully');
    } catch (e) {
      _showErrorSnackBar('Error completing stock count: $e');
    }
  }

  Future<void> _resumeStockCount(StockCount stockCount) async {
    if (stockCount.status != 'in_progress') {
      _showErrorSnackBar('Can only resume in-progress stock counts');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Load existing items for this stock count
      final items = await _stockCountService.getStockCountItems(stockCount.id);

      // Load actual stocked-in and sold quantities
      final stockedInQuantities =
          await _stockCountService.getStockedInQuantities(stockCount.outletId);
      final soldQuantities =
          await _stockCountService.getSoldQuantities(stockCount.outletId);

      setState(() {
        _currentStockCount = stockCount;
        _currentItems = items;
        _stockedInQuantities = stockedInQuantities;
        _soldQuantities = soldQuantities;
        _selectedOutletId = stockCount.outletId;
        _tabController.animateTo(1); // Switch to count entry tab
      });

      _showSuccessSnackBar('Stock count session resumed');
    } catch (e) {
      _showErrorSnackBar('Error resuming stock count: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _viewStockCountDetails(StockCount stockCount) async {
    try {
      final items = await _stockCountService.getStockCountItems(stockCount.id);

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (context) => _buildStockCountDetailsDialog(stockCount, items),
      );
    } catch (e) {
      _showErrorSnackBar('Error loading stock count details: $e');
    }
  }

  Widget _buildStockCountDetailsDialog(
      StockCount stockCount, List<StockCountItem> items) {
    final colorScheme = Theme.of(context).colorScheme;

    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.8,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with all elements in a single row
            Row(
              children: [
                Icon(Icons.inventory, color: colorScheme.primary, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Stock Count #${stockCount.id.substring(0, 8)}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Date: ${DateFormat('MMM dd, yyyy HH:mm').format(stockCount.countDate)}',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getStatusColor(stockCount.status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    stockCount.status.toUpperCase(),
                    style: TextStyle(
                      color: _getStatusColor(stockCount.status),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Export buttons for completed counts
                if (stockCount.status == 'completed') ...[
                  OutlinedButton.icon(
                    onPressed: () => _exportToCsv(stockCount, items),
                    icon: const Icon(Icons.table_chart),
                    label: const Text('Export CSV'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: () => _exportToPdf(stockCount, items),
                    icon: const Icon(Icons.picture_as_pdf),
                    label: const Text('Export PDF'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                // Close and Resume buttons
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
                if (stockCount.status == 'in_progress') ...[
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _resumeStockCount(stockCount);
                    },
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Resume Count'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 20),

            // Summary Cards
            Row(
              children: [
                Expanded(
                  child: _buildSummaryCard(
                    'Total Items',
                    items.length.toString(),
                    Icons.inventory_2,
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildSummaryCard(
                    'Items with Variance',
                    items
                        .where((item) => item.variance.abs() > 0.01)
                        .length
                        .toString(),
                    Icons.warning,
                    Colors.orange,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildSummaryCard(
                    'Total Value Impact',
                    '₦${items.fold(0.0, (sum, item) => sum + item.valueImpact.abs()).toStringAsFixed(0)}',
                    Icons.attach_money,
                    Colors.red,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Items Table
            Expanded(
              child: Card(
                elevation: 2,
                child: Column(
                  children: [
                    // Table Header
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withOpacity(0.1),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(8),
                          topRight: Radius.circular(8),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Text(
                              'Product Name',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: colorScheme.primary,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              'Theoretical',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: colorScheme.primary,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              'Actual',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: colorScheme.primary,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              'Variance',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: colorScheme.primary,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              'Value Impact',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: colorScheme.primary,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Table Body
                    Expanded(
                      child: ListView.builder(
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          final item = items[index];
                          final hasVariance = item.variance.abs() > 0.01;

                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: hasVariance
                                  ? Colors.red.withOpacity(0.05)
                                  : null,
                              border: Border(
                                bottom: BorderSide(
                                  color: Colors.grey[200]!,
                                  width: 1,
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: Text(
                                    item.productName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    item.theoreticalQuantity.toStringAsFixed(3),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    item.actualQuantity.toStringAsFixed(3),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    '${item.variance >= 0 ? '+' : ''}${item.variance.toStringAsFixed(3)}',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: hasVariance
                                          ? (item.variance > 0
                                              ? Colors.green
                                              : Colors.red)
                                          : null,
                                      fontWeight:
                                          hasVariance ? FontWeight.bold : null,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    '₦${item.valueImpact.toStringAsFixed(0)}',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: hasVariance
                                          ? (item.valueImpact > 0
                                              ? Colors.green
                                              : Colors.red)
                                          : null,
                                      fontWeight:
                                          hasVariance ? FontWeight.bold : null,
                                    ),
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

            // Bottom spacing
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(
      String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _exportToCsv(
      StockCount stockCount, List<StockCountItem> items) async {
    try {
      // Prepare CSV data
      List<List<dynamic>> csvData = [
        [
          'Product Name',
          'Theoretical Quantity',
          'Actual Quantity',
          'Variance',
          'Value Impact (₦)',
          'Unit Cost (₦)'
        ]
      ];

      for (final item in items) {
        csvData.add([
          item.productName,
          item.theoreticalQuantity.toStringAsFixed(3),
          item.actualQuantity.toStringAsFixed(3),
          item.variance.toStringAsFixed(3),
          item.valueImpact.toStringAsFixed(2),
          item.costPerUnit.toStringAsFixed(2),
        ]);
      }

      // Convert to CSV string
      String csvString = const ListToCsvConverter().convert(csvData);

      // Get the downloads directory
      final directory = await getDownloadsDirectory();
      if (directory == null) {
        _showErrorSnackBar('Could not access downloads directory');
        return;
      }

      // Create file
      final fileName =
          'stock_count_${stockCount.id.substring(0, 8)}_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv';
      final file = File('${directory.path}/$fileName');
      await file.writeAsString(csvString);

      _showSuccessSnackBar('CSV exported to Downloads: $fileName');
    } catch (e) {
      _showErrorSnackBar('Error exporting CSV: $e');
    }
  }

  Future<void> _exportToPdf(
      StockCount stockCount, List<StockCountItem> items) async {
    try {
      final pdf = pw.Document();

      // Calculate summary data
      final totalItems = items.length;
      final itemsWithVariance =
          items.where((item) => item.variance.abs() > 0.01).length;
      final totalValueImpact =
          items.fold(0.0, (sum, item) => sum + item.valueImpact.abs());

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) {
            return [
              // Header
              pw.Header(
                level: 0,
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'Stock Count Report',
                          style: pw.TextStyle(
                            fontSize: 24,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.Text(
                          'Count #${stockCount.id.substring(0, 8)}',
                          style: const pw.TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          'Date: ${DateFormat('MMM dd, yyyy HH:mm').format(stockCount.countDate)}',
                          style: const pw.TextStyle(fontSize: 12),
                        ),
                        pw.Text(
                          'Status: ${stockCount.status.toUpperCase()}',
                          style: const pw.TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),

              // Summary Section
              pw.Container(
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius:
                      const pw.BorderRadius.all(pw.Radius.circular(8)),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Summary',
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 10),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                      children: [
                        pw.Column(
                          children: [
                            pw.Text(
                              totalItems.toString(),
                              style: pw.TextStyle(
                                fontSize: 18,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                            pw.Text('Total Items'),
                          ],
                        ),
                        pw.Column(
                          children: [
                            pw.Text(
                              itemsWithVariance.toString(),
                              style: pw.TextStyle(
                                fontSize: 18,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                            pw.Text('Items with Variance'),
                          ],
                        ),
                        pw.Column(
                          children: [
                            pw.Text(
                              '₦${totalValueImpact.toStringAsFixed(0)}',
                              style: pw.TextStyle(
                                fontSize: 18,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                            pw.Text('Total Value Impact'),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),

              // Items Table
              pw.Text(
                'Stock Count Details',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300),
                columnWidths: {
                  0: const pw.FlexColumnWidth(3),
                  1: const pw.FlexColumnWidth(2),
                  2: const pw.FlexColumnWidth(2),
                  3: const pw.FlexColumnWidth(2),
                  4: const pw.FlexColumnWidth(2),
                },
                children: [
                  // Header row
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(
                      color: PdfColors.grey200,
                    ),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          'Product Name',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          'Theoretical',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          'Actual',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          'Variance',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          'Value Impact (₦)',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                  // Data rows
                  ...items.map((item) {
                    final hasVariance = item.variance.abs() > 0.01;
                    return pw.TableRow(
                      decoration: hasVariance
                          ? const pw.BoxDecoration(color: PdfColors.red50)
                          : null,
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(item.productName),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            item.theoreticalQuantity.toStringAsFixed(3),
                            textAlign: pw.TextAlign.center,
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            item.actualQuantity.toStringAsFixed(3),
                            textAlign: pw.TextAlign.center,
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            '${item.variance >= 0 ? '+' : ''}${item.variance.toStringAsFixed(3)}',
                            textAlign: pw.TextAlign.center,
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            '₦${item.valueImpact.toStringAsFixed(0)}',
                            textAlign: pw.TextAlign.center,
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ],
              ),
            ];
          },
        ),
      );

      // Get the downloads directory
      final directory = await getDownloadsDirectory();
      if (directory == null) {
        _showErrorSnackBar('Could not access downloads directory');
        return;
      }

      // Save PDF file
      final fileName =
          'stock_count_${stockCount.id.substring(0, 8)}_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf';
      final file = File('${directory.path}/$fileName');
      await file.writeAsBytes(await pdf.save());

      _showSuccessSnackBar('PDF exported to Downloads: $fileName');
    } catch (e) {
      _showErrorSnackBar('Error exporting PDF: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DashboardLayout(
      title: 'Stock Count & Reconciliation',
      child: Column(
        children: [
          // Tab Bar
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: colorScheme.primary,
              unselectedLabelColor: Colors.grey[600],
              indicatorColor: colorScheme.primary,
              tabs: const [
                Tab(icon: Icon(Icons.dashboard), text: 'Overview'),
                Tab(icon: Icon(Icons.inventory), text: 'Count Entry'),
                Tab(icon: Icon(Icons.analytics), text: 'Reconciliation'),
                Tab(icon: Icon(Icons.history), text: 'History'),
              ],
            ),
          ),
          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(),
                _buildCountEntryTab(),
                _buildReconciliationTab(),
                _buildHistoryTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    final colorScheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Outlet Selection Card
          Card(
            elevation: 2,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.store, color: colorScheme.primary, size: 24),
                      const SizedBox(width: 12),
                      const Text(
                        'Select Outlet for Stock Count',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _selectedOutletId,
                    decoration: InputDecoration(
                      labelText: 'Outlet',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      prefixIcon:
                          Icon(Icons.location_on, color: colorScheme.primary),
                    ),
                    items: _outlets.map((outlet) {
                      return DropdownMenuItem(
                        value: outlet.id,
                        child: Text(outlet.name),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() => _selectedOutletId = value);
                    },
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _selectedOutletId != null && !_isLoading
                          ? _startNewStockCount
                          : null,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.add_circle),
                      label: Text(
                          _isLoading ? 'Starting...' : 'Start New Stock Count'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Analytics Cards
          _buildAnalyticsCards(),

          const SizedBox(height: 20),

          // Recent Stock Counts
          Card(
            elevation: 2,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.history, color: colorScheme.primary, size: 24),
                      const SizedBox(width: 12),
                      const Text(
                        'Recent Stock Counts',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_stockCounts.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Text(
                          'No stock counts found',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _stockCounts.take(5).length,
                      separatorBuilder: (context, index) => const Divider(),
                      itemBuilder: (context, index) {
                        final stockCount = _stockCounts[index];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: _getStatusColor(stockCount.status)
                                .withOpacity(0.2),
                            child: Icon(
                              _getStatusIcon(stockCount.status),
                              color: _getStatusColor(stockCount.status),
                            ),
                          ),
                          title: Text(
                            'Count #${stockCount.id.substring(0, 8)}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            '${DateFormat('MMM dd, yyyy').format(stockCount.countDate)} • ${stockCount.status}',
                          ),
                          trailing: Icon(Icons.chevron_right,
                              color: Colors.grey[400]),
                          onTap: () {
                            if (stockCount.status == 'in_progress') {
                              _resumeStockCount(stockCount);
                            } else {
                              _viewStockCountDetails(stockCount);
                            }
                          },
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCountEntryTab() {
    if (_currentStockCount == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No active stock count session',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              'Start a new stock count from the Overview tab',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Session Info Header
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          color: Colors.blue[50],
          child: Row(
            children: [
              Icon(Icons.inventory, color: Colors.blue[700]),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Stock Count Session #${_currentStockCount!.id.substring(0, 8)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[700],
                      ),
                    ),
                    Text(
                      'Started: ${DateFormat('MMM dd, yyyy HH:mm').format(_currentStockCount!.createdAt)}',
                      style: TextStyle(color: Colors.blue[600], fontSize: 12),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: _completeStockCount,
                icon: const Icon(Icons.check_circle),
                label: const Text('Complete Count'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),

        // Items Table
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  // Table Header
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withOpacity(0.1),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(12),
                        topRight: Radius.circular(12),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Text(
                            'Product Name',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            'Total Stocked-in',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            'Total Sold',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            'Available Count',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            'Report',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Table Body
                  Expanded(
                    child: ListView.builder(
                      itemCount: _currentItems.length,
                      itemBuilder: (context, index) {
                        final item = _currentItems[index];
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: Colors.grey[200]!,
                                width: 1,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              // Product Name
                              Expanded(
                                flex: 3,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.productName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                    if (item.hasVariance)
                                      Container(
                                        margin: const EdgeInsets.only(top: 4),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: item.isPositiveVariance
                                              ? Colors.green[100]
                                              : Colors.red[100],
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          item.varianceStatus,
                                          style: TextStyle(
                                            color: item.isPositiveVariance
                                                ? Colors.green[700]
                                                : Colors.red[700],
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              // Total Stocked-in (Actual Given Quantity)
                              Expanded(
                                flex: 2,
                                child: Text(
                                  (_stockedInQuantities[item.productId] ?? 0.0)
                                      .toStringAsFixed(3),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              // Total Sold (Actual Sold Quantity)
                              Expanded(
                                flex: 2,
                                child: Text(
                                  (_soldQuantities[item.productId] ?? 0.0)
                                      .toStringAsFixed(3),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              // Available Count (Actual Quantity Input)
                              Expanded(
                                flex: 2,
                                child: Padding(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 8),
                                  child: TextFormField(
                                    initialValue:
                                        item.actualQuantity.toString(),
                                    keyboardType: TextInputType.number,
                                    textAlign: TextAlign.center,
                                    decoration: InputDecoration(
                                      isDense: true,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 8,
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(6),
                                        borderSide: BorderSide(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary,
                                        ),
                                      ),
                                    ),
                                    onChanged: (value) {
                                      final quantity =
                                          double.tryParse(value) ?? 0.0;
                                      _updateItemQuantity(item.id, quantity);
                                    },
                                  ),
                                ),
                              ),
                              // Report (Variance)
                              Expanded(
                                flex: 2,
                                child: Column(
                                  children: [
                                    Text(
                                      '${item.variance > 0 ? '+' : ''}${item.variance.toStringAsFixed(1)}',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: item.hasVariance
                                            ? (item.isPositiveVariance
                                                ? Colors.green[700]
                                                : Colors.red[700])
                                            : Colors.grey[600],
                                      ),
                                    ),
                                    if (item.hasVariance)
                                      Text(
                                        '(${item.variancePercentage.toStringAsFixed(1)}%)',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: item.isPositiveVariance
                                              ? Colors.green[600]
                                              : Colors.red[600],
                                        ),
                                      ),
                                  ],
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
    );
  }

  Widget _buildReconciliationTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Reconciliation Dashboard',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),

          // Variance Summary Cards
          _buildVarianceSummaryCards(),

          const SizedBox(height: 20),

          // Adjustments Section
          Card(
            elevation: 2,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Pending Adjustments',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  const Center(
                    child: Text(
                      'No pending adjustments',
                      style: TextStyle(color: Colors.grey),
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

  Widget _buildHistoryTab() {
    return Column(
      children: [
        // Filters
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.grey[50],
          child: Row(
            children: [
              Flexible(
                flex: 1,
                child: DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Filter by Outlet',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  isExpanded: true,
                  items: [
                    const DropdownMenuItem(
                        value: null, child: Text('All Outlets')),
                    ..._outlets.map((outlet) => DropdownMenuItem(
                          value: outlet.id,
                          child: Text(
                            outlet.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        )),
                  ],
                  onChanged: (value) {
                    // TODO: Filter by outlet
                  },
                ),
              ),
              const SizedBox(width: 16),
              Flexible(
                flex: 1,
                child: DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Filter by Status',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(value: null, child: Text('All Status')),
                    DropdownMenuItem(
                        value: 'completed', child: Text('Completed')),
                    DropdownMenuItem(
                        value: 'in_progress', child: Text('In Progress')),
                  ],
                  onChanged: (value) {
                    // TODO: Filter by status
                  },
                ),
              ),
            ],
          ),
        ),

        // History List
        Expanded(
          child: _stockCounts.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.history, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'No stock count history',
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _stockCounts.length,
                  itemBuilder: (context, index) {
                    final stockCount = _stockCounts[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: _getStatusColor(stockCount.status)
                              .withOpacity(0.2),
                          child: Icon(
                            _getStatusIcon(stockCount.status),
                            color: _getStatusColor(stockCount.status),
                          ),
                        ),
                        title: Text(
                          'Stock Count #${stockCount.id.substring(0, 8)}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                'Date: ${DateFormat('MMM dd, yyyy HH:mm').format(stockCount.countDate)}'),
                            Text('Status: ${stockCount.status}'),
                            if (stockCount.notes != null)
                              Text('Notes: ${stockCount.notes}'),
                          ],
                        ),
                        trailing:
                            Icon(Icons.chevron_right, color: Colors.grey[400]),
                        onTap: () {
                          if (stockCount.status == 'in_progress') {
                            _resumeStockCount(stockCount);
                          } else {
                            _viewStockCountDetails(stockCount);
                          }
                        },
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildAnalyticsCards() {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        Expanded(
          child: _buildAnalyticsCard(
            'Total Counts',
            _analyticsData['total_counts']?.toString() ?? '0',
            Icons.inventory,
            colorScheme.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildAnalyticsCard(
            'Accuracy Rate',
            '${(_analyticsData['accuracy_percentage'] ?? 0.0).toStringAsFixed(1)}%',
            Icons.check_circle,
            Colors.green,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildAnalyticsCard(
            'Items with Variance',
            _analyticsData['items_with_variance']?.toString() ?? '0',
            Icons.warning,
            Colors.orange,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildAnalyticsCard(
            'Value Impact',
            '₦${(_analyticsData['total_value_impact'] ?? 0.0).toStringAsFixed(0)}',
            Icons.attach_money,
            Colors.red,
          ),
        ),
      ],
    );
  }

  Widget _buildAnalyticsCard(
      String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 24),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 16),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVarianceSummaryCards() {
    return Row(
      children: [
        Expanded(
          child: _buildVarianceCard(
            'Total Overage',
            '+${(_analyticsData['total_overage'] ?? 0.0).toStringAsFixed(1)}',
            Colors.green,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildVarianceCard(
            'Total Shortage',
            '-${(_analyticsData['total_shortage'] ?? 0.0).toStringAsFixed(1)}',
            Colors.red,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildVarianceCard(
            'Avg Variance %',
            '${(_analyticsData['avg_variance_percentage'] ?? 0.0).toStringAsFixed(2)}%',
            Colors.orange,
          ),
        ),
      ],
    );
  }

  Widget _buildVarianceCard(String title, String value, Color color) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
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

  Color _getStatusColor(String status) {
    switch (status) {
      case 'completed':
        return Colors.green;
      case 'in_progress':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'completed':
        return Icons.check_circle;
      case 'in_progress':
        return Icons.access_time;
      default:
        return Icons.help;
    }
  }
}
