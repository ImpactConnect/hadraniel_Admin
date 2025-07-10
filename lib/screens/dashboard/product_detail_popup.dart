import 'package:flutter/material.dart';
import '../../core/models/product_model.dart';

class ProductDetailPopup extends StatelessWidget {
  final Product product;
  final Function() onEdit;
  final Function() onDelete;

  const ProductDetailPopup({
    super.key,
    required this.product,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        padding: const EdgeInsets.all(16.0),
        constraints: const BoxConstraints(maxWidth: 500),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    product.productName,
                    style: Theme.of(context).textTheme.headlineSmall,
                    overflow: TextOverflow.ellipsis,
                  ),
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
            if (product.description != null && product.description!.isNotEmpty)
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
              trailing: Icon(
                product.isSynced ? Icons.cloud_done : Icons.cloud_off,
                color: product.isSynced ? Colors.green : Colors.grey,
                size: 20,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.edit),
                  label: const Text('Edit'),
                  onPressed: () {
                    Navigator.of(context).pop();
                    onEdit();
                  },
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  label: const Text(
                    'Delete',
                    style: TextStyle(color: Colors.red),
                  ),
                  onPressed: () {
                    Navigator.of(context).pop();
                    onDelete();
                  },
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {Widget? trailing}) {
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
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
