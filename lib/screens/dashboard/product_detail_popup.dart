import 'package:flutter/material.dart';
import '../../core/models/product_model.dart';
import '../../core/services/sync_service.dart';
import 'package:intl/intl.dart';

class ProductDetailPopup extends StatelessWidget {
  final Product product;
  final Function() onEdit;
  final Function() onDelete;
  final SyncService _syncService = SyncService();

  ProductDetailPopup({
    super.key,
    required this.product,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 8,
      child: Container(
        width: 600,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with product name and actions
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Product Details',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.edit, color: colorScheme.primary),
                      onPressed: onEdit,
                      tooltip: 'Edit Product',
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () {
                        Navigator.of(context).pop();
                        onDelete();
                      },
                      tooltip: 'Delete Product',
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: Colors.grey[700]),
                      onPressed: () => Navigator.of(context).pop(),
                      tooltip: 'Close',
                    ),
                  ],
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 16),

            // Product information in a card
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Product name with icon
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: colorScheme.primary.withOpacity(0.1),
                          radius: 24,
                          child: Icon(
                            Icons.inventory_2,
                            color: colorScheme.primary,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                product.productName,
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                'ID: ${product.id}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Product details in a grid layout
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left column
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildDetailRow(
                                context,
                                'Quantity',
                                '${product.quantity} ${product.unit}',
                                Icons.shopping_basket,
                                colorScheme.primary,
                              ),
                              const SizedBox(height: 16),
                              _buildDetailRow(
                                context,
                                'Cost Per Unit',
                                '\$${product.costPerUnit.toStringAsFixed(2)}',
                                Icons.attach_money,
                                Colors.green[700]!,
                              ),
                              const SizedBox(height: 16),
                              _buildDetailRow(
                                context,
                                'Total Cost',
                                '\$${(product.quantity * product.costPerUnit).toStringAsFixed(2)}',
                                Icons.calculate,
                                Colors.indigo,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 24),
                        // Right column
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              FutureBuilder<String>(
                                future: _syncService.getOutletName(
                                  product.outletId,
                                ),
                                builder: (context, snapshot) {
                                  return _buildDetailRow(
                                    context,
                                    'Assigned Outlet',
                                    snapshot.data ?? 'Loading...',
                                    Icons.store,
                                    Colors.orange[700]!,
                                  );
                                },
                              ),
                              const SizedBox(height: 16),
                              _buildDetailRow(
                                context,
                                'Date Added',
                                _formatDate(product.dateAdded),
                                Icons.calendar_today,
                                Colors.blue[700]!,
                              ),
                              const SizedBox(height: 16),
                              _buildDetailRow(
                                context,
                                'Last Updated',
                                _formatDate(product.createdAt),
                                Icons.update,
                                Colors.purple[700]!,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Description section
                    if (product.description != null &&
                        product.description!.isNotEmpty) ...[
                      Text(
                        'Description',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: colorScheme.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Text(
                          product.description ?? '',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),

                    // Sync status
                    Row(
                      children: [
                        Icon(
                          product.isSynced ? Icons.cloud_done : Icons.cloud_off,
                          color: product.isSynced ? Colors.green : Colors.grey,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          product.isSynced ? 'Synced to cloud' : 'Not synced',
                          style: TextStyle(
                            color: product.isSynced
                                ? Colors.green
                                : Colors.grey,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Close button
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color iconColor,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
