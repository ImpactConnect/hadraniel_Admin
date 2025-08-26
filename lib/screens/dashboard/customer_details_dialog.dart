import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/models/customer_model.dart';
import '../../core/services/customer_service.dart';
import '../../core/services/sync_service.dart';
import 'edit_customer_dialog.dart';

class CustomerDetailsDialog extends StatefulWidget {
  final Customer customer;

  const CustomerDetailsDialog({super.key, required this.customer});

  @override
  State<CustomerDetailsDialog> createState() => _CustomerDetailsDialogState();
}

class _CustomerDetailsDialogState extends State<CustomerDetailsDialog> {
  final CustomerService _customerService = CustomerService();
  final SyncService _syncService = SyncService();
  String _outletName = '-';
  List<Map<String, dynamic>> _purchaseHistory = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCustomerDetails();
  }

  Future<void> _loadCustomerDetails() async {
    try {
      // Load outlet name if customer has an outlet assigned
      if (widget.customer.outletId != null &&
          widget.customer.outletId!.isNotEmpty) {
        final outletName =
            await _syncService.getOutletName(widget.customer.outletId!);
        _outletName = outletName;
      }

      // Load customer purchase history
      final history =
          await _customerService.getCustomerPurchaseHistory(widget.customer.id);

      setState(() {
        _purchaseHistory = history;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading customer details: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading customer details: $e')),
        );
      }
    }
  }

  Future<void> _deleteCustomer() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Delete Customer',
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
        content: const Text('Are you sure you want to delete this customer?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed ?? false) {
      try {
        await _customerService.deleteCustomer(widget.customer.id);
        Navigator.of(context).pop(true); // Return true to indicate deletion
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error deleting customer: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 5,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 800, maxHeight: 800),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.person,
                        color: colorScheme.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      widget.customer.fullName,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) => EditCustomerDialog(
                            customer: widget.customer,
                            onCustomerUpdated: (updatedCustomer) {
                              setState(() {
                                // Note: Since Customer fields are final, we would need to
                                // update the parent widget or reload from database
                              });
                              _loadCustomerDetails(); // Reload customer details if changed
                            },
                          ),
                        );
                      },
                      icon: const Icon(Icons.edit),
                      label: const Text('Edit'),
                      style: ElevatedButton.styleFrom(
                        foregroundColor: colorScheme.onPrimary,
                        backgroundColor: colorScheme.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: _deleteCustomer,
                      icon: const Icon(Icons.delete),
                      label: const Text('Delete'),
                      style: ElevatedButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: colorScheme.error,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: Icon(Icons.close, color: colorScheme.primary),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ],
            ),
            Divider(color: colorScheme.primary.withOpacity(0.2), thickness: 1),
            const SizedBox(height: 24),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Compact Customer Information
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            colorScheme.primary.withOpacity(0.1),
                            colorScheme.primary.withOpacity(0.05),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: colorScheme.primary.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Phone',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color:
                                        colorScheme.onSurface.withOpacity(0.6),
                                  ),
                                ),
                                Text(
                                  widget.customer.phone ?? '-',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Outlet',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color:
                                        colorScheme.onSurface.withOpacity(0.6),
                                  ),
                                ),
                                Text(
                                  _outletName,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Outstanding',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color:
                                        colorScheme.onSurface.withOpacity(0.6),
                                  ),
                                ),
                                Text(
                                  '₦${NumberFormat('#,##0.00').format(widget.customer.totalOutstanding)}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: widget.customer.totalOutstanding > 0
                                        ? Colors.red.shade700
                                        : Colors.green.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Created',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color:
                                        colorScheme.onSurface.withOpacity(0.6),
                                  ),
                                ),
                                Text(
                                  DateFormat('MMM dd, yyyy')
                                      .format(widget.customer.createdAt),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Icon(
                          Icons.history,
                          color: colorScheme.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Purchase History',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.primary,
                          ),
                        ),
                        const Spacer(),
                        if (_purchaseHistory.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: colorScheme.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${_purchaseHistory.length} transactions',
                              style: TextStyle(
                                fontSize: 12,
                                color: colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: _purchaseHistory.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.receipt_long,
                                      size: 48,
                                      color: Colors.grey.shade400,
                                    ),
                                    const SizedBox(height: 16),
                                    const Text(
                                      'No purchase history available',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontStyle: FontStyle.italic,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : Column(
                                children: [
                                  // Table Header
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color:
                                          colorScheme.primary.withOpacity(0.1),
                                      borderRadius: const BorderRadius.only(
                                        topLeft: Radius.circular(12),
                                        topRight: Radius.circular(12),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          flex: 2,
                                          child: Text(
                                            'Date',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: colorScheme.primary,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 3,
                                          child: Text(
                                            'Items Purchased',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: colorScheme.primary,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 2,
                                          child: Text(
                                            'Amount Paid',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: colorScheme.primary,
                                              fontSize: 14,
                                            ),
                                            textAlign: TextAlign.right,
                                          ),
                                        ),
                                        Expanded(
                                          flex: 2,
                                          child: Text(
                                            'Outstanding',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: colorScheme.primary,
                                              fontSize: 14,
                                            ),
                                            textAlign: TextAlign.right,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Table Body
                                  Expanded(
                                    child: ListView.builder(
                                      itemCount: _purchaseHistory.length,
                                      itemBuilder: (context, index) {
                                        final purchase =
                                            _purchaseHistory[index];
                                        final isEven = index % 2 == 0;

                                        return Container(
                                          padding: const EdgeInsets.all(16),
                                          decoration: BoxDecoration(
                                            color: isEven
                                                ? Colors.grey.shade50
                                                : Colors.white,
                                            border: Border(
                                              bottom: BorderSide(
                                                color: Colors.grey.shade200,
                                                width: 0.5,
                                              ),
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              // Date
                                              Expanded(
                                                flex: 2,
                                                child: Text(
                                                  DateFormat('MMM dd, yyyy')
                                                      .format(
                                                    DateTime.parse(
                                                        purchase['date']),
                                                  ),
                                                  style: const TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ),
                                              // Items Purchased
                                              Expanded(
                                                flex: 3,
                                                child: Tooltip(
                                                  message: purchase[
                                                          'items_detail'] ??
                                                      'No items',
                                                  child: Text(
                                                    purchase['product_names'] ??
                                                        'No items',
                                                    style: const TextStyle(
                                                      fontSize: 13,
                                                    ),
                                                    maxLines: 2,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ),
                                              // Amount Paid
                                              Expanded(
                                                flex: 2,
                                                child: Text(
                                                  '₦${NumberFormat('#,##0.00').format((purchase['amount_paid'] as num?)?.toDouble() ?? 0.0)}',
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w600,
                                                    color:
                                                        Colors.green.shade700,
                                                  ),
                                                  textAlign: TextAlign.right,
                                                ),
                                              ),
                                              // Outstanding
                                              Expanded(
                                                flex: 2,
                                                child: Builder(
                                                  builder: (context) {
                                                    final outstandingAmount =
                                                        (purchase['outstanding_amount']
                                                                    as num?)
                                                                ?.toDouble() ??
                                                            0.0;
                                                    return Text(
                                                      '₦${NumberFormat('#,##0.00').format(outstandingAmount)}',
                                                      style: TextStyle(
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color:
                                                            outstandingAmount >
                                                                    0
                                                                ? Colors.red
                                                                    .shade700
                                                                : Colors.green
                                                                    .shade700,
                                                      ),
                                                      textAlign:
                                                          TextAlign.right,
                                                    );
                                                  },
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  // Summary Footer
                                  if (_purchaseHistory.isNotEmpty)
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: colorScheme.primary
                                            .withOpacity(0.05),
                                        borderRadius: const BorderRadius.only(
                                          bottomLeft: Radius.circular(12),
                                          bottomRight: Radius.circular(12),
                                        ),
                                        border: Border(
                                          top: BorderSide(
                                            color: colorScheme.primary
                                                .withOpacity(0.2),
                                            width: 1,
                                          ),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            flex: 5,
                                            child: Text(
                                              'Total (${_purchaseHistory.length} transactions)',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: colorScheme.primary,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 2,
                                            child: Text(
                                              '₦${NumberFormat('#,##0.00').format(_purchaseHistory.fold<double>(0, (sum, p) => sum + ((p['amount_paid'] as num?)?.toDouble() ?? 0.0)))}',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: Colors.green.shade700,
                                                fontSize: 14,
                                              ),
                                              textAlign: TextAlign.right,
                                            ),
                                          ),
                                          Expanded(
                                            flex: 2,
                                            child: Builder(
                                              builder: (context) {
                                                final totalOutstanding =
                                                    _purchaseHistory.fold<
                                                            double>(
                                                        0,
                                                        (sum, p) =>
                                                            sum +
                                                            ((p['outstanding_amount']
                                                                        as num?)
                                                                    ?.toDouble() ??
                                                                0.0));
                                                return Text(
                                                  '₦${NumberFormat('#,##0.00').format(totalOutstanding)}',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color: totalOutstanding > 0
                                                        ? Colors.red.shade700
                                                        : Colors.green.shade700,
                                                    fontSize: 14,
                                                  ),
                                                  textAlign: TextAlign.right,
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
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
