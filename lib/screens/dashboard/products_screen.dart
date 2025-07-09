import 'package:flutter/material.dart';
import '../../core/models/product_model.dart';
import '../../core/services/sync_service.dart';
import 'sidebar.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final SyncService _syncService = SyncService();
  List<Product> _products = [];
  String _searchQuery = '';
  String? _selectedOutlet;
  String? _selectedUnit;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    // TODO: Implement get products from SyncService
    setState(() {
      _products = [];
    });
  }

  void _showProductDialog({Product? product}) {
    final formKey = GlobalKey<FormState>();
    String name = product?.name ?? '';
    String unit = product?.unit ?? '';
    double price = product?.price ?? 0.0;
    List<String> selectedOutlets = product?.outletIds ?? [];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(product == null ? 'Add New Product' : 'Edit Product'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                initialValue: name,
                decoration: const InputDecoration(labelText: 'Product Name'),
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Required field' : null,
                onSaved: (value) => name = value ?? '',
              ),
              TextFormField(
                initialValue: unit,
                decoration: const InputDecoration(labelText: 'Unit'),
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Required field' : null,
                onSaved: (value) => unit = value ?? '',
              ),
              TextFormField(
                initialValue: price.toString(),
                decoration: const InputDecoration(labelText: 'Price'),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value?.isEmpty ?? true) return 'Required field';
                  if (double.tryParse(value!) == null) return 'Invalid number';
                  return null;
                },
                onSaved: (value) => price = double.parse(value!),
              ),
              // TODO: Add outlet selection widget
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                formKey.currentState?.save();
                // TODO: Implement product creation/update logic
                Navigator.pop(context);
                _loadProducts(); // Refresh the list
              }
            },
            child: Text(product == null ? 'Add' : 'Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    var filteredProducts = _products.where(
      (product) =>
          product.name.toLowerCase().contains(_searchQuery.toLowerCase()),
    );

    if (_selectedOutlet != null) {
      filteredProducts = filteredProducts.where(
        (product) => product.outletIds.contains(_selectedOutlet),
      );
    }

    if (_selectedUnit != null) {
      filteredProducts = filteredProducts.where(
        (product) => product.unit == _selectedUnit,
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Products')),
      drawer: Sidebar(),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Search Products',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (value) => setState(() => _searchQuery = value),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedOutlet,
                        decoration: const InputDecoration(
                          labelText: 'Filter by Outlet',
                        ),
                        items: const [
                          // TODO: Add outlet items
                        ],
                        onChanged: (value) =>
                            setState(() => _selectedOutlet = value),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedUnit,
                        decoration: const InputDecoration(
                          labelText: 'Filter by Unit',
                        ),
                        items: const [
                          // TODO: Add unit items
                        ],
                        onChanged: (value) =>
                            setState(() => _selectedUnit = value),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: filteredProducts.length,
              itemBuilder: (context, index) {
                final product = filteredProducts.elementAt(index);
                return ListTile(
                  leading: const Icon(Icons.inventory),
                  title: Text(product.name),
                  subtitle: Text(
                    '${product.unit} - \$${product.price.toStringAsFixed(2)}',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () => _showProductDialog(product: product),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showProductDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
