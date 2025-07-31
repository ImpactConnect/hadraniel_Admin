import 'package:flutter/material.dart';
import '../../core/models/customer_model.dart';
import '../../core/services/customer_service.dart';
import '../../core/services/sync_service.dart';

class EditCustomerDialog extends StatefulWidget {
  final Customer customer;
  final Function(Customer) onCustomerUpdated;

  const EditCustomerDialog({
    super.key,
    required this.customer,
    required this.onCustomerUpdated,
  });

  @override
  State<EditCustomerDialog> createState() => _EditCustomerDialogState();
}

class _EditCustomerDialogState extends State<EditCustomerDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  String? _selectedOutletId;
  bool _isLoading = false;

  late CustomerService _customerService;
  late SyncService _syncService;
  List<Map<String, String>> _outlets = [];

  @override
  void initState() {
    super.initState();
    _customerService = CustomerService();
    _syncService = SyncService();

    // Initialize controllers with existing customer data
    _nameController = TextEditingController(text: widget.customer.fullName);
    _phoneController = TextEditingController(text: widget.customer.phone ?? '');
    _selectedOutletId = widget.customer.outletId;

    _loadOutlets();
  }

  Future<void> _loadOutlets() async {
    try {
      final outlets = await _syncService.fetchAllLocalOutlets();
      setState(() {
        _outlets = outlets
            .map(
              (outlet) => {
                'id': outlet.id,
                'name': outlet.name ?? 'Unknown Outlet',
              },
            )
            .toList();
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading outlets: $e')));
    }
  }

  Future<void> _updateCustomer() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final updatedCustomer = Customer(
        id: widget.customer.id,
        fullName: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        outletId: _selectedOutletId,
        createdAt: widget.customer.createdAt,
      );

      await _customerService.updateCustomer(updatedCustomer);
      widget.onCustomerUpdated(updatedCustomer);
      Navigator.of(context).pop();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error updating customer: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Edit Customer',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter customer name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedOutletId,
                decoration: const InputDecoration(
                  labelText: 'Assigned Outlet',
                  border: OutlineInputBorder(),
                ),
                items: _outlets.map((outlet) {
                  return DropdownMenuItem(
                    value: outlet['id'],
                    child: Text(outlet['name'] ?? ''),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedOutletId = value;
                  });
                },
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _updateCustomer,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Update Customer'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }
}
