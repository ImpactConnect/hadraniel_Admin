import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/models/stock_intake_model.dart';
import '../core/models/intake_balance_model.dart';
import '../core/models/product_distribution_model.dart';
import '../core/services/stock_intake_service.dart';
import '../core/services/sync_service.dart';
import '../core/database/database_helper.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/loading_indicator.dart';
import '../widgets/custom_date_picker.dart';
import '../screens/dashboard/sidebar.dart';

class StockIntakeScreen extends StatefulWidget {
  const StockIntakeScreen({Key? key}) : super(key: key);

  @override
  _StockIntakeScreenState createState() => _StockIntakeScreenState();
}

class _StockIntakeScreenState extends State<StockIntakeScreen>
    with SingleTickerProviderStateMixin {
  final StockIntakeService _stockIntakeService = StockIntakeService();
  final SyncService _syncService = SyncService();
  final _formKey = GlobalKey<FormState>();
  final _productNameController = TextEditingController();
  final _quantityController = TextEditingController();
  final _costPerUnitController = TextEditingController();
  final _descriptionController = TextEditingController();

  List<StockIntake> _stockIntakes = [];
  List<IntakeBalance> _intakeBalances = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedUnit = 'Pcs';
  DateTime? _startDate;
  DateTime? _endDate;
  final TextEditingController _searchController = TextEditingController();

  // Tab controller
  late TabController _tabController;

  // Balance tab specific variables
  String _balanceSearchQuery = '';
  final TextEditingController _balanceSearchController =
      TextEditingController();
  String _sortColumn = 'productName';
  bool _sortAscending = true;
  String _balanceFilter = 'all'; // 'all', 'positive', 'zero', 'negative'

  final List<String> _units = [
    'Pcs',
    'Kg',
    'L',
    'Box',
    'Carton',
    '1/2 Carton',
    'Bag'
  ];

  // List of predefined product names

  // List of predefined product names
  List<String> _predefinedProducts = [
    // Custom products added by user will be inserted at the top
  ];

  // Base predefined products list
  final List<String> _basePredefinedProducts = [
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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      // This is called when the tab changes, forcing a rebuild of the UI
      // which will update the FloatingActionButton visibility
      setState(() {});
    });
    _initializeProductsList();
    _loadData();
  }

  Future<void> _initializeProductsList() async {
    await _loadCustomProducts();
    // Combine custom products with base predefined products
    _predefinedProducts = [
      ...await _getCustomProducts(),
      ..._basePredefinedProducts
    ];
  }

  Future<List<String>> _getCustomProducts() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList('custom_products') ?? [];
  }

  Future<void> _loadCustomProducts() async {
    final customProducts = await _getCustomProducts();
    setState(() {
      _predefinedProducts = [...customProducts, ..._basePredefinedProducts];
    });
  }

  Future<void> _saveCustomProduct(String productName) async {
    final prefs = await SharedPreferences.getInstance();
    final customProducts = await _getCustomProducts();

    // Add the new product if it doesn't already exist
    if (!customProducts.contains(productName) &&
        !_basePredefinedProducts.contains(productName)) {
      customProducts.insert(0, productName); // Add to the beginning
      await prefs.setStringList('custom_products', customProducts);

      // Update the predefined products list
      setState(() {
        _predefinedProducts = [...customProducts, ..._basePredefinedProducts];
      });
    }
  }

  @override
  void dispose() {
    _productNameController.dispose();
    _quantityController.dispose();
    _costPerUnitController.dispose();
    _descriptionController.dispose();
    _searchController.dispose();
    _balanceSearchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Ensure tables are created before querying
      await _stockIntakeService.createStockIntakeTable();
      await _stockIntakeService.createIntakeBalancesTable();

      // First try to get data from local database
      final stockIntakes = await _stockIntakeService.getAllIntakes();
      final intakeBalances = await _stockIntakeService.getAllIntakeBalances();

      // If local database is empty, sync from Supabase
      if (stockIntakes.isEmpty && intakeBalances.isEmpty) {
        try {
          await _syncService.syncStockIntakesToLocalDb();
          // Note: syncStockIntakesToLocalDb() already handles intake balance calculation
          // Reload data after syncing
          final syncedStockIntakes = await _stockIntakeService.getAllIntakes();
          final syncedIntakeBalances =
              await _stockIntakeService.getAllIntakeBalances();

          setState(() {
            _stockIntakes = syncedStockIntakes;
            _intakeBalances = syncedIntakeBalances;
            _isLoading = false;
          });
        } catch (syncError) {
          print('Error syncing from Supabase: $syncError');
          // Still show local data even if sync fails
          setState(() {
            _stockIntakes = stockIntakes;
            _intakeBalances = intakeBalances;
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _stockIntakes = stockIntakes;
          _intakeBalances = intakeBalances;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading data: $e')));
      }
    }
  }

  void _showAddIntakeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Stock Intake'),
        content: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Autocomplete<String>(
                  optionsBuilder: (TextEditingValue textEditingValue) {
                    // Show all options when the field is empty
                    if (textEditingValue.text == '') {
                      return _predefinedProducts;
                    }

                    // Filter predefined products based on input
                    final filteredProducts =
                        _predefinedProducts.where((String option) {
                      return option.toLowerCase().contains(
                            textEditingValue.text.toLowerCase(),
                          );
                    }).toList();

                    // If the current text doesn't match any predefined product exactly,
                    // add it as a custom option at the top
                    final currentText = textEditingValue.text.trim();
                    if (currentText.isNotEmpty &&
                        !_predefinedProducts.any((product) =>
                            product.toLowerCase() ==
                            currentText.toLowerCase())) {
                      filteredProducts.insert(
                          0, '+ Add "$currentText" as new product');
                    }

                    return filteredProducts;
                  },
                  onSelected: (String selection) {
                    if (selection.startsWith('+ Add "')) {
                      // Extract the custom product name from the selection
                      final customProduct =
                          selection.substring(7, selection.length - 16);
                      _productNameController.text = customProduct;
                    } else {
                      _productNameController.text = selection;
                    }
                  },
                  fieldViewBuilder: (
                    BuildContext context,
                    TextEditingController controller,
                    FocusNode focusNode,
                    VoidCallback onFieldSubmitted,
                  ) {
                    // Assign the controller to our class controller
                    if (controller.text.isEmpty &&
                        _productNameController.text.isNotEmpty) {
                      controller.text = _productNameController.text;
                    } else if (_productNameController.text.isEmpty &&
                        controller.text.isNotEmpty) {
                      _productNameController.text = controller.text;
                    }

                    return TextFormField(
                      controller: controller,
                      focusNode: focusNode,
                      decoration: const InputDecoration(
                        labelText: 'Product Name',
                        border: OutlineInputBorder(),
                        hintText: 'Select from list or type new product name',
                        helperText:
                            'You can add custom products not in the predefined list',
                      ),
                      onChanged: (value) {
                        _productNameController.text = value;
                      },
                      onTap: () {
                        // This will trigger the optionsBuilder with empty text
                        // which will now show all options
                        if (controller.text.isEmpty) {
                          controller.text = '';
                          focusNode.requestFocus();
                        }
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter product name';
                        }
                        return null;
                      },
                    );
                  },
                  optionsViewBuilder: (
                    BuildContext context,
                    AutocompleteOnSelected<String> onSelected,
                    Iterable<String> options,
                  ) {
                    return Align(
                      alignment: Alignment.topLeft,
                      child: Material(
                        elevation: 4.0,
                        child: Container(
                          constraints: const BoxConstraints(maxHeight: 200),
                          width: 300,
                          child: ListView.builder(
                            padding: const EdgeInsets.all(8.0),
                            itemCount: options.length,
                            itemBuilder: (BuildContext context, int index) {
                              final String option = options.elementAt(
                                index,
                              );

                              // Check if this is a custom product option
                              final isCustomProduct =
                                  option.startsWith('+ Add "');

                              return ListTile(
                                leading: isCustomProduct
                                    ? const Icon(Icons.add_circle,
                                        color: Colors.green)
                                    : const Icon(Icons.inventory,
                                        color: Colors.blue),
                                title: Text(
                                  option,
                                  style: TextStyle(
                                    fontWeight: isCustomProduct
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    color: isCustomProduct
                                        ? Colors.green[700]
                                        : null,
                                  ),
                                ),
                                onTap: () {
                                  onSelected(option);
                                },
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  controller: _quantityController,
                  labelText: 'Quantity Received',
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter quantity';
                    }
                    if (double.tryParse(value) == null ||
                        double.parse(value) <= 0) {
                      return 'Please enter a valid quantity';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedUnit,
                  decoration: const InputDecoration(
                    labelText: 'Unit',
                    border: OutlineInputBorder(),
                  ),
                  items: _units.map((unit) {
                    return DropdownMenuItem<String>(
                      value: unit,
                      child: Text(unit),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedUnit = value!;
                    });
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please select a unit';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  controller: _costPerUnitController,
                  labelText: 'Cost Per Unit',
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter cost per unit';
                    }
                    if (double.tryParse(value) == null ||
                        double.parse(value) <= 0) {
                      return 'Please enter a valid cost';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  controller: _descriptionController,
                  labelText: 'Description (Optional)',
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
          ElevatedButton(onPressed: _addStockIntake, child: const Text('Add')),
        ],
      ),
    );
  }

  Future<void> _addStockIntake() async {
    if (_formKey.currentState!.validate()) {
      final productName = _productNameController.text.trim();
      final quantity = double.parse(_quantityController.text.trim());
      final costPerUnit = double.parse(_costPerUnitController.text.trim());
      final description = _descriptionController.text.trim();
      final totalCost = quantity * costPerUnit;

      // Save custom product if it's not in the predefined lists
      if (!_basePredefinedProducts.contains(productName)) {
        await _saveCustomProduct(productName);
      }

      final stockIntake = StockIntake(
        id: const Uuid().v4(),
        productName: productName,
        quantityReceived: quantity,
        unit: _selectedUnit,
        costPerUnit: costPerUnit,
        totalCost: totalCost,
        description: description,
        dateReceived: DateTime.now(),
        createdAt: DateTime.now(),
        isSynced: false,
      );

      try {
        await _stockIntakeService.addStockIntake(stockIntake);
        await _loadData();
        Navigator.pop(context);

        // Clear form fields
        _productNameController.clear();
        _quantityController.clear();
        _costPerUnitController.clear();
        _descriptionController.clear();
        setState(() {
          _selectedUnit = 'Pcs';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Stock intake added successfully')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding stock intake: $e')),
        );
      }
    }
  }

  void _showDateRangePicker() async {
    // Get the screen size
    final Size screenSize = MediaQuery.of(context).size;

    // Calculate the dialog size (70% of screen width, 60% of screen height)
    final double dialogWidth = screenSize.width * 0.7;
    final double dialogHeight = screenSize.height * 0.6;

    // Show a custom dialog with DateRangePicker inside
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            width: dialogWidth,
            height: dialogHeight,
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Select Date Range',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const Divider(),
                Expanded(
                  child: Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme: Theme.of(context).colorScheme.copyWith(
                            primary: Theme.of(context).colorScheme.primary,
                            onPrimary: Colors.white,
                          ),
                    ),
                    child: DateRangePickerDialog(
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                      initialDateRange: _startDate != null && _endDate != null
                          ? DateTimeRange(start: _startDate!, end: _endDate!)
                          : null,
                      saveText: 'APPLY',
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ).then((value) {
      if (value != null && value is DateTimeRange) {
        setState(() {
          _startDate = value.start;
          _endDate = value.end;
        });
      }
    });
  }

  void _clearDateFilter() {
    setState(() {
      _startDate = null;
      _endDate = null;
    });
  }

  // Helper function to format balance numbers with proper decimal places
  String _formatBalance(double value) {
    if (value == value.toInt()) {
      return value.toInt().toString();
    }
    // Round to 2 decimal places and remove trailing zeros
    String formatted = value.toStringAsFixed(2);
    formatted = formatted.replaceAll(RegExp(r'0*$'), '');
    formatted = formatted.replaceAll(RegExp(r'\.$'), '');
    return formatted;
  }

  void _showBalanceDetails(IntakeBalance balance) async {
    final colorScheme = Theme.of(context).colorScheme;
    final StockIntakeService _stockIntakeService = StockIntakeService();

    // Fetch distribution history for this product
    List<ProductDistribution> distributions =
        await _stockIntakeService.getProductDistributions(balance.productName);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  balance.productName.substring(0, 1).toUpperCase(),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${balance.productName} Balance Details',
                style: TextStyle(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Container(
          width: double.maxFinite,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product metrics cards in a row
              Row(
                children: [
                  Expanded(
                    child: _buildMetricsCard(
                      icon: Icons.inventory_2_outlined,
                      label: 'Total Received',
                      value: _formatBalance(balance.totalReceived),
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildMetricsCard(
                      icon: Icons.assignment_outlined,
                      label: 'Total Assigned',
                      value: _formatBalance(balance.totalAssigned),
                      color: Colors.orange,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildMetricsCard(
                      icon: Icons.account_balance_outlined,
                      label: 'Balance Quantity',
                      value: _formatBalance(balance.balanceQuantity),
                      color: balance.balanceQuantity > 0
                          ? Colors.green
                          : balance.balanceQuantity < 0
                              ? Colors.red
                              : Colors.grey,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildMetricsCard(
                      icon: Icons.calendar_today_outlined,
                      label: 'Last Updated',
                      value: DateFormat(
                        'MMM dd, yyyy',
                      ).format(balance.lastUpdated),
                      color: Colors.purple,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Distribution History',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(height: 8),
              distributions.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16.0),
                      child: Center(
                        child: Text(
                          'No distribution history available',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    )
                  : Expanded(
                      child: _buildDistributionHistoryTable(distributions),
                    ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDistributionHistoryTable(
    List<ProductDistribution> distributions,
  ) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          // Table header (sticky)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    'Outlet',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Quantity',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Date',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Table body (scrollable)
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: distributions.length,
              itemBuilder: (context, index) {
                final distribution = distributions[index];
                final bool isEven = index % 2 == 0;

                return Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 12,
                  ),
                  decoration: BoxDecoration(
                    color: isEven ? Colors.white : Colors.grey.shade50,
                    border: Border(
                      top: BorderSide(color: Colors.grey.shade200),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Text(
                          distribution.outletName,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          distribution.quantity.toString(),
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          DateFormat(
                            'MMM dd, yyyy',
                          ).format(distribution.distributionDate),
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<StockIntake> get _filteredStockIntakes {
    // First apply basic filters (search and date)
    List<StockIntake> filtered = _stockIntakes.where((intake) {
      // Apply search filter
      final searchQuery = _searchQuery.toLowerCase();
      final productNameMatch = intake.productName.toLowerCase().contains(
            searchQuery,
          );

      // Safely handle nullable description
      final description = intake.description;
      final descriptionMatch = description != null && description.isNotEmpty
          ? description.toLowerCase().contains(searchQuery)
          : false;

      final matchesSearch = productNameMatch || descriptionMatch;

      // Apply date filter
      bool matchesDate = true;
      if (_startDate != null && _endDate != null) {
        final intakeDate = DateTime(
          intake.dateReceived.year,
          intake.dateReceived.month,
          intake.dateReceived.day,
        );
        final startDate = DateTime(
          _startDate!.year,
          _startDate!.month,
          _startDate!.day,
        );
        final endDate = DateTime(
          _endDate!.year,
          _endDate!.month,
          _endDate!.day,
          23,
          59,
          59,
        );
        matchesDate = intakeDate.isAtSameMomentAs(startDate) ||
            intakeDate.isAtSameMomentAs(endDate) ||
            (intakeDate.isAfter(startDate) && intakeDate.isBefore(endDate));
      }

      return matchesSearch && matchesDate;
    }).toList();

    // Apply product filter
    if (_selectedProductFilter != 'All Products') {
      switch (_selectedProductFilter) {
        case 'Low Stock':
          // Filter for products with low stock (less than 10 units)
          final lowStockProducts = _intakeBalances
              .where((balance) => balance.balanceQuantity < 10)
              .map((balance) => balance.productName)
              .toSet();
          filtered = filtered
              .where((intake) => lowStockProducts.contains(intake.productName))
              .toList();
          break;
        case 'High Value':
          // Filter for high value products (cost per unit > 100)
          filtered =
              filtered.where((intake) => intake.costPerUnit > 100).toList();
          break;
        case 'Recently Added':
          // Filter for products added in the last 7 days
          final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
          filtered = filtered
              .where((intake) => intake.dateReceived.isAfter(sevenDaysAgo))
              .toList();
          break;
      }
    }

    // Apply sorting
    switch (_selectedSortOption) {
      case 'Date (Newest)':
        filtered.sort((a, b) => b.dateReceived.compareTo(a.dateReceived));
        break;
      case 'Date (Oldest)':
        filtered.sort((a, b) => a.dateReceived.compareTo(b.dateReceived));
        break;
      case 'Price (High-Low)':
        filtered.sort((a, b) => b.totalCost.compareTo(a.totalCost));
        break;
      case 'Price (Low-High)':
        filtered.sort((a, b) => a.totalCost.compareTo(b.totalCost));
        break;
      case 'Name (A-Z)':
        filtered.sort((a, b) => a.productName.compareTo(b.productName));
        break;
      case 'Name (Z-A)':
        filtered.sort((a, b) => b.productName.compareTo(a.productName));
        break;
    }

    return filtered;
  }

  double get _totalStockValue {
    return _filteredStockIntakes.fold(
      0,
      (sum, intake) => sum + intake.totalCost,
    );
  }

  Future<void> _exportBalancesToCSV() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final path =
          '${directory.path}/stock_balances_${DateTime.now().millisecondsSinceEpoch}.csv';
      final file = File(path);

      // Create CSV data
      List<List<dynamic>> rows = [];

      // Add header row
      rows.add([
        'Product Name',
        'Total Received',
        'Total Assigned',
        'Balance Quantity',
        'Last Updated',
      ]);

      // Add data rows
      for (var balance in _filteredBalances) {
        rows.add([
          balance.productName,
          balance.totalReceived,
          balance.totalAssigned,
          balance.balanceQuantity,
          DateFormat('yyyy-MM-dd').format(balance.lastUpdated),
        ]);
      }

      // Convert to CSV
      String csv = const ListToCsvConverter().convert(rows);

      // Write to file
      await file.writeAsString(csv);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('CSV exported to: $path')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error exporting CSV: $e')));
    }
  }

  Future<void> _exportBalancesToPDF() async {
    try {
      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          header: (pw.Context context) {
            return pw.Header(
              level: 0,
              child: pw.Text(
                'Stock Balance Report',
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            );
          },
          footer: (pw.Context context) {
            return pw.Footer(
              trailing: pw.Text(
                'Page ${context.pageNumber} of ${context.pagesCount}',
                style: pw.TextStyle(fontSize: 10),
              ),
            );
          },
          build: (pw.Context context) => [
            pw.Table.fromTextArray(
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              headerDecoration: pw.BoxDecoration(color: PdfColors.grey300),
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.center,
                2: pw.Alignment.center,
                3: pw.Alignment.center,
                4: pw.Alignment.center,
              },
              headers: [
                'Product Name',
                'Total Received',
                'Total Assigned',
                'Balance',
                'Last Updated',
              ],
              data: _filteredBalances.map((balance) {
                return [
                  balance.productName,
                  _formatBalance(balance.totalReceived),
                  _formatBalance(balance.totalAssigned),
                  _formatBalance(balance.balanceQuantity),
                  DateFormat('yyyy-MM-dd').format(balance.lastUpdated),
                ];
              }).toList(),
            ),
          ],
        ),
      );

      final directory = await getApplicationDocumentsDirectory();
      final path =
          '${directory.path}/stock_balances_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final file = File(path);
      await file.writeAsBytes(await pdf.save());

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('PDF exported to: $path')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error exporting PDF: $e')));
    }
  }

  Future<void> _exportIntakesToCSV() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final path =
          '${directory.path}/stock_intakes_${DateTime.now().millisecondsSinceEpoch}.csv';
      final file = File(path);

      // Create CSV data
      List<List<dynamic>> rows = [];

      // Add header row
      rows.add([
        'Product Name',
        'Quantity',
        'Unit',
        'Cost Per Unit',
        'Total Cost',
        'Date',
        'Description',
      ]);

      // Add data rows
      for (var intake in _filteredStockIntakes) {
        rows.add([
          intake.productName,
          intake.quantityReceived,
          intake.unit,
          intake.costPerUnit,
          intake.totalCost,
          DateFormat('yyyy-MM-dd').format(intake.dateReceived),
          intake.description,
        ]);
      }

      // Convert to CSV
      String csv = const ListToCsvConverter().convert(rows);

      // Write to file
      await file.writeAsString(csv);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('CSV exported to: $path')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error exporting CSV: $e')));
    }
  }

  Future<void> _exportIntakesToPDF() async {
    try {
      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          header: (pw.Context context) {
            return pw.Header(
              level: 0,
              child: pw.Text(
                'Stock Intake Report',
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            );
          },
          footer: (pw.Context context) {
            return pw.Footer(
              trailing: pw.Text(
                'Page ${context.pageNumber} of ${context.pagesCount}',
                style: pw.TextStyle(fontSize: 10),
              ),
            );
          },
          build: (pw.Context context) => [
            pw.Table.fromTextArray(
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              headerDecoration: pw.BoxDecoration(color: PdfColors.grey300),
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.center,
                2: pw.Alignment.center,
                3: pw.Alignment.center,
                4: pw.Alignment.center,
                5: pw.Alignment.center,
                6: pw.Alignment.centerLeft,
              },
              headers: [
                'Product Name',
                'Quantity',
                'Unit',
                'Cost Per Unit',
                'Total Cost',
                'Date',
                'Description',
              ],
              data: _filteredStockIntakes.map((intake) {
                return [
                  intake.productName,
                  intake.quantityReceived.toString(),
                  intake.unit,
                  intake.costPerUnit.toString(),
                  NumberFormat('#,##0.00').format(intake.totalCost),
                  DateFormat('yyyy-MM-dd').format(intake.dateReceived),
                  intake.description,
                ];
              }).toList(),
            ),
          ],
        ),
      );

      final directory = await getApplicationDocumentsDirectory();
      final path =
          '${directory.path}/stock_intakes_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final file = File(path);
      await file.writeAsBytes(await pdf.save());

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('PDF exported to: $path')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error exporting PDF: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 768;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stock Intake'),
        actions: [
          // Only show export buttons when on the Intake Records tab
          if (_tabController.index == 0) ...[
            IconButton(
              icon: const Icon(Icons.file_download),
              onPressed: _exportIntakesToCSV,
              tooltip: 'Export to CSV',
            ),
            IconButton(
              icon: const Icon(Icons.picture_as_pdf),
              onPressed: _exportIntakesToPDF,
              tooltip: 'Export to PDF',
            ),
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: _showAddIntakeDialog,
              tooltip: 'Add Stock Intake',
            ),
          ],
        ],
        // Remove the hamburger menu for desktop view
        automaticallyImplyLeading: !isDesktop,
        // TabBar removed from here
      ),
      drawer: !isDesktop ? Drawer(child: Sidebar()) : null,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Permanent sidebar for larger screens
          if (isDesktop)
            Container(
              width: 256, // Fixed width for the sidebar
              height: MediaQuery.of(context).size.height,
              child: Sidebar(),
            ),
          // Main content area
          Expanded(
            child: _isLoading
                ? const Center(child: LoadingIndicator())
                : Column(
                    children: [
                      // Custom styled TabBar at the top of the content area
                      Container(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16.0,
                          vertical: 8.0,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 5,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: TabBar(
                          controller: _tabController,
                          indicatorColor: Theme.of(context).colorScheme.primary,
                          labelColor: Theme.of(context).colorScheme.primary,
                          unselectedLabelColor: Colors.grey,
                          indicatorSize: TabBarIndicatorSize.tab,
                          dividerColor: Colors.transparent,
                          tabs: const [
                            Tab(
                              text: 'Intake Records',
                              icon: Icon(Icons.receipt_long),
                            ),
                            Tab(
                              text: 'Balance Summary',
                              icon: Icon(Icons.balance),
                            ),
                          ],
                        ),
                      ),
                      // TabBarView for the content
                      Expanded(
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            // Tab 1: Intake Records (current view)
                            Column(
                              children: [
                                _buildHeader(),
                                _buildMetricsSection(),
                                _buildFiltersSection(),
                                _buildTableHeader(),
                                Expanded(child: _buildStockIntakeList()),
                              ],
                            ),
                            // Tab 2: Balance Summary
                            Column(
                              children: [
                                _buildBalanceHeader(),
                                _buildBalanceFiltersSection(),
                                _buildBalanceTableHeader(),
                                Expanded(child: _buildBalanceList()),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
      // Removed floating action buttons as they've been moved to the AppBar
    );
  }

  Widget _buildHeader() {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
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
                  Icons.inventory_2,
                  color: colorScheme.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Stock Intake Records',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          CustomButton(
            onPressed: _showAddIntakeDialog,
            text: 'Add New Intake',
            icon: Icons.add,
            color: colorScheme.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceHeader() {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
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
                  Icons.balance,
                  color: colorScheme.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Product Balance Summary',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Showing ${_filteredBalances.length} of ${_intakeBalances.length} products',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ],
          ),
          Row(
            children: [
              CustomButton(
                onPressed: _exportBalancesToCSV,
                text: 'Export CSV',
                icon: Icons.file_download,
                color: colorScheme.primary,
                isOutlined: true,
              ),
              const SizedBox(width: 8),
              CustomButton(
                onPressed: _exportBalancesToPDF,
                text: 'Export PDF',
                icon: Icons.picture_as_pdf,
                color: colorScheme.primary,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsSection() {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: [
          Expanded(
            child: Card(
              elevation: 2,
              margin: const EdgeInsets.symmetric(vertical: 4.0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Container(
                padding: const EdgeInsets.all(12.0),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      colorScheme.primary.withOpacity(0.8),
                      colorScheme.primary,
                    ],
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.monetization_on,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Total Stock Value',
                          style: TextStyle(fontSize: 14, color: Colors.white),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '₦${NumberFormat('#,##0.00').format(_totalStockValue)}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Container(
                padding: const EdgeInsets.all(12.0),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.white,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.inventory,
                            color: Colors.orange[700],
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Total Items Received',
                          style: TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${_filteredStockIntakes.length}',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange[700],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: InkWell(
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Row(
                        children: [
                          Icon(Icons.balance, color: colorScheme.primary),
                          const SizedBox(width: 8),
                          const Text('Product Balances'),
                        ],
                      ),
                      content: SizedBox(
                        width: double.maxFinite,
                        height: 400,
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: _intakeBalances.length,
                          itemBuilder: (context, index) {
                            final balance = _intakeBalances[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor:
                                      colorScheme.primary.withOpacity(0.1),
                                  child: Text(
                                    balance.productName
                                        .substring(0, 1)
                                        .toUpperCase(),
                                    style: TextStyle(
                                      color: colorScheme.primary,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                title: Text(balance.productName),
                                subtitle: Text(
                                  'Balance: ${balance.balanceQuantity}',
                                ),
                                trailing: Icon(
                                  Icons.arrow_forward_ios,
                                  size: 16,
                                ),
                                onTap: () => _showBalanceDetails(balance),
                              ),
                            );
                          },
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(
                            'Close',
                            style: TextStyle(color: colorScheme.primary),
                          ),
                        ),
                      ],
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(12.0),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.white,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.category,
                              color: Colors.green[700],
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Product Balances',
                            style: TextStyle(fontSize: 14, color: Colors.grey),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${_intakeBalances.length} Products',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.green[700],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Add state variables for additional filters
  String _selectedProductFilter = 'All Products';
  String _selectedSortOption = 'Date (Newest)';

  Widget _buildFiltersSection() {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        children: [
          Row(
            children: [
              // Reduced search bar
              Expanded(
                flex: 2,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12.0),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        spreadRadius: 1,
                        blurRadius: 3,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search products',
                      hintStyle: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 14,
                      ),
                      prefixIcon: Icon(
                        Icons.search,
                        color: colorScheme.primary,
                        size: 20,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.0),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.0),
                        borderSide: BorderSide(
                          color: Colors.grey.withOpacity(0.1),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.0),
                        borderSide: BorderSide(color: colorScheme.primary),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 8.0,
                        horizontal: 8.0,
                      ),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Date range picker
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12.0),
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      spreadRadius: 1,
                      blurRadius: 3,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12.0),
                    onTap: _showDateRangePicker,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.calendar_today,
                            size: 18,
                            color: colorScheme.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _startDate != null && _endDate != null
                                ? '${DateFormat('MMM dd').format(_startDate!)} - ${DateFormat('MMM dd').format(_endDate!)}'
                                : 'Date Range',
                            style: TextStyle(
                              color: colorScheme.onSurface,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              if (_startDate != null && _endDate != null) ...[
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12.0),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        spreadRadius: 1,
                        blurRadius: 3,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: IconButton(
                    onPressed: _clearDateFilter,
                    icon: const Icon(Icons.clear, color: Colors.red, size: 18),
                    tooltip: 'Clear date filter',
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                      padding: const EdgeInsets.all(8),
                    ),
                  ),
                ),
              ],
              const SizedBox(width: 8),
              // Product filter dropdown
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12.0),
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      spreadRadius: 1,
                      blurRadius: 3,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedProductFilter,
                    icon: Icon(
                      Icons.arrow_drop_down,
                      color: colorScheme.primary,
                    ),
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontSize: 14,
                    ),
                    items: <String>[
                      'All Products',
                      'Low Stock',
                      'High Value',
                      'Recently Added',
                    ].map<DropdownMenuItem<String>>((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      setState(() {
                        _selectedProductFilter = newValue!;
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Sort options dropdown
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12.0),
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      spreadRadius: 1,
                      blurRadius: 3,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedSortOption,
                    icon: Icon(Icons.sort, color: colorScheme.primary),
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontSize: 14,
                    ),
                    items: <String>[
                      'Date (Newest)',
                      'Date (Oldest)',
                      'Price (High-Low)',
                      'Price (Low-High)',
                      'Name (A-Z)',
                      'Name (Z-A)',
                    ].map<DropdownMenuItem<String>>((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      setState(() {
                        _selectedSortOption = newValue!;
                      });
                    },
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceFiltersSection() {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12.0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: TextField(
                controller: _balanceSearchController,
                decoration: InputDecoration(
                  hintText: 'Search by product name',
                  hintStyle: TextStyle(color: Colors.grey[400]),
                  prefixIcon: Icon(Icons.search, color: colorScheme.primary),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                    borderSide: BorderSide(color: Colors.grey.withOpacity(0.1)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                    borderSide: BorderSide(color: colorScheme.primary),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 16.0,
                    horizontal: 16.0,
                  ),
                ),
                onChanged: (value) {
                  setState(() {
                    _balanceSearchQuery = value;
                  });
                },
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Filter by balance quantity
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12.0),
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: PopupMenuButton<String>(
              onSelected: (value) {
                setState(() {
                  _balanceFilter = value;
                });
              },
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              offset: const Offset(0, 40),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemBuilder: (context) => [
                const PopupMenuItem<String>(
                  value: 'all',
                  child: Text('All Balances'),
                ),
                const PopupMenuItem<String>(
                  value: 'positive',
                  child: Text('Positive Balances'),
                ),
                const PopupMenuItem<String>(
                  value: 'zero',
                  child: Text('Zero Balances'),
                ),
                const PopupMenuItem<String>(
                  value: 'negative',
                  child: Text('Negative Balances'),
                ),
              ],
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.filter_list, color: Colors.white),
                    const SizedBox(width: 8),
                    Text(
                      _balanceFilter == 'all'
                          ? 'All Balances'
                          : _balanceFilter == 'positive'
                              ? 'Positive Balances'
                              : _balanceFilter == 'zero'
                                  ? 'Zero Balances'
                                  : 'Negative Balances',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeader() {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: colorScheme.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.primary.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: _buildHeaderCell('Product Name', color: colorScheme.primary),
          ),
          Expanded(
            flex: 1,
            child: _buildHeaderCell('Quantity', color: colorScheme.primary),
          ),
          Expanded(
            flex: 1,
            child: _buildHeaderCell('Unit', color: colorScheme.primary),
          ),
          Expanded(
            flex: 2,
            child: _buildHeaderCell('Cost/Unit', color: colorScheme.primary),
          ),
          Expanded(
            flex: 2,
            child: _buildHeaderCell('Total Cost', color: colorScheme.primary),
          ),
          Expanded(
            flex: 2,
            child: _buildHeaderCell(
              'Date Received',
              color: colorScheme.primary,
            ),
          ),
          Expanded(
            flex: 1,
            child: _buildHeaderCell('Sync', color: colorScheme.primary),
          ),
          Expanded(
            flex: 1,
            child: _buildHeaderCell('Actions', color: colorScheme.primary),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceTableHeader() {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: colorScheme.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.primary.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: InkWell(
              onTap: () {
                setState(() {
                  if (_sortColumn == 'productName') {
                    _sortAscending = !_sortAscending;
                  } else {
                    _sortColumn = 'productName';
                    _sortAscending = true;
                  }
                });
              },
              child: Row(
                children: [
                  Text(
                    'Product Name',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  if (_sortColumn == 'productName')
                    Icon(
                      _sortAscending
                          ? Icons.arrow_upward
                          : Icons.arrow_downward,
                      size: 16,
                      color: colorScheme.primary,
                    ),
                ],
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: InkWell(
              onTap: () {
                setState(() {
                  if (_sortColumn == 'totalReceived') {
                    _sortAscending = !_sortAscending;
                  } else {
                    _sortColumn = 'totalReceived';
                    _sortAscending = true;
                  }
                });
              },
              child: Row(
                children: [
                  Text(
                    'Total Received',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  if (_sortColumn == 'totalReceived')
                    Icon(
                      _sortAscending
                          ? Icons.arrow_upward
                          : Icons.arrow_downward,
                      size: 16,
                      color: colorScheme.primary,
                    ),
                ],
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: InkWell(
              onTap: () {
                setState(() {
                  if (_sortColumn == 'balanceQuantity') {
                    _sortAscending = !_sortAscending;
                  } else {
                    _sortColumn = 'balanceQuantity';
                    _sortAscending = true;
                  }
                });
              },
              child: Row(
                children: [
                  Text(
                    'Balance',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  if (_sortColumn == 'balanceQuantity')
                    Icon(
                      _sortAscending
                          ? Icons.arrow_upward
                          : Icons.arrow_downward,
                      size: 16,
                      color: colorScheme.primary,
                    ),
                ],
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: _buildHeaderCell('Last Updated', color: colorScheme.primary),
          ),
          Expanded(
            flex: 1,
            child: _buildHeaderCell('Actions', color: colorScheme.primary),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(String text, {int flex = 1, Color? color}) {
    return Text(
      text,
      style: TextStyle(fontWeight: FontWeight.bold, color: color),
    );
  }

  Widget _buildStockIntakeList() {
    final colorScheme = Theme.of(context).colorScheme;

    if (_filteredStockIntakes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 64,
              color: colorScheme.primary.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No stock intake records found',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _filteredStockIntakes.length,
      itemBuilder: (context, index) {
        final intake = _filteredStockIntakes[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            intake.productName.substring(0, 1).toUpperCase(),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.primary,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              intake.productName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (intake.description != null &&
                                intake.description!.isNotEmpty)
                              Text(
                                intake.description!,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${intake.quantityReceived}',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.blue[700]),
                    ),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Text(intake.unit, textAlign: TextAlign.center),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    '₦${NumberFormat('#,##0.00').format(intake.costPerUnit)}',
                    style: TextStyle(color: Colors.grey[800]),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    '₦${NumberFormat('#,##0.00').format(intake.totalCost)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    DateFormat('MMM dd, yyyy').format(intake.dateReceived),
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: intake.isSynced
                      ? Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: Colors.green[50],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.check_circle,
                                color: Colors.green[700],
                                size: 14,
                              ),
                              const SizedBox(width: 2),
                              Flexible(
                                child: Text(
                                  'Synced',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.green[700],
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        )
                      : Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: Colors.orange[50],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.sync,
                                color: Colors.orange[700],
                                size: 14,
                              ),
                              const SizedBox(width: 2),
                              Flexible(
                                child: Text(
                                  'Pending',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.orange[700],
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
                Expanded(
                  flex: 1,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: IconButton(
                          icon: Icon(
                            Icons.edit,
                            color: Colors.orange[700],
                            size: 16,
                          ),
                          onPressed: () => _editStockIntake(intake),
                          tooltip: 'Edit',
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.orange.withOpacity(0.1),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                            minimumSize: const Size(28, 28),
                          ),
                        ),
                      ),
                      const SizedBox(width: 2),
                      Flexible(
                        child: IconButton(
                          icon: Icon(
                            Icons.delete,
                            color: Colors.red[700],
                            size: 16,
                          ),
                          onPressed: () => _deleteStockIntake(intake),
                          tooltip: 'Delete',
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.red.withOpacity(0.1),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                            minimumSize: const Size(28, 28),
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
      },
    );
  }

  List<IntakeBalance> get _filteredBalances {
    return _intakeBalances.where((balance) {
      // Apply search filter
      final matchesSearch = balance.productName.toLowerCase().contains(
            _balanceSearchQuery.toLowerCase(),
          );

      // Apply balance quantity filter
      bool matchesBalanceFilter = true;
      if (_balanceFilter == 'positive') {
        matchesBalanceFilter = balance.balanceQuantity > 0;
      } else if (_balanceFilter == 'zero') {
        matchesBalanceFilter = balance.balanceQuantity == 0;
      } else if (_balanceFilter == 'negative') {
        matchesBalanceFilter = balance.balanceQuantity < 0;
      }

      return matchesSearch && matchesBalanceFilter;
    }).toList();
  }

  Widget _buildBalanceList() {
    final colorScheme = Theme.of(context).colorScheme;
    List<IntakeBalance> filteredBalances = _filteredBalances;

    // Sort the list based on selected column and direction
    filteredBalances.sort((a, b) {
      int result;
      if (_sortColumn == 'productName') {
        result = a.productName.compareTo(b.productName);
      } else if (_sortColumn == 'totalReceived') {
        result = a.totalReceived.compareTo(b.totalReceived);
      } else if (_sortColumn == 'balanceQuantity') {
        result = a.balanceQuantity.compareTo(b.balanceQuantity);
      } else {
        result = a.lastUpdated.compareTo(b.lastUpdated);
      }
      return _sortAscending ? result : -result;
    });

    if (filteredBalances.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 64,
              color: colorScheme.primary.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No balance records found',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: filteredBalances.length,
      itemBuilder: (context, index) {
        final balance = filteredBalances[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            balance.productName.substring(0, 1).toUpperCase(),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.primary,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          balance.productName,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _formatBalance(balance.totalReceived),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.blue[700]),
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: balance.balanceQuantity > 0
                              ? Colors.green[400]
                              : balance.balanceQuantity < 0
                                  ? Colors.red[400]
                                  : Colors.grey[400],
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: balance.balanceQuantity > 0
                              ? Colors.green[50]
                              : balance.balanceQuantity < 0
                                  ? Colors.red[50]
                                  : Colors.grey[50],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _formatBalance(balance.balanceQuantity),
                          style: TextStyle(
                            color: balance.balanceQuantity > 0
                                ? Colors.green[700]
                                : balance.balanceQuantity < 0
                                    ? Colors.red[700]
                                    : Colors.grey[700],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    DateFormat('MMM dd, yyyy').format(balance.lastUpdated),
                    style: TextStyle(color: Colors.grey[700]),
                    textAlign: TextAlign.center,
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: IconButton(
                    icon: Icon(Icons.info_outline, color: colorScheme.primary),
                    onPressed: () => _showBalanceDetails(balance),
                    tooltip: 'View Details',
                    style: IconButton.styleFrom(
                      backgroundColor: colorScheme.primary.withOpacity(0.1),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _editStockIntake(StockIntake intake) async {
    final result = await showDialog<StockIntake>(
      context: context,
      builder: (context) => _EditStockIntakeDialog(intake: intake),
    );

    if (result != null) {
      try {
        await _stockIntakeService.updateStockIntake(result);
        await _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Stock intake updated successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error updating stock intake: $e')),
          );
        }
      }
    }
  }

  Future<void> _deleteStockIntake(StockIntake intake) async {
    // First check if the product is assigned to any outlet
    try {
      final isAssigned = await _stockIntakeService
          .isProductAssignedToOutlet(intake.productName);

      if (isAssigned) {
        // Show error dialog if product is already assigned
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Icon(
                  Icons.error_outline,
                  color: Colors.red[700],
                  size: 28,
                ),
                const SizedBox(width: 8),
                Text(
                  'Cannot Delete Product',
                  style: TextStyle(color: Colors.red[700]),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'This product "${intake.productName}" cannot be deleted because it has already been assigned to one or more outlets.',
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.orange[700],
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'To delete this stock intake record, you must first remove all product distributions for this product from the outlets.',
                          style: TextStyle(
                            color: Colors.orange[800],
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        return;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error checking product assignment: $e')),
        );
      }
      return;
    }

    // If product is not assigned, proceed with normal deletion confirmation
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Delete Stock Intake',
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
                'Are you sure you want to delete this stock intake record?'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Product: ${intake.productName}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text('Quantity: ${intake.quantityReceived} ${intake.unit}'),
                  Text(
                      'Total Cost: ₦${NumberFormat('#,##0.00').format(intake.totalCost)}'),
                  Text(
                      'Date: ${DateFormat('MMM dd, yyyy').format(intake.dateReceived)}'),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'This action cannot be undone.',
              style: TextStyle(color: Colors.red, fontSize: 12),
            ),
          ],
        ),
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
        await _stockIntakeService.deleteStockIntake(intake.id);
        await _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Stock intake deleted successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting stock intake: $e')),
          );
        }
      }
    }
  }
}

class _EditStockIntakeDialog extends StatefulWidget {
  final StockIntake intake;

  const _EditStockIntakeDialog({required this.intake});

  @override
  State<_EditStockIntakeDialog> createState() => _EditStockIntakeDialogState();
}

class _EditStockIntakeDialogState extends State<_EditStockIntakeDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _productNameController;
  late TextEditingController _quantityController;
  late TextEditingController _unitController;
  late TextEditingController _costPerUnitController;
  late TextEditingController _descriptionController;
  late DateTime _selectedDate;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _productNameController =
        TextEditingController(text: widget.intake.productName);
    _quantityController =
        TextEditingController(text: widget.intake.quantityReceived.toString());
    _unitController = TextEditingController(text: widget.intake.unit);
    _costPerUnitController =
        TextEditingController(text: widget.intake.costPerUnit.toString());
    _descriptionController =
        TextEditingController(text: widget.intake.description ?? '');
    _selectedDate = widget.intake.dateReceived;
  }

  @override
  void dispose() {
    _productNameController.dispose();
    _quantityController.dispose();
    _unitController.dispose();
    _costPerUnitController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        'Edit Stock Intake',
        style: TextStyle(color: colorScheme.primary),
      ),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _productNameController,
                decoration: const InputDecoration(
                  labelText: 'Product Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value?.isEmpty ?? true) return 'Product name is required';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _quantityController,
                      decoration: const InputDecoration(
                        labelText: 'Quantity',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value?.isEmpty ?? true) return 'Required';
                        if (double.tryParse(value!) == null)
                          return 'Invalid number';
                        if (double.parse(value) <= 0) return 'Must be positive';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _unitController,
                      decoration: const InputDecoration(
                        labelText: 'Unit',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value?.isEmpty ?? true) return 'Required';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _costPerUnitController,
                decoration: const InputDecoration(
                  labelText: 'Cost per Unit (₦)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value?.isEmpty ?? true)
                    return 'Cost per unit is required';
                  if (double.tryParse(value!) == null) return 'Invalid number';
                  if (double.parse(value) <= 0) return 'Must be positive';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (date != null) {
                    setState(() {
                      _selectedDate = date;
                    });
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today, color: colorScheme.primary),
                      const SizedBox(width: 12),
                      Text(
                        'Date: ${DateFormat('MMM dd, yyyy').format(_selectedDate)}',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description (Optional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calculate, color: colorScheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Total Cost: ₦${NumberFormat('#,##0.00').format((double.tryParse(_quantityController.text) ?? 0) * (double.tryParse(_costPerUnitController.text) ?? 0))}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _saveChanges,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save Changes'),
        ),
      ],
    );
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final quantity = double.parse(_quantityController.text);
      final costPerUnit = double.parse(_costPerUnitController.text);

      final updatedIntake = widget.intake.copyWith(
        productName: _productNameController.text.trim(),
        quantityReceived: quantity,
        unit: _unitController.text.trim(),
        costPerUnit: costPerUnit,
        totalCost: quantity * costPerUnit,
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        dateReceived: _selectedDate,
        isSynced: false, // Mark as unsynced since it was modified
      );

      Navigator.of(context).pop(updatedIntake);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }
}
