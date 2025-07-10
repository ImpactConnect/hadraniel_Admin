import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../../core/models/product_model.dart';
import '../../core/models/outlet_model.dart';
import '../../core/services/sync_service.dart';
import 'sidebar.dart';
import 'product_detail_popup.dart';

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
  bool _isSyncing = false;

  List<String> _getPreloadedProductNames() {
    return [
      'Sardine 2-4',
      'Sardine 3-5',
      'Sardine 2SLT',
      'Argentine BIG',
      'Argentine Mideum',
      'Mackerel 3-5',
      'Mackerel 5-9',
      'Mackerel 9UP',
      'Shawa Box',
      'Shawa 150-200 2SLT',
      'Shawa 200-250',
      'Shawa 250-300',
      'Shawa 300+ 22KG',
      'Shawa P Ocean Spirit',
      'Shawa SMT',
      'Shawa Cornelius',
      'Alaska',
      'Argentine',
      'Mulet',
      'Hake 15KG',
      'Hake 10KG',
      'Turkey 306',
      'Turkey 305',
      'Turkey (Blanket)',
      'Full Chicken',
      'Chicken Half',
      'Chicken Breast',
      'Chicken Wings',
      'Chicken Laps',
      'Minal Sursage',
      'Golden Phonex',
      'Confidence Sausage',
      'Doux Sausage',
      'Gool Sausage',
      'Frangosul Sausage',
      'Gurme Sausage',
      'ByKeskin Sausage',
      'Premium Sausage',
      'Pena',
      'Sadia',
      'Perdix',
      'Seara',
      'Minu',
      'UME Sausage',
      'Tika',
      'Shrimps',
      'Cow Meat',
      'Goat Meat',
      'Elubo 0.50',
      'Elubo 1Kg',
      'Elubo 2Kg',
      'Shawama / Lebanese Bread',
      'Puff Puff Mix',
      'Spring Roll',
      'Samosa',
      'Garri Ijebu Drinking Bag',
      'Garri Ijebu Drinking 1Kg',
      'Garri Ijebu Drinking 2Kg',
      'Garri Ijebu Drinking Mudu',
      'Garri Ijebu Drinking Paint',
      'Garri Lebu/Swallow 1Kg',
      'Garri Lebu/Swallow 2Kg',
      'Garri Lebu/Swallow Bag',
      'Garri Lebu/Swallow Mudu',
      'Garri Lebu/Swallow Paint',
      'Vegitable Mixed 450g',
      'Vegitable Mixed 400g',
      'Palm Oil 5L',
      'Palm Oil 10L',
      'Palm Oil 20L',
      'Pomo Ice',
      'Pomo Dry Big',
      'Pomo Dry Small',
      'Egg',
      'Kulikuli Big',
      'Kulikuli Small',
      'Kulikuli Mudu',
      'Panla BW Africa Medium',
      'Panla BW Africa Big',
      'Panla BW Africa Small',
      'Panla BW PP',
      'Panla BW 30KG 3Slates',
      'Crocker Large',
      'Croker Medium',
      'American Paco / Tilapia',
      'Original Tilapia',
      'Chicken Gizzard',
      'Turkey Gizzard',
      'Potato Cips',
      'Crabs',
      'Prawns',
      'Frolic Tomato Ketchup',
      'Heinz Tomato Ketchup',
      'Alfa Tomato Ketchup',
      'Light Soy Sauce',
      'Dark Soy Sauce',
      'Premium Oyster Sauce',
      'Sweet Chilli Sauce',
      'Prawn Crackers Chips',
      'Bay Leaves Big',
      'Bay Leaves Medium',
      'Bay Leaves Pieces',
      'Green Giant (Sweet Corn) 425ml',
      'Green Giant (Sweet Corn) 212ml',
      'Bakeon Baking Powder 100g',
      'Bama Mayonnaise 226ml',
      'Bama Mayonnaise 385ml',
      'Bama Mayonnaise 810ml',
      'Jago Mayonnaise 443ml',
      'Laziz Salad Cream 285gm',
      'Laziz Salad Cream gm',
      'Ground Black Pepper',
      'Ground Light/White Pepper',
      'Royal Wrap Aluminium Foil Papper 8m',
      'Know Seasoning Cubes/Beef',
      'Know Seasoning Chicken',
      'Mr Chef Beef Flavour',
      'Mr Chef Mixed Spices Cubes',
      'Maggi Star Seasoning Cube',
      'Maggi Star Chicken Flavour',
      'Maggi Jollof Seasoning Powder',
      'Advance Cken Chicken Seasoning Powder',
      'Mivina Chicken seasoning Powder',
      'Tiger Tomato Stew Mix',
      'Spicity Seasoning Powder Stew & Jollof 100g',
      'Spicity Seasoning Powder Stew & Jollof 10g',
      'Spicity Seasoning Powder Fried Rice 10g',
      'Mr Chef Seasoning Tomato Mix Powder',
      'Deco Seasoning Aromat Chicken',
      'Mr Chef Jollof Saghetti Seasoning Powder',
      'Mr Chef Seasoning Goat Meat Powder 10g',
      'Ama Wonda Curry 5g',
      'Ama Wonda Jollof Rice Spice 5g',
      'Ama Wonda Fried Rice Spice 5g',
      'Larsor Fish Seasoning 10g',
      'Larsor Beef Seasoning 10g',
      'Larsor Chicken Seasoning 10g',
      'Larsor Peppersoup Seasoning 10g',
      'Larsoe Fried Rice Seasoning 10g',
      'Addme All Purpose Beef Flavour Seasoning 10g',
      'Addme All Purpose Chicken Flavour Seasoning 10g',
      'Tasty Tom 2in1 Seasoning Beef Powder 11g',
      'Tasty Tom 2in1 Seasoning Chicken Powder 11g',
      'Kitchen Glory Fish Seasoning Powder 10g',
      'Kitchen Glory Chicken Seasoning Powder 10g',
      'Mr Chef Crayfish Seasoning Powder 10g',
      'Tiger Nutmeg Powder 10g',
      'Intergrated Ingredients Mixed Spices 10g',
      'Gino Curry Powder',
      'Gino Dried Thyme',
      'Forza Chicken Seasoning Powder 10g',
      'Forza Jollof Seasoning Powder 10g',
      'Dahir Spices Curry Powder 5g',
      'Tiger Curry Masala',
      'Vitals Ginger Garlic Powder 5g',
      'Mr Chef Ginger Onion Garlic Seasoning Powder 10g',
      'Mr Chef Mixed Spices Seasoning Powder 10g',
      'Gino Party Jollof Tomato Seasoning Mix Paste',
      'Gino Peppered Chicken Flavoured Tomato Seasoning Mix Paste',
      'Tasty Tom Tomato Mix Paste',
      'Tasty Tom Jollof Mix Paste',
    ];
  }

  Future<void> _syncProducts() async {
    setState(() => _isSyncing = true);
    try {
      await _syncService.syncProductsToLocalDb();
      await _loadProducts();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Products synced successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error syncing products: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _loadProducts();
    _loadOutlets();
  }

  Future<void> _loadOutlets() async {
    try {
      await _syncService.syncOutletsToLocalDb();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading outlets: $e')));
      }
    }
  }

  Future<void> _deleteProduct(Product product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Product'),
        content: Text(
          'Are you sure you want to delete ${product.productName}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed ?? false) {
      try {
        await _syncService.deleteProduct(product.id);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Product deleted successfully')),
        );
        _loadProducts(); // Refresh the list
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error deleting product: $e')));
      }
    }
  }

  Future<void> _loadProducts() async {
    try {
      final products = await _syncService.getAllLocalProducts();
      if (mounted) {
        setState(() {
          _products = products;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading products: $e')));
      }
    }
  }

  void _showProductDialog({Product? product}) {
    final formKey = GlobalKey<FormState>();
    String productName = product?.productName ?? '';
    String unit = product?.unit ?? 'KG';
    double quantity = product?.quantity ?? 0.0;
    double costPerUnit = product?.costPerUnit ?? 0.0;
    String outletId = product?.outletId ?? '';
    String? description = product?.description;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(product == null ? 'Add New Product' : 'Edit Product'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: productName.isEmpty ? null : productName,
                decoration: const InputDecoration(labelText: 'Product Name'),
                items:
                    _getPreloadedProductNames()
                        .map(
                          (name) =>
                              DropdownMenuItem(value: name, child: Text(name)),
                        )
                        .toList()
                      ..add(
                        const DropdownMenuItem(
                          value: 'other',
                          child: Text('Add New Product'),
                        ),
                      ),
                onChanged: (value) {
                  if (value == 'other') {
                    // Show text field for new product name
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('New Product Name'),
                        content: TextFormField(
                          autofocus: true,
                          onChanged: (value) => productName = value,
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('OK'),
                          ),
                        ],
                      ),
                    );
                  } else {
                    productName = value ?? '';
                  }
                },
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Required field' : null,
              ),
              DropdownButtonFormField<String>(
                value: unit,
                decoration: const InputDecoration(labelText: 'Unit'),
                items:
                    ['KG', 'PCS', 'Carton', 'Paint', 'Cup']
                        .map(
                          (unit) =>
                              DropdownMenuItem(value: unit, child: Text(unit)),
                        )
                        .toList()
                      ..add(
                        const DropdownMenuItem(
                          value: 'other',
                          child: Text('Add New Unit'),
                        ),
                      ),
                onChanged: (value) {
                  if (value == 'other') {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('New Unit'),
                        content: TextFormField(
                          autofocus: true,
                          onChanged: (value) => unit = value,
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('OK'),
                          ),
                        ],
                      ),
                    );
                  } else {
                    unit = value ?? 'KG';
                  }
                },
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Required field' : null,
              ),
              TextFormField(
                initialValue: quantity.toString(),
                decoration: const InputDecoration(labelText: 'Quantity'),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value?.isEmpty ?? true) return 'Required field';
                  if (double.tryParse(value!) == null) return 'Invalid number';
                  return null;
                },
                onSaved: (value) => quantity = double.parse(value!),
              ),
              TextFormField(
                initialValue: costPerUnit.toString(),
                decoration: const InputDecoration(labelText: 'Cost per Unit'),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value?.isEmpty ?? true) return 'Required field';
                  if (double.tryParse(value!) == null) return 'Invalid number';
                  return null;
                },
                onSaved: (value) => costPerUnit = double.parse(value!),
              ),
              TextFormField(
                initialValue: description,
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 3,
                onSaved: (value) => description = value,
              ),
              // Outlet selection
              FutureBuilder(
                future: _syncService.getAllLocalOutlets(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const CircularProgressIndicator();
                  }
                  final outlets = snapshot.data!;
                  return DropdownButtonFormField<String>(
                    value: outletId.isEmpty ? null : outletId,
                    decoration: const InputDecoration(labelText: 'Outlet'),
                    items: outlets
                        .map(
                          (outlet) => DropdownMenuItem(
                            value: outlet.id,
                            child: Text(outlet.name),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => outletId = value ?? '',
                    validator: (value) =>
                        value?.isEmpty ?? true ? 'Required field' : null,
                  );
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              if (formKey.currentState?.validate() ?? false) {
                formKey.currentState?.save();
                final now = DateTime.now();
                final newProduct = Product(
                  id: product?.id ?? const Uuid().v4(),
                  productName: productName,
                  quantity: quantity,
                  unit: unit,
                  costPerUnit: costPerUnit,
                  totalCost: quantity * costPerUnit,
                  dateAdded: product?.dateAdded ?? now,
                  lastUpdated: now,
                  description: description,
                  outletId: outletId,
                  createdAt: product?.createdAt ?? now,
                );

                try {
                  if (product == null) {
                    await _syncService.insertProduct(newProduct);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Product added successfully'),
                        ),
                      );
                    }
                  } else {
                    await _syncService.updateProduct(newProduct);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Product updated successfully'),
                        ),
                      );
                    }
                  }
                  if (mounted) {
                    Navigator.pop(context);
                    await _loadProducts(); // Refresh the list
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error saving product: $e')),
                    );
                  }
                }
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
      (product) => product.productName.toLowerCase().contains(
        _searchQuery.toLowerCase(),
      ),
    );

    if (_selectedOutlet != null) {
      filteredProducts = filteredProducts.where(
        (product) => product.outletId == _selectedOutlet,
      );
    }

    if (_selectedUnit != null) {
      filteredProducts = filteredProducts.where(
        (product) => product.unit == _selectedUnit,
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Products'),
        actions: [
          IconButton(
            icon: _isSyncing
                ? const CircularProgressIndicator(color: Colors.white)
                : const Icon(Icons.sync),
            onPressed: _isSyncing ? null : _syncProducts,
          ),
        ],
      ),
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
                      child: FutureBuilder<List<Outlet>>(
                        future: _syncService.getAllLocalOutlets(),
                        builder: (context, snapshot) {
                          if (snapshot.hasError) {
                            return const Text('Error loading outlets');
                          }
                          final outlets = snapshot.data ?? [];
                          return DropdownButtonFormField<String>(
                            value: _selectedOutlet,
                            decoration: const InputDecoration(
                              labelText: 'Filter by Outlet',
                            ),
                            items: [
                              const DropdownMenuItem(
                                value: null,
                                child: Text('All Outlets'),
                              ),
                              ...outlets.map(
                                (outlet) => DropdownMenuItem(
                                  value: outlet.id,
                                  child: Text(outlet.name),
                                ),
                              ),
                            ],
                            onChanged: (value) =>
                                setState(() => _selectedOutlet = value),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedUnit,
                        decoration: const InputDecoration(
                          labelText: 'Filter by Unit',
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('All Units'),
                          ),
                          ...['KG', 'PCS', 'Carton', 'Paint', 'Cup'].map(
                            (unit) => DropdownMenuItem(
                              value: unit,
                              child: Text(unit),
                            ),
                          ),
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
            child: PrimaryScrollController(
              controller: ScrollController(),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SingleChildScrollView(
                  controller: ScrollController(),
                  child: Theme(
                    data: Theme.of(context).copyWith(
                      dataTableTheme: DataTableThemeData(
                        headingRowColor: MaterialStateProperty.all(
                          Theme.of(context).colorScheme.primary.withOpacity(0.1),
                        ),
                      ),
                    ),
                    child: DataTable(
                    columns: const [
                      DataColumn(label: Text('Product Name')),
                      DataColumn(label: Text('Unit')),
                      DataColumn(label: Text('Quantity')),
                      DataColumn(label: Text('Cost/Unit')),
                      DataColumn(label: Text('Assigned Outlet')),
                      DataColumn(label: Text('Total Cost')),
                      DataColumn(label: Text('Date Added')),
                      DataColumn(label: Text('Date Updated')),
                      DataColumn(label: Text('Sync Status')),
                      DataColumn(label: Text('Actions')),
                    ],
                    rows: filteredProducts.map((product) {
                      final totalCost = product.quantity * product.costPerUnit;
                      return DataRow(
                        cells: [
                          DataCell(Text(product.productName)),
                          DataCell(Text(product.unit)),
                          DataCell(Text(product.quantity.toString())),
                          DataCell(
                            Text('\$${product.costPerUnit.toStringAsFixed(2)}'),
                          ),
                          DataCell(
                            FutureBuilder<String>(
                              future: _syncService.getOutletName(
                                product.outletId,
                              ),
                              builder: (context, snapshot) {
                                if (snapshot.hasData) {
                                  return Text(snapshot.data!);
                                }
                                return const Text('Loading...');
                              },
                            ),
                          ),
                          DataCell(Text('\$${totalCost.toStringAsFixed(2)}')),
                          DataCell(
                            Text(
                              DateFormat(
                                'yyyy-MM-dd',
                              ).format(product.dateAdded),
                            ),
                          ),
                          DataCell(
                            Text(
                              DateFormat(
                                'yyyy-MM-dd',
                              ).format(product.createdAt),
                            ),
                          ),
                          DataCell(
                            Icon(
                              product.isSynced
                                  ? Icons.cloud_done
                                  : Icons.cloud_off,
                              color: product.isSynced
                                  ? Colors.green
                                  : Colors.grey,
                            ),
                          ),
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.visibility, size: 20),
                                  onPressed: () => showDialog(
                                    context: context,
                                    builder: (context) =>
                                        ProductDetailPopup(product: product),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.edit, size: 20),
                                  onPressed: () =>
                                      _showProductDialog(product: product),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, size: 20),
                                  onPressed: () => _deleteProduct(product),
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
            ),
          ),
          )
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showProductDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
