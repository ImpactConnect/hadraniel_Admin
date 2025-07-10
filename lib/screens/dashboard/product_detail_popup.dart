import 'package:flutter/material.dart';
import '../../core/models/product_model.dart';

class ProductDetailPopup extends StatelessWidget {
  final Product product;

  const ProductDetailPopup({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        padding: const EdgeInsets.all(16.0),
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  product.productName,
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
            _buildDetailRow('Quantity', '${product.quantity} ${product.unit}'),
            _buildDetailRow(
              'Cost per Unit',
              '\$${product.costPerUnit.toStringAsFixed(2)}',
            ),
            _buildDetailRow(
              'Total Cost',
              '\$${product.totalCost.toStringAsFixed(2)}',
            ),
            if (product.description != null)
              _buildDetailRow('Description', product.description!),
            _buildDetailRow('Date Added', _formatDate(product.dateAdded)),
            if (product.lastUpdated != null)
              _buildDetailRow(
                'Last Updated',
                _formatDate(product.lastUpdated!),
              ),
            _buildDetailRow('Created At', _formatDate(product.createdAt)),
            _buildDetailRow(
              'Sync Status',
              product.isSynced ? 'Synced' : 'Not Synced',
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
