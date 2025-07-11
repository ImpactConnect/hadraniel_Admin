import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../core/models/product_model.dart';
import '../../core/models/outlet_model.dart';
import '../../core/services/sync_service.dart';

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
  late String productName;
  late String unit;
  late double quantity;
  late double costPerUnit;
  late String outletId;
  String? description;

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

  @override
  void initState() {
    super.initState();
    productName = widget.product?.productName ?? '';
    unit = widget.product?.unit ?? 'Kg';
    quantity = widget.product?.quantity ?? 0.0;
    costPerUnit = widget.product?.costPerUnit ?? 0.0;
    outletId = widget.product?.outletId ?? '';
    description = widget.product?.description;
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
                      optionsBuilder: (TextEditingValue textEditingValue) {
                        if (textEditingValue.text.isEmpty) {
                          return [
                            'Add New Product',
                            ..._getPreloadedProductNames(),
                          ];
                        }
                        return _getPreloadedProductNames()
                            .where(
                              (product) => product.toLowerCase().contains(
                                textEditingValue.text.toLowerCase(),
                              ),
                            )
                            .toList()
                          ..insert(0, 'Add New Product');
                      },
                      onSelected: (String value) {
                        if (value == 'Add New Product') {
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('New Product Name'),
                              content: TextFormField(
                                autofocus: true,
                                onChanged: (value) =>
                                    setState(() => productName = value),
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
                          setState(() => productName = value);
                        }
                      },
                      fieldViewBuilder:
                          (
                            context,
                            textEditingController,
                            focusNode,
                            onFieldSubmitted,
                          ) {
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
                        DropdownMenuItem(value: 'Carton', child: Text('Carton')),
                        DropdownMenuItem(value: 'Paint', child: Text('Paint')),
                        DropdownMenuItem(value: 'Cup', child: Text('Cup')),
                        DropdownMenuItem(value: 'other', child: Text('Add New Unit'))
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
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value?.isEmpty ?? true) return 'Required field';
                        if (double.tryParse(value!) == null)
                          return 'Invalid number';
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
