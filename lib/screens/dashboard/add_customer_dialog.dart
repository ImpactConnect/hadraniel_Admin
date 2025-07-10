import 'package:flutter/material.dart';
import '../../core/models/customer_model.dart';
import '../../core/services/customer_service.dart';
import '../../core/services/sync_service.dart';

class AddCustomerDialog extends StatefulWidget {
  final Function(Customer) onCustomerAdded;

  const AddCustomerDialog({super.key, required this.onCustomerAdded});

  @override
  State<AddCustomerDialog> createState() => _AddCustomerDialogState();
}

class _AddCustomerDialogState extends State<AddCustomerDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
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
    _loadOutlets();
  }

  Future<void> _loadOutlets() async {
    try {
      final outlets = await _syncService.fetchAllLocalOutlets();
      setState(() {
        _outlets = outlets.map((outlet) => {
          'id': outlet.id,
          'name': outlet.name ?? 'Unknown Outlet',
        }).toList();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading outlets: $e')),
      );
    }
  }

  Future<void> _saveCustomer() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final customer = Customer(
        fullName: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        outletId: _selectedOutletId,
      );

      final savedCustomer = await _customerService.createCustomer(customer);
      widget.onCustomerAdded(savedCustomer);
      Navigator.of(context).pop();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error saving customer: $e')));
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
                    'Add New Customer',
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
                onPressed: _isLoading ? null : _saveCustomer,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save Customer'),
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
