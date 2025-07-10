import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/models/customer_model.dart';
import '../../core/services/customer_service.dart';
import '../../core/services/sync_service.dart';

class CustomerDetailsDialog extends StatefulWidget {
  final Customer customer;

  const CustomerDetailsDialog({super.key, required this.customer});

  @override
  State<CustomerDetailsDialog> createState() => _CustomerDetailsDialogState();
}

class _CustomerDetailsDialogState extends State<CustomerDetailsDialog> {
  late CustomerService _customerService;
  late SyncService _syncService;
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
      // TODO: Initialize services properly
      // final outletName = await _syncService.getOutletName(widget.customer.outletId ?? '');
      // final history = await _customerService.getCustomerPurchaseHistory(widget.customer.id);

      setState(() {
        _outletName = '-'; // Replace with actual outlet name
        _purchaseHistory = []; // Replace with actual purchase history
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading customer details: $e')),
      );
    }
  }

  Future<void> _deleteCustomer() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Customer'),
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
    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 800),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.customer.fullName,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: () {
                        // TODO: Implement edit functionality
                      },
                      icon: const Icon(Icons.edit),
                      label: const Text('Edit'),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: _deleteCustomer,
                      icon: const Icon(Icons.delete),
                      label: const Text('Delete'),
                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _DetailCard(
                            title: 'Phone Number',
                            value: widget.customer.phone ?? '-',
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _DetailCard(
                            title: 'Assigned Outlet',
                            value: _outletName,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _DetailCard(
                            title: 'Outstanding Balance',
                            value:
                                '₦${NumberFormat('#,##0.00').format(widget.customer.totalOutstanding)}',
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _DetailCard(
                            title: 'Created At',
                            value: DateFormat(
                              'yyyy-MM-dd',
                            ).format(widget.customer.createdAt),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Purchase History',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: _purchaseHistory.isEmpty
                          ? const Center(
                              child: Text('No purchase history available'),
                            )
                          : ListView.builder(
                              itemCount: _purchaseHistory.length,
                              itemBuilder: (context, index) {
                                final purchase = _purchaseHistory[index];
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  child: ListTile(
                                    title: Text(
                                      DateFormat('yyyy-MM-dd').format(
                                        DateTime.parse(purchase['date']),
                                      ),
                                    ),
                                    subtitle: Text(
                                      purchase['items'].toString(),
                                    ),
                                    trailing: Text(
                                      '₦${NumberFormat('#,##0.00').format(purchase['amount'])}',
                                    ),
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
    );
  }
}

class _DetailCard extends StatelessWidget {
  final String title;
  final String value;

  const _DetailCard({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(fontSize: 16)),
          ],
        ),
      ),
    );
  }
}
