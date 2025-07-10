import 'package:flutter/material.dart';
import 'package:hadraniel_admin/core/models/outlet_model.dart';
import 'package:hadraniel_admin/core/models/product_model.dart';
import 'package:hadraniel_admin/core/services/product_service.dart';
import 'package:hadraniel_admin/core/services/sync_service.dart';
import 'package:uuid/uuid.dart';
import 'sidebar.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final ProductService _productService = ProductService();
  final SyncService _syncService = SyncService();
  final _searchController = TextEditingController();

  List<Product> _products = [];
  List<Outlet> _outlets = [];
  String _selectedOutletId = '';
  bool _isLoading = false;
  String _searchQuery = '';

  final List<String> _predefinedProducts = [
    'Chicken',
    'Turkey',
    'Gari',
    'Titus',
    'Shawa',
    'Egg',
    'Beef',
    'Goat meat',
  ];

  final List<String> _predefinedUnits = ['KG', 'PCS', 'Carton', 'Paint', 'Cup'];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final outlets = await _syncService.getAllLocalOutlets();
      final products = await _productService.getAllProducts();
      setState(() {
        _outlets = outlets;
        _products = products;
        if (outlets.isNotEmpty && _selectedOutletId.isEmpty) {
          _selectedOutletId = outlets.first.id;
        }
      });
    } catch (e) {
      _showError('Error loading data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _syncProducts() async {
    setState(() => _isLoading = true);
    try {
      await _productService.fetchProductsFromSupabase();
      await _loadData();
      _showSuccess('Products synced successfully');
    } catch (e) {
      _showError('Error syncing products: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showProductDialog({Product? product}) {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(
      text: product?.productName ?? '',
    );
    final quantityController = TextEditingController(
      text: product?.quantity.toString() ?? '',
    );
    final unitController = TextEditingController(text: product?.unit ?? '');
    final costPerUnitController = TextEditingController(
      text: product?.costPerUnit.toString() ?? '',
    );
    final descriptionController = TextEditingController(
      text: product?.description ?? '',
    );
    String selectedOutletId = product?.outletId ?? _selectedOutletId;
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(product == null ? 'Add New Product' : 'Edit Product'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Autocomplete<String>(
                    optionsBuilder: (TextEditingValue textEditingValue) {
                      return _predefinedProducts.where(
                        (product) => product.toLowerCase().contains(
                          textEditingValue.text.toLowerCase(),
                        ),
                      );
                    },
                    onSelected: (String selection) {
                      nameController.text = selection;
                    },
                    fieldViewBuilder:
                        (context, controller, focusNode, onFieldSubmitted) {
                          return TextFormField(
                            controller: nameController,
                            focusNode: focusNode,
                            decoration: const InputDecoration(
                              labelText: 'Product Name',
                            ),
                            validator: (value) => value?.isEmpty ?? true
                                ? 'Required field'
                                : null,
                          );
                        },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: quantityController,
                    decoration: const InputDecoration(labelText: 'Quantity'),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value?.isEmpty ?? true) return 'Required field';
                      if (double.tryParse(value!) == null)
                        return 'Invalid number';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  Autocomplete<String>(
                    optionsBuilder: (TextEditingValue textEditingValue) {
                      return _predefinedUnits.where(
                        (unit) => unit.toLowerCase().contains(
                          textEditingValue.text.toLowerCase(),
                        ),
                      );
                    },
                    onSelected: (String selection) {
                      unitController.text = selection;
                    },
                    fieldViewBuilder:
                        (context, controller, focusNode, onFieldSubmitted) {
                          return TextFormField(
                            controller: unitController,
                            focusNode: focusNode,
                            decoration: const InputDecoration(
                              labelText: 'Unit',
                            ),
                            validator: (value) => value?.isEmpty ?? true
                                ? 'Required field'
                                : null,
                          );
                        },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: costPerUnitController,
                    decoration: const InputDecoration(
                      labelText: 'Cost per Unit',
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value?.isEmpty ?? true) return 'Required field';
                      if (double.tryParse(value!) == null)
                        return 'Invalid number';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedOutletId,
                    decoration: const InputDecoration(labelText: 'Outlet'),
                    items: _outlets.map((outlet) {
                      return DropdownMenuItem(
                        value: outlet.id,
                        child: Text(outlet.name),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() => selectedOutletId = value!);
                    },
                    validator: (value) =>
                        value?.isEmpty ?? true ? 'Required field' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: descriptionController,
                    decoration: const InputDecoration(labelText: 'Description'),
                    maxLines: 3,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      if (formKey.currentState?.validate() ?? false) {
                        setState(() => isLoading = true);
                        try {
                          final quantity = double.parse(
                            quantityController.text,
                          );
                          final costPerUnit = double.parse(
                            costPerUnitController.text,
                          );
                          final totalCost = quantity * costPerUnit;

                          final newProduct = Product(
                            id: product?.id ?? const Uuid().v4(),
                            productName: nameController.text,
                            quantity: quantity,
                            unit: unitController.text,
                            costPerUnit: costPerUnit,
                            totalCost: totalCost,
                            dateAdded: product?.dateAdded ?? DateTime.now(),
                            lastUpdated: DateTime.now(),
                            description: descriptionController.text,
                            outletId: selectedOutletId,
                            createdAt: product?.createdAt ?? DateTime.now(),
                          );

                          if (product == null) {
                            await _productService.insertProduct(newProduct);
                          } else {
                            await _productService.updateProduct(newProduct);
                          }

                          Navigator.pop(context);
                          _loadData();
                          _showSuccess(
                            product == null
                                ? 'Product created successfully'
                                : 'Product updated successfully',
                          );
                        } catch (e) {
                          _showError('Error: $e');
                          setState(() => isLoading = false);
                        }
                      }
                    },
              child: isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(product == null ? 'Create' : 'Update'),
            ),
          ],
        ),
      ),
    );
  }

  void _showProductDetails(Product product) {
    final outlet = _outlets.firstWhere(
      (o) => o.id == product.outletId,
      orElse: () => Outlet(
        id: '',
        name: 'Unknown',
        location: null,
        createdAt: DateTime.now(),
      ),
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(product.productName),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Name: ${product.productName}'),
            Text('Quantity: ${product.quantity} ${product.unit}'),
            Text('Cost per Unit: \$${product.costPerUnit.toStringAsFixed(2)}'),
            Text('Total Cost: \$${product.totalCost.toStringAsFixed(2)}'),
            Text('Date Added: ${product.dateAdded.toString().split('.')[0]}'),
            if (product.lastUpdated != null)
              Text(
                'Last Updated: ${product.lastUpdated.toString().split('.')[0]}',
              ),
            if (product.description?.isNotEmpty ?? false)
              Text('Description: ${product.description}'),
            Text('Outlet: ${outlet.name}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final filteredProducts = _products.where((product) {
      final matchesSearch = product.productName.toLowerCase().contains(
        _searchQuery.toLowerCase(),
      );
      final matchesOutlet =
          _selectedOutletId.isEmpty || product.outletId == _selectedOutletId;
      return matchesSearch && matchesOutlet;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Products'),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            onPressed: _isLoading ? null : _syncProducts,
            tooltip: 'Sync Products',
          ),
        ],
      ),
      drawer: Sidebar(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          decoration: const InputDecoration(
                            labelText: 'Search Products',
                            prefixIcon: Icon(Icons.search),
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (value) =>
                              setState(() => _searchQuery = value),
                        ),
                      ),
                      const SizedBox(width: 16),
                      DropdownButton<String>(
                        value: _selectedOutletId.isEmpty
                            ? null
                            : _selectedOutletId,
                        hint: const Text('All Outlets'),
                        items: [
                          const DropdownMenuItem(
                            value: '',
                            child: Text('All Outlets'),
                          ),
                          ..._outlets.map(
                            (outlet) => DropdownMenuItem(
                              value: outlet.id,
                              child: Text(outlet.name),
                            ),
                          ),
                        ],
                        onChanged: (value) =>
                            setState(() => _selectedOutletId = value ?? ''),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: filteredProducts.isEmpty
                      ? const Center(
                          child: Text(
                            'No products found',
                            style: TextStyle(fontSize: 16),
                          ),
                        )
                      : SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            columns: const [
                              DataColumn(label: Text('Name')),
                              DataColumn(label: Text('Quantity')),
                              DataColumn(label: Text('Unit')),
                              DataColumn(label: Text('Cost/Unit')),
                              DataColumn(label: Text('Total Cost')),
                              DataColumn(label: Text('Outlet')),
                              DataColumn(label: Text('Actions')),
                            ],
                            rows: filteredProducts.map((product) {
                              final outlet = _outlets.firstWhere(
                                (o) => o.id == product.outletId,
                                orElse: () => Outlet(
                                  id: '',
                                  name: 'Unknown',
                                  location: null,
                                  createdAt: DateTime.now(),
                                ),
                              );
                              return DataRow(
                                cells: [
                                  DataCell(Text(product.productName)),
                                  DataCell(Text(product.quantity.toString())),
                                  DataCell(Text(product.unit)),
                                  DataCell(
                                    Text(
                                      '\$${product.costPerUnit.toStringAsFixed(2)}',
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      '\$${product.totalCost.toStringAsFixed(2)}',
                                    ),
                                  ),
                                  DataCell(Text(outlet.name)),
                                  DataCell(
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.visibility),
                                          onPressed: () =>
                                              _showProductDetails(product),
                                          tooltip: 'View Details',
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.edit),
                                          onPressed: () => _showProductDialog(
                                            product: product,
                                          ),
                                          tooltip: 'Edit Product',
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete),
                                          onPressed: () async {
                                            final confirm = await showDialog(
                                              context: context,
                                              builder: (context) => AlertDialog(
                                                title: const Text(
                                                  'Confirm Delete',
                                                ),
                                                content: Text(
                                                  'Delete ${product.productName}?',
                                                ),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () =>
                                                        Navigator.pop(
                                                          context,
                                                          false,
                                                        ),
                                                    child: const Text('Cancel'),
                                                  ),
                                                  TextButton(
                                                    onPressed: () =>
                                                        Navigator.pop(
                                                          context,
                                                          true,
                                                        ),
                                                    child: const Text(
                                                      'Delete',
                                                      style: TextStyle(
                                                        color: Colors.red,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );

                                            if (confirm == true) {
                                              await _productService
                                                  .deleteProduct(product.id);
                                              _loadData();
                                              _showSuccess(
                                                'Product deleted successfully',
                                              );
                                            }
                                          },
                                          tooltip: 'Delete Product',
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showProductDialog(),
        tooltip: 'Add New Product',
        child: const Icon(Icons.add),
      ),
    );
  }
}
