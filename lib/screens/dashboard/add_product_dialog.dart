import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../core/models/product_model.dart';
import '../../core/models/outlet_model.dart';
import '../../core/services/sync_service.dart';
import '../../core/services/stock_intake_service.dart';

class AddProductDialog extends StatefulWidget {
  final Product? product;
  final Function onProductSaved;

  const AddProductDialog({
    super.key,
    this.product,
    required this.onProductSaved,
  });

  @override
  State<AddProductDialog> createState() => _AddProductDialogState();
}

class _AddProductDialogState extends State<AddProductDialog> {
  final SyncService _syncService = SyncService();
  final formKey = GlobalKey<FormState>();
  final TextEditingController _productNameController = TextEditingController();
  bool _isNewProduct = false;
  late String productName;
  late String unit;
  late double quantity;
  late double costPerUnit;
  late String outletId;
  String? description;

  // Cache for product names with balance
  List<String>? _cachedProductNames;
  // Cache for product balances
  Map<String, double>? _cachedProductBalances;

  // Get the available balance for a product
  double getAvailableBalance(String productName) {
    return _cachedProductBalances?[productName] ?? 0.0;
  }

  Future<List<String>> _getPreloadedProductNames() async {
    // Return cached product names if available
    if (_cachedProductNames != null) {
      return _cachedProductNames!;
    }

    try {
      // Import the StockIntakeService to get products with balance
      final stockIntakeService = StockIntakeService();

      // Get products with balance > 0 along with their balances
      final productsWithBalance = await stockIntakeService
          .getAvailableProductsWithBalance();

      // Cache the balances
      _cachedProductBalances = productsWithBalance;

      // Cache the product names with balance information
      _cachedProductNames = productsWithBalance.keys.map((name) {
        final balance = productsWithBalance[name]!;
        final unit = widget.product?.unit ?? 'Kg'; // Default unit
        return '$name (${balance.toStringAsFixed(2)}$unit left)';
      }).toList();

      return _cachedProductNames!;
    } catch (e) {
      print('Error fetching products with balance: $e');
      // Return an empty list in case of error
      return [];
    }
  }

  // Extract the actual product name from the display string
  String extractProductName(String displayName) {
    // Check if the string contains balance information
    final balanceIndex = displayName.lastIndexOf(' (');
    if (balanceIndex > 0) {
      return displayName.substring(0, balanceIndex);
    }
    return displayName;
  }

  @override
  void initState() {
    super.initState();
    productName = widget.product?.productName ?? '';
    _productNameController.text = productName;
    _isNewProduct = widget.product == null;
    unit = widget.product?.unit ?? 'Kg';
    quantity = widget.product?.quantity ?? 0.0;
    costPerUnit = widget.product?.costPerUnit ?? 0.0;
    outletId = widget.product?.outletId ?? '';
    description = widget.product?.description;
  }

