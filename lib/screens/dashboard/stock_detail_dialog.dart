import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/models/outlet_model.dart';
import '../../core/models/product_model.dart';
import '../../core/models/stock_balance_model.dart';
import '../../core/services/sync_service.dart';

class StockDetailDialog extends StatefulWidget {
  final StockBalance stock;
  final Product product;
  final Outlet outlet;

  const StockDetailDialog({
    super.key,
    required this.stock,
    required this.product,
    required this.outlet,
  });

  @override
  State<StockDetailDialog> createState() => _StockDetailDialogState();
}

class _StockDetailDialogState extends State<StockDetailDialog> {
  final SyncService _syncService = SyncService();
  List<Map<String, dynamic>> _salesHistory = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSalesHistory();
  }

  Future<void> _loadSalesHistory() async {
    setState(() => _isLoading = true);
    try {
      print('Loading sales history for product: ${widget.product.id}');
      final sales = await _syncService.getSalesWithDetails(
        productId: widget.product.id,
      );
      print('Received sales history: $sales');
      setState(() {
        _salesHistory = sales;
        _isLoading = false;
      });
      print('Sales history length: ${_salesHistory.length}');
    } catch (e) {
      print('Error loading sales history: $e');
      setState(() => _isLoading = false);
    }
  }

  Widget _buildDetailRow(String label, String value, {Color? valueColor}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
      margin: const EdgeInsets.only(bottom: 8.0),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: Colors.grey.shade700,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: valueColor ?? Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
      margin: const EdgeInsets.only(bottom: 16.0, top: 8.0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary.withOpacity(0.1),
            Theme.of(context).colorScheme.primary.withOpacity(0.05),
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSalesHistoryTable() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_salesHistory.isEmpty) {
      return const Center(
        child: Text(
          'No sales history available',
          style: TextStyle(fontSize: 16, fontStyle: FontStyle.italic),
        ),
      );
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [Colors.white, Colors.grey.shade50],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: MaterialStateProperty.all(
              Theme.of(context).colorScheme.primary,
            ),
            headingTextStyle: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
            dataRowColor: MaterialStateProperty.resolveWith<Color?>(
              (Set<MaterialState> states) {
                if (states.contains(MaterialState.hovered)) {
                  return Theme.of(context).colorScheme.primary.withOpacity(0.1);
                }
                return null;
              },
            ),
            columns: const [
              DataColumn(label: Text('Date')),
              DataColumn(label: Text('Outlet')),
              DataColumn(label: Text('Customer')),
              DataColumn(label: Text('Quantity')),
              DataColumn(label: Text('Total Cost')),
            ],
            rows: [
              // Regular sales data rows
              ..._salesHistory.map((sale) {
                final saleDate = DateTime.parse(sale['created_at']);
                return DataRow(
                  cells: [
                    DataCell(Text(
                      DateFormat('MMM d, yyyy').format(saleDate),
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    )),
                    DataCell(Text(
                      sale['outlet_name'] ?? 'N/A',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    )),
                    DataCell(Text(
                      sale['customer_name'] ?? 'Walk-in',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    )),
                    DataCell(Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        sale['quantity']?.toString() ?? '0',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade800,
                        ),
                      ),
                    )),
                    DataCell(Text(
                      '₦${(sale['total_amount'] ?? 0.0).toStringAsFixed(2)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade700,
                      ),
                    )),
                  ],
                );
              }).toList(),
              // Summary row
              if (_salesHistory.isNotEmpty)
                DataRow(
                  color: MaterialStateProperty.all(
                    Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  ),
                  cells: [
                    const DataCell(Text(
                      'TOTAL',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    )),
                    const DataCell(Text('')), // Empty outlet cell
                    const DataCell(Text('')), // Empty customer cell
                    DataCell(Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _salesHistory
                            .fold<double>(
                              0.0,
                              (sum, sale) =>
                                  sum +
                                  ((sale['quantity'] as num?)?.toDouble() ??
                                      0.0),
                            )
                            .toStringAsFixed(3),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                          fontSize: 14,
                        ),
                      ),
                    )),
                    DataCell(Text(
                      '₦${_salesHistory.fold<double>(
                            0.0,
                            (sum, sale) =>
                                sum +
                                (sale['total_amount'] as num? ?? 0).toDouble(),
                          ).toStringAsFixed(2)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                        fontSize: 14,
                      ),
                    )),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 10,
      child: Container(
          width: MediaQuery.of(context).size.width * 0.85,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.9,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              colors: [Colors.white, Colors.grey.shade50],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with gradient background
              Container(
                padding: const EdgeInsets.all(24.0),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).colorScheme.primary,
                      Theme.of(context).colorScheme.primary.withOpacity(0.8),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.inventory_2,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Stock Details',
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 28,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              // Content
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top row with Product Information and Stock Quantities side by side
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Product Information Section
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildSectionTitle(
                                  context,
                                  'Product Information',
                                  Icons.inventory,
                                ),
                                Column(
                                  children: [
                                    _buildDetailRow(
                                      'Product Name',
                                      widget.product.productName,
                                    ),
                                    _buildDetailRow(
                                        'Outlet', widget.outlet.name),
                                    _buildDetailRow(
                                      'Cost Price',
                                      '₦${widget.product.costPerUnit}',
                                      valueColor: Colors.green.shade700,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          // Stock Quantities Section
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildSectionTitle(
                                  context,
                                  'Stock Quantities',
                                  Icons.assessment,
                                ),
                                Column(
                                  children: [
                                    _buildDetailRow(
                                      'Given Quantity',
                                      '${widget.stock.givenQuantity}',
                                      valueColor: Colors.blue.shade700,
                                    ),
                                    _buildDetailRow(
                                      'Sold Quantity',
                                      '${widget.stock.soldQuantity}',
                                      valueColor: Colors.orange.shade700,
                                    ),
                                    _buildDetailRow(
                                      'Balance',
                                      '${widget.stock.balanceQuantity}',
                                      valueColor: Colors.purple.shade700,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // Financial Values Section
                      _buildSectionTitle(
                        context,
                        'Financial Values',
                        Icons.account_balance_wallet,
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: _buildDetailRow(
                              'Total Value',
                              '₦${widget.stock.totalGivenValue?.toStringAsFixed(2) ?? '0.00'}',
                              valueColor: Colors.green.shade700,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildDetailRow(
                              'Sold Value',
                              '₦${widget.stock.totalSoldValue?.toStringAsFixed(2) ?? '0.00'}',
                              valueColor: Colors.blue.shade700,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildDetailRow(
                              'Balance Value',
                              '₦${widget.stock.balanceValue?.toStringAsFixed(2) ?? '0.00'}',
                              valueColor: Colors.purple.shade700,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // Sale History Section
                      _buildSectionTitle(
                          context, 'Sale History', Icons.history),
                      _buildSalesHistoryTable(),
                    ],
                  ),
                ),
              ),
            ],
          )),
    );
  }
}
