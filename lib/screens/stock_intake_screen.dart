import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import '../core/models/stock_intake_model.dart';
import '../core/models/intake_balance_model.dart';
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

class _StockIntakeScreenState extends State<StockIntakeScreen> with SingleTickerProviderStateMixin {
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
  bool _isSyncing = false;
  String _searchQuery = '';
  String _selectedUnit = 'Pcs';
  DateTime? _startDate;
  DateTime? _endDate;
  final TextEditingController _searchController = TextEditingController();
  
  // Tab controller
  late TabController _tabController;
  
  // Balance tab specific variables
  String _balanceSearchQuery = '';
  final TextEditingController _balanceSearchController = TextEditingController();
  String _sortColumn = 'productName';
  bool _sortAscending = true;
  String _balanceFilter = 'all'; // 'all', 'positive', 'zero', 'negative'

  final List<String> _units = ['Pcs', 'Kg', 'L', 'Box', 'Carton', 'Bag'];

  // List of predefined product names

  // List of predefined product names
  final List<String> _predefinedProducts = [
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
    _loadData();
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

      final stockIntakes = await _stockIntakeService.getAllIntakes();
      final intakeBalances = await _stockIntakeService.getAllIntakeBalances();

      setState(() {
        _stockIntakes = stockIntakes;
        _intakeBalances = intakeBalances;
        _isLoading = false;
      });
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

  Future<void> _syncData() async {
    setState(() {
      _isSyncing = true;
    });

    try {
      // Sync stock intakes to Supabase
      for (final intake in _stockIntakes.where((i) => !i.isSynced)) {
        final success = await _syncService.syncStockIntakeToSupabase(intake);
        if (success) {
          await _stockIntakeService.markIntakeAsSynced(intake.id);
        }
      }

      // Sync intake balances to Supabase
      for (final balance in _intakeBalances) {
        await _syncService.syncIntakeBalancesToSupabase(balance);
      }

      // Refresh data
      await _loadData();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sync completed successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error syncing data: $e')));
    } finally {
      setState(() {
        _isSyncing = false;
      });
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
                    return _predefinedProducts.where((String option) {
                      return option.toLowerCase().contains(
                        textEditingValue.text.toLowerCase(),
                      );
                    });
                  },
                  onSelected: (String selection) {
                    _productNameController.text = selection;
                  },
                  fieldViewBuilder:
                      (
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
                            hintText: 'Start typing or click to see options',
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
                  optionsViewBuilder:
                      (
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
                                  return ListTile(
                                    title: Text(option),
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
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
    }
  }

  void _clearDateFilter() {
    setState(() {
      _startDate = null;
      _endDate = null;
    });
  }

  void _showBalanceDetails(IntakeBalance balance) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${balance.productName} Balance Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Total Received: ${balance.totalReceived}'),
            const SizedBox(height: 8),
            Text('Total Assigned: ${balance.totalAssigned}'),
            const SizedBox(height: 8),
            Text('Balance Quantity: ${balance.balanceQuantity}'),
            const SizedBox(height: 8),
            Text(
              'Last Updated: ${DateFormat('MMM dd, yyyy').format(balance.lastUpdated)}',
            ),
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

  List<StockIntake> get _filteredStockIntakes {
    return _stockIntakes.where((intake) {
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
        matchesDate =
            intakeDate.isAtSameMomentAs(startDate) ||
            intakeDate.isAtSameMomentAs(endDate) ||
            (intakeDate.isAfter(startDate) && intakeDate.isBefore(endDate));
      }

      return matchesSearch && matchesDate;
    }).toList();
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
      final path = '${directory.path}/stock_balances_${DateTime.now().millisecondsSinceEpoch}.csv';
      final file = File(path);
      
      // Create CSV data
      List<List<dynamic>> rows = [];
      
      // Add header row
      rows.add(['Product Name', 'Total Received', 'Total Assigned', 'Balance Quantity', 'Last Updated']);
      
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
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('CSV exported to: $path')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error exporting CSV: $e')),
      );
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
              child: pw.Text('Stock Balance Report', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
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
              headerDecoration: pw.BoxDecoration(
                color: PdfColors.grey300,
              ),
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.center,
                2: pw.Alignment.center,
                3: pw.Alignment.center,
                4: pw.Alignment.center,
              },
              headers: ['Product Name', 'Total Received', 'Total Assigned', 'Balance', 'Last Updated'],
              data: _filteredBalances.map((balance) {
                return [
                  balance.productName,
                  balance.totalReceived.toString(),
                  balance.totalAssigned.toString(),
                  balance.balanceQuantity.toString(),
                  DateFormat('yyyy-MM-dd').format(balance.lastUpdated),
                ];
              }).toList(),
            ),
          ],
        ),
      );
      
      final directory = await getApplicationDocumentsDirectory();
      final path = '${directory.path}/stock_balances_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final file = File(path);
      await file.writeAsBytes(await pdf.save());
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PDF exported to: $path')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error exporting PDF: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 768;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stock Intake'),
        actions: [
          IconButton(
            icon: Icon(_isSyncing ? Icons.sync_disabled : Icons.sync),
            onPressed: _isSyncing ? null : _syncData,
            tooltip: 'Sync Data',
          ),
        ],
        // Remove the hamburger menu for desktop view
        automaticallyImplyLeading: !isDesktop,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Theme.of(context).colorScheme.primary,
          labelColor: Theme.of(context).colorScheme.primary,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(text: 'Intake Records', icon: Icon(Icons.receipt_long)),
            Tab(text: 'Balance Summary', icon: Icon(Icons.balance)),
          ],
        ),
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
                : TabBarView(
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
      floatingActionButton: _tabController.index == 0 ? FloatingActionButton(
        onPressed: _showAddIntakeDialog,
        child: const Icon(Icons.add),
        tooltip: 'Add Stock Intake',
      ) : null,
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Stock Intake Records',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          CustomButton(
            onPressed: _showAddIntakeDialog,
            text: 'Add New Intake',
            icon: Icons.add,
          ),
        ],
      ),
    );
  }
  
  Widget _buildBalanceHeader() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
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
          Row(
            children: [
              CustomButton(
                onPressed: _exportBalancesToCSV,
                text: 'Export CSV',
                icon: Icons.file_download,
              ),
              const SizedBox(width: 8),
              CustomButton(
                onPressed: _exportBalancesToPDF,
                text: 'Export PDF',
                icon: Icons.picture_as_pdf,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsSection() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: [
          Expanded(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Total Stock Value',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '₦${NumberFormat('#,##0.00').format(_totalStockValue)}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Total Items Received',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${_filteredStockIntakes.length}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Card(
              child: InkWell(
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Product Balances'),
                      content: SizedBox(
                        width: double.maxFinite,
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: _intakeBalances.length,
                          itemBuilder: (context, index) {
                            final balance = _intakeBalances[index];
                            return ListTile(
                              title: Text(balance.productName),
                              subtitle: Text(
                                'Balance: ${balance.balanceQuantity}',
                              ),
                              onTap: () => _showBalanceDetails(balance),
                            );
                          },
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Close'),
                        ),
                      ],
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Product Balances',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${_intakeBalances.length} Products',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
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

  Widget _buildFiltersSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Search by product name or description',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
          const SizedBox(width: 16),
          InkWell(
            onTap: _showDateRangePicker,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    _startDate != null && _endDate != null
                        ? '${DateFormat('MMM dd').format(_startDate!)} - ${DateFormat('MMM dd').format(_endDate!)}'
                        : 'Select Date Range',
                  ),
                ],
              ),
            ),
          ),
          if (_startDate != null && _endDate != null) ...[  
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: _clearDateFilter,
              tooltip: 'Clear Date Filter',
            ),
          ],
        ],
      ),
    );
  }
  
  Widget _buildBalanceFiltersSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _balanceSearchController,
              decoration: const InputDecoration(
                hintText: 'Search by product name',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {
                  _balanceSearchQuery = value;
                });
              },
            ),
          ),
          const SizedBox(width: 16),
          // Filter by balance quantity
          PopupMenuButton<String>(
             onSelected: (value) {
               setState(() {
                 _balanceFilter = value;
               });
             },
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
               padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
               decoration: BoxDecoration(
                 color: Theme.of(context).colorScheme.primary,
                 borderRadius: BorderRadius.circular(4),
               ),
               child: Row(
                 children: [
                   const Icon(Icons.filter_list, color: Colors.white),
                   const SizedBox(width: 8),
                   Text(
                     _balanceFilter == 'all' ? 'All Balances' :
                     _balanceFilter == 'positive' ? 'Positive Balances' :
                     _balanceFilter == 'zero' ? 'Zero Balances' :
                     'Negative Balances',
                     style: const TextStyle(color: Colors.white),
                   ),
                 ],
               ),
             ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      color: Colors.grey[200],
      child: Row(
        children: [
          Expanded(flex: 3, child: _buildHeaderCell('Product Name')),
          Expanded(flex: 1, child: _buildHeaderCell('Quantity')),
          Expanded(flex: 1, child: _buildHeaderCell('Unit')),
          Expanded(flex: 2, child: _buildHeaderCell('Cost/Unit')),
          Expanded(flex: 2, child: _buildHeaderCell('Total Cost')),
          Expanded(flex: 2, child: _buildHeaderCell('Date Received')),
          Expanded(flex: 1, child: _buildHeaderCell('Sync')),
        ],
      ),
    );
  }
  
  Widget _buildBalanceTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      color: Colors.grey[200],
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
                  Text('Product Name', style: TextStyle(fontWeight: FontWeight.bold)),
                  if (_sortColumn == 'productName')
                    Icon(_sortAscending ? Icons.arrow_upward : Icons.arrow_downward, size: 16),
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
                  Text('Total Received', style: TextStyle(fontWeight: FontWeight.bold)),
                  if (_sortColumn == 'totalReceived')
                    Icon(_sortAscending ? Icons.arrow_upward : Icons.arrow_downward, size: 16),
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
                  Text('Balance', style: TextStyle(fontWeight: FontWeight.bold)),
                  if (_sortColumn == 'balanceQuantity')
                    Icon(_sortAscending ? Icons.arrow_upward : Icons.arrow_downward, size: 16),
                ],
              ),
            ),
          ),
          Expanded(flex: 2, child: _buildHeaderCell('Last Updated')),
          Expanded(flex: 1, child: _buildHeaderCell('Actions')),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(String text) {
    return Text(text, style: const TextStyle(fontWeight: FontWeight.bold));
  }

  Widget _buildStockIntakeList() {
    if (_filteredStockIntakes.isEmpty) {
      return const Center(child: Text('No stock intake records found'));
    }

    return ListView.builder(
      itemCount: _filteredStockIntakes.length,
      itemBuilder: (context, index) {
        final intake = _filteredStockIntakes[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        intake.productName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
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
                Expanded(flex: 1, child: Text('${intake.quantityReceived}')),
                Expanded(flex: 1, child: Text(intake.unit)),
                Expanded(
                  flex: 2,
                  child: Text(
                    '₦${NumberFormat('#,##0.00').format(intake.costPerUnit)}',
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    '₦${NumberFormat('#,##0.00').format(intake.totalCost)}',
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    DateFormat('MMM dd, yyyy').format(intake.dateReceived),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: intake.isSynced
                      ? const Icon(Icons.check_circle, color: Colors.green)
                      : const Icon(Icons.sync, color: Colors.orange),
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
      final matchesSearch = balance.productName.toLowerCase().contains(_balanceSearchQuery.toLowerCase());
      
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
      return const Center(child: Text('No balance records found'));
    }
    
    return ListView.builder(
      itemCount: filteredBalances.length,
      itemBuilder: (context, index) {
        final balance = filteredBalances[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    balance.productName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text('${balance.totalReceived}'),
                ),
                Expanded(
                   flex: 2,
                   child: Row(
                     children: [
                       Container(
                         width: 12,
                         height: 12,
                         decoration: BoxDecoration(
                           color: balance.balanceQuantity > 0 
                               ? Colors.green 
                               : balance.balanceQuantity < 0 
                                   ? Colors.red 
                                   : Colors.grey,
                           shape: BoxShape.circle,
                         ),
                       ),
                       const SizedBox(width: 8),
                       Text(
                         '${balance.balanceQuantity}',
                         style: TextStyle(
                           color: balance.balanceQuantity > 0 
                               ? Colors.green 
                               : balance.balanceQuantity < 0 
                                   ? Colors.red 
                                   : Colors.grey,
                           fontWeight: FontWeight.bold,
                         ),
                       ),
                     ],
                   ),
                 ),
                Expanded(
                  flex: 2,
                  child: Text(
                    DateFormat('MMM dd, yyyy').format(balance.lastUpdated),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: IconButton(
                    icon: const Icon(Icons.info_outline),
                    onPressed: () => _showBalanceDetails(balance),
                    tooltip: 'View Details',
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