  @override
  void dispose() {
    _productNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.6,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.product == null ? 'Add New Product' : 'Edit Product',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Form(
              key: formKey,
              child: Wrap(
                spacing: 20,
                runSpacing: 20,
                children: [
                  SizedBox(
                    width: 300,
                    child: Autocomplete<String>(
                      initialValue: TextEditingValue(text: productName),
                      optionsBuilder:
                          (TextEditingValue textEditingValue) async {
                            // Get product names with balance
                            final productNames =
                                await _getPreloadedProductNames();

                            if (textEditingValue.text.isEmpty) {
                              return ['Add New Product', ...productNames];
                            }
                            return productNames
                                .where(
                                  (product) => product.toLowerCase().contains(
                                    textEditingValue.text.toLowerCase(),
                                  ),
                                )
                                .toList()
                              ..insert(0, 'Add New Product');
                          },
                      onSelected: (String selection) {
                        if (selection == 'Add New Product') {
                          setState(() {
                            _isNewProduct = true;
                            productName = '';
                            _productNameController.text = '';
                          });
                        } else {
                          // Extract the actual product name from the display string
                          final actualProductName = extractProductName(
                            selection,
                          );

                          setState(() {
                            _isNewProduct = false;
                            productName = actualProductName;
                            _productNameController.text = selection;
                          });
                        }
                      },
                      fieldViewBuilder:
                          (
                            context,
                            textEditingController,
                            focusNode,
                            onFieldSubmitted,
                          ) {
                            // Initialize the controller with our stored value
                            if (_productNameController.text.isNotEmpty &&
                                textEditingController.text.isEmpty) {
                              textEditingController.text =
                                  _productNameController.text;
                            }

                            return TextFormField(
                              controller: textEditingController,
                              focusNode: focusNode,
                              decoration: InputDecoration(
                                labelText: 'Product Name',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                filled: true,
                                fillColor: Colors.grey[50],
                              ),
                              onChanged: (value) {
                                // Keep our controller in sync
                                _productNameController.text = value;
                                productName = value;
                              },
                              validator: (value) => value?.isEmpty ?? true
                                  ? 'Required field'
                                  : null,
                            );
                          },
                    ),
                  ),
                  SizedBox(
                    width: 300,
                    child: DropdownButtonFormField<String>(
                      value: unit,
                      decoration: InputDecoration(
                        labelText: 'Unit',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                      items: const [
                        DropdownMenuItem(value: 'Kg', child: Text('Kg')),
                        DropdownMenuItem(value: 'PCS', child: Text('PCS')),
                        DropdownMenuItem(
                          value: 'Carton',
                          child: Text('Carton'),
                        ),
                        DropdownMenuItem(value: 'Paint', child: Text('Paint')),
                        DropdownMenuItem(value: 'Cup', child: Text('Cup')),
                        DropdownMenuItem(
                          value: 'other',
                          child: Text('Add New Unit'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == 'other') {
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('New Unit'),
                              content: TextFormField(
                                autofocus: true,
                                onChanged: (value) =>
                                    setState(() => unit = value),
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
                          setState(() => unit = value ?? 'Kg');
                        }
                      },
                      validator: (value) =>
                          value?.isEmpty ?? true ? 'Required field' : null,
                    ),
                  ),
                  SizedBox(
                    width: 300,
                    child: TextFormField(
                      initialValue: quantity.toString(),
                      decoration: InputDecoration(
                        labelText: 'Quantity',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                        // Show the available balance in the helper text
                        helperText: !_isNewProduct
                            ? 'Available: ${getAvailableBalance(productName).toStringAsFixed(2)} ${unit}'
                            : null,
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value?.isEmpty ?? true) return 'Required field';
                        if (double.tryParse(value!) == null)
                          return 'Invalid number';

                        // Check if quantity exceeds available balance for existing products
                        if (!_isNewProduct) {
                          final requestedQuantity = double.parse(value);
                          final availableBalance = getAvailableBalance(
                            productName,
                          );

                          if (requestedQuantity > availableBalance) {
                            return 'Exceeds available balance of ${availableBalance.toStringAsFixed(2)} ${unit}';
                          }
                        }
                        return null;
                      },
                      onSaved: (value) => quantity = double.parse(value!),
                    ),
                  ),
                  SizedBox(
                    width: 300,
                    child: TextFormField(
                      initialValue: costPerUnit.toString(),
                      decoration: InputDecoration(
                        labelText: 'Cost per Unit',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value?.isEmpty ?? true) return 'Required field';
                        if (double.tryParse(value!) == null)
                          return 'Invalid number';
                        return null;
                      },
                      onSaved: (value) => costPerUnit = double.parse(value!),
                    ),
                  ),
                  SizedBox(
                    width: 300,
                    child: TextFormField(
                      initialValue: description,
                      decoration: InputDecoration(
                        labelText: 'Description',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                      maxLines: 3,
                      onSaved: (value) => description = value,
                    ),
                  ),
                  SizedBox(
                    width: 300,
                    child: FutureBuilder<List<Outlet>>(
                      future: _syncService.getAllLocalOutlets(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        final outlets = snapshot.data!;
                        return DropdownButtonFormField<String>(
                          value: outletId.isEmpty ? null : outletId,
                          decoration: InputDecoration(
                            labelText: 'Outlet',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            filled: true,
                            fillColor: Colors.grey[50],
                          ),
                          items: outlets
                              .map(
                                (outlet) => DropdownMenuItem(
                                  value: outlet.id,
                                  child: Text(outlet.name),
                                ),
                              )
                              .toList(),
                          onChanged: (value) =>
                              setState(() => outletId = value ?? ''),
                          validator: (value) =>
                              value?.isEmpty ?? true ? 'Required field' : null,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () async {
                    if (formKey.currentState?.validate() ?? false) {
                      formKey.currentState?.save();
                      final now = DateTime.now();
                      final newProduct = Product(
                        id: widget.product?.id ?? const Uuid().v4(),
                        productName: productName,
                        quantity: quantity,
                        unit: unit,
                        costPerUnit: costPerUnit,
                        totalCost: quantity * costPerUnit,
                        dateAdded: widget.product?.dateAdded ?? now,
                        lastUpdated: now,
                        description: description,
                        outletId: outletId,
                        createdAt: widget.product?.createdAt ?? now,
                      );

                      try {
                        if (widget.product == null) {
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
                          widget.onProductSaved();
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
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(widget.product == null ? 'Add' : 'Save'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
