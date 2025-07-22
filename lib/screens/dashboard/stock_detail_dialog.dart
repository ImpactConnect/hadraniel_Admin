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

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 15,
              color: Colors.grey.shade800,
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0, top: 8.0),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary, size: 22),
          const SizedBox(width: 8),
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
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: MaterialStateProperty.all(
            Theme.of(context).colorScheme.primary.withOpacity(0.1),
          ),
          columns: const [
            DataColumn(label: Text('Date')),
            DataColumn(label: Text('Outlet')),
            DataColumn(label: Text('Customer')),
            DataColumn(label: Text('Quantity')),
            DataColumn(label: Text('Total Cost')),
          ],
          rows: _salesHistory.map((sale) {
            final saleDate = DateTime.parse(sale['created_at']);
            return DataRow(
              cells: [
                DataCell(Text(DateFormat('yyyy-MM-dd').format(saleDate))),
                DataCell(Text(sale['outlet_name'] ?? 'N/A')),
                DataCell(Text(sale['customer_name'] ?? 'N/A')),
                DataCell(Text(sale['quantity']?.toString() ?? '0')),
                DataCell(
                  Text('₦${(sale['total_amount'] ?? 0.0).toStringAsFixed(2)}'),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 5,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.8,
        padding: const EdgeInsets.all(24.0),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Stock Details',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.close,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              Divider(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                thickness: 1,
              ),
              const SizedBox(height: 16),

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
                        Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              children: [
                                _buildDetailRow(
                                  'Product Name',
                                  widget.product.productName,
                                ),
                                _buildDetailRow('Outlet', widget.outlet.name),
                                _buildDetailRow(
                                  'Cost Price',
                                  '₦${widget.product.costPerUnit}',
                                ),
                              ],
                            ),
                          ),
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
                        Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              children: [
                                _buildDetailRow(
                                  'Given Quantity',
                                  '${widget.stock.givenQuantity}',
                                ),
                                _buildDetailRow(
                                  'Sold Quantity',
                                  '${widget.stock.soldQuantity}',
                                ),
                                _buildDetailRow(
                                  'Balance',
                                  '${widget.stock.balanceQuantity}',
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Financial Values Section
              _buildSectionTitle(
                context,
                'Financial Values',
                Icons.account_balance_wallet,
              ),
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12.0),
                          decoration: BoxDecoration(
                            border: Border(
                              right: BorderSide(
                                color: Colors.grey.shade200,
                                width: 1,
                              ),
                            ),
                          ),
                          child: _buildDetailRow(
                            'Total Value',
                            '₦${widget.stock.totalGivenValue?.toStringAsFixed(2) ?? '0.00'}',
                          ),
                        ),
                      ),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12.0),
                          decoration: BoxDecoration(
                            border: Border(
                              right: BorderSide(
                                color: Colors.grey.shade200,
                                width: 1,
                              ),
                            ),
                          ),
                          child: _buildDetailRow(
                            'Sold Value',
                            '₦${widget.stock.totalSoldValue?.toStringAsFixed(2) ?? '0.00'}',
                          ),
                        ),
                      ),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12.0),
                          child: _buildDetailRow(
                            'Balance Value',
                            '₦${widget.stock.balanceValue?.toStringAsFixed(2) ?? '0.00'}',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Sale History Section
              _buildSectionTitle(context, 'Sale History', Icons.history),
              _buildSalesHistoryTable(),
            ],
          ),
        ),
      ),
    );
  }
}
