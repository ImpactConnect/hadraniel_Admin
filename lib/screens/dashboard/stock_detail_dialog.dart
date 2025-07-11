import 'package:flutter/material.dart';
import '../../core/models/outlet_model.dart';
import '../../core/models/product_model.dart';
import '../../core/models/stock_balance_model.dart';

class StockDetailDialog extends StatelessWidget {
  final StockBalance stock;
  final Product product;
  final Outlet outlet;

  const StockDetailDialog({
    super.key,
    required this.stock,
    required this.product,
    required this.outlet,
  });

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Text(value),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.6,
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Stock Details',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 16),
            _buildDetailRow('Product Name', product.productName),
            _buildDetailRow('Outlet', outlet.name),
            _buildDetailRow('Given Quantity', '${stock.givenQuantity}'),
            _buildDetailRow('Sold Quantity', '${stock.soldQuantity}'),
            _buildDetailRow('Balance', '${stock.balanceQuantity}'),
            _buildDetailRow('Cost Price', '₦${product.costPerUnit}'),
            _buildDetailRow(
              'Total Value',
              '₦${stock.totalGivenValue?.toStringAsFixed(2) ?? '0.00'}',
            ),
            _buildDetailRow(
              'Sold Value',
              '₦${stock.totalSoldValue?.toStringAsFixed(2) ?? '0.00'}',
            ),
            _buildDetailRow(
              'Balance Value',
              '₦${stock.balanceValue?.toStringAsFixed(2) ?? '0.00'}',
            ),
            const SizedBox(height: 24),
            Text(
              'Sale History',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            // Placeholder for sale history
            const Center(
              child: Text(
                'Sale history will be displayed here',
                style: TextStyle(fontStyle: FontStyle.italic),
              ),
            ),
          ],
        ),
      ),
    );
  }
}