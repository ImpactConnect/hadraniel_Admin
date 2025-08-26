import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/models/expenditure_model.dart';
import '../../core/models/outlet_model.dart';
import '../../core/services/expenditure_service.dart';
import '../../core/services/sync_service.dart';
import '../../widgets/dashboard_layout.dart';
import '../../widgets/loading_indicator.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/custom_date_picker.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:typed_data';

class ExpendituresScreen extends StatefulWidget {
  const ExpendituresScreen({super.key});

  @override
  State<ExpendituresScreen> createState() => _ExpendituresScreenState();
}

class _ExpendituresScreenState extends State<ExpendituresScreen>
    with TickerProviderStateMixin {
  final ExpenditureService _expenditureService = ExpenditureService();
  final SyncService _syncService = SyncService();
  final _formKey = GlobalKey<FormState>();
  late TabController _tabController;

  List<Expenditure> _expenditures = [];
  List<ExpenditureCategory> _categories = [];
  List<Outlet> _outlets = [];
  Map<String, dynamic> _analytics = {};
  bool _isLoading = true;
  String _selectedFilter = 'all';
  String? _selectedOutlet;
  String? _selectedOutletForForm;
  String? _selectedCategory;
  DateTime? _startDate;
  DateTime? _endDate;
  String _trendPeriod = 'monthly'; // daily, weekly, monthly, yearly
  List<Expenditure> _filteredExpenditures = [];
  Map<String, dynamic> _filteredAnalytics = {};

  // Form controllers
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  final _receiptController = TextEditingController();
  final _vendorController = TextEditingController();
  final _notesController = TextEditingController();
  String _selectedPaymentMethod = 'cash';
  String _selectedCategoryId = '';
  DateTime _selectedDate = DateTime.now();
  bool _isRecurring = false;
  String _recurringFrequency = 'monthly';
  Expenditure? _editingExpenditure;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _descriptionController.dispose();
    _amountController.dispose();
    _receiptController.dispose();
    _vendorController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      await _expenditureService.initializeDefaultCategories();
      final expenditures = await _expenditureService.getAllExpenditures();
      final categories = await _expenditureService.getAllCategories();
      final outlets = await _syncService.getAllLocalOutlets();
      final analytics = await _expenditureService.getExpenditureAnalytics();

      setState(() {
        _expenditures = expenditures;
        _filteredExpenditures = expenditures;
        _categories = categories;
        _outlets = outlets;
        _analytics = analytics;
        _filteredAnalytics = analytics;
        if (_categories.isNotEmpty) {
          _selectedCategoryId = _categories.first.id;
        }
        if (_outlets.isNotEmpty) {
          _selectedOutletForForm = _outlets.first.id;
        }
      });
      _applyFiltersAuto();
    } catch (e) {
      _showErrorSnackBar('Error loading data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _applyFilters() async {
    setState(() => _isLoading = true);
    await _applyFiltersAuto();
    setState(() => _isLoading = false);
  }

  Future<void> _applyFiltersAuto() async {
    try {
      List<Expenditure> filteredExpenditures = List.from(_expenditures);

      // Apply outlet filter
      if (_selectedOutlet != null) {
        filteredExpenditures = filteredExpenditures
            .where((exp) => exp.outletId == _selectedOutlet)
            .toList();
      }

      // Apply category filter
      if (_selectedCategory != null) {
        filteredExpenditures = filteredExpenditures
            .where((exp) => exp.category == _selectedCategory)
            .toList();
      }

      // Apply date range filter
      if (_startDate != null && _endDate != null) {
        filteredExpenditures = filteredExpenditures
            .where((exp) =>
                exp.dateIncurred
                    .isAfter(_startDate!.subtract(const Duration(days: 1))) &&
                exp.dateIncurred
                    .isBefore(_endDate!.add(const Duration(days: 1))))
            .toList();
      }

      // Calculate filtered analytics
      final filteredAnalytics =
          _calculateFilteredAnalytics(filteredExpenditures);

      setState(() {
        _filteredExpenditures = filteredExpenditures;
        _filteredAnalytics = filteredAnalytics;
      });
    } catch (e) {
      _showErrorSnackBar('Error applying filters: $e');
    }
  }

  Map<String, dynamic> _calculateFilteredAnalytics(
      List<Expenditure> expenditures) {
    final totalExpenditure =
        expenditures.fold<double>(0.0, (sum, exp) => sum + exp.amount);

    final categoryBreakdown = <String, Map<String, dynamic>>{};
    for (final exp in expenditures) {
      if (categoryBreakdown.containsKey(exp.category)) {
        categoryBreakdown[exp.category]!['total'] += exp.amount;
        categoryBreakdown[exp.category]!['count'] += 1;
      } else {
        categoryBreakdown[exp.category] = {
          'category': exp.category,
          'total': exp.amount,
          'count': 1,
        };
      }
    }

    return {
      'totalExpenditure': totalExpenditure,
      'pendingApprovals': 0, // Placeholder since approval status was removed
      'categoryBreakdown': categoryBreakdown.values.toList(),
    };
  }

  Widget _buildTableHeader(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }

  TableRow _buildExpenditureTableRow(Expenditure expenditure) {
    final category = _categories.firstWhere(
      (cat) => cat.name == expenditure.category,
      orElse: () => ExpenditureCategory(
        id: 'unknown',
        name: expenditure.category,
        description: '',
        color: '#9E9E9E',
        createdAt: DateTime.now(),
      ),
    );

    return TableRow(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Colors.grey.withOpacity(0.2),
            width: 1,
          ),
        ),
      ),
      children: [
        _buildTableCell(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                expenditure.description,
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (expenditure.vendorName != null) ...[
                const SizedBox(height: 2),
                Text(
                  'Vendor: ${expenditure.vendorName}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ],
          ),
        ),
        _buildTableCell(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: Color(
                      int.parse(category.color.replaceFirst('#', '0xFF'))),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  expenditure.category,
                  style: const TextStyle(fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        _buildTableCell(
          child: Text(
            expenditure.outletName,
            style: const TextStyle(fontSize: 13),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        _buildTableCell(
          child: Text(
            _formatCurrency(expenditure.amount),
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.red,
              fontSize: 14,
            ),
          ),
        ),
        _buildTableCell(
          child: Text(
            DateFormat('MMM dd, yyyy').format(expenditure.dateIncurred),
            style: const TextStyle(fontSize: 13),
          ),
        ),
        _buildTableCell(
          child: Text(
            expenditure.paymentMethod?.toUpperCase() ?? 'CASH',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        _buildTableCell(
          child: Container(
            width: 40,
            child: PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, size: 16),
              padding: EdgeInsets.zero,
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'view',
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.visibility, size: 16),
                      SizedBox(width: 8),
                      Text('View Details'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'edit',
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.edit, size: 16, color: Colors.blue),
                      SizedBox(width: 8),
                      Text('Edit'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.delete, size: 16, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Delete'),
                    ],
                  ),
                ),
              ],
              onSelected: (value) {
                switch (value) {
                  case 'view':
                    _showExpenditureDetails(expenditure);
                    break;
                  case 'edit':
                    _editExpenditure(expenditure);
                    break;
                  case 'delete':
                    _deleteExpenditure(expenditure.id);
                    break;
                }
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTableCell({required Widget child}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: child,
    );
  }

  String _formatCurrency(double amount) {
    return '₦${amount.toStringAsFixed(2)}';
  }

  Future<void> _editExpenditure(Expenditure expenditure) async {
    _editingExpenditure = expenditure;
    _descriptionController.text = expenditure.description;
    _amountController.text = expenditure.amount.toString();
    _receiptController.text = expenditure.receiptNumber ?? '';
    _vendorController.text = expenditure.vendorName ?? '';
    _notesController.text = expenditure.notes ?? '';

    // Find the category ID by name
    final category = _categories.firstWhere(
      (cat) => cat.name == expenditure.category,
      orElse: () => _categories.isNotEmpty
          ? _categories.first
          : ExpenditureCategory(
              id: 'unknown',
              name: expenditure.category,
              description: '',
              color: '#9E9E9E',
              createdAt: DateTime.now(),
            ),
    );
    _selectedCategoryId = category.id;

    _selectedOutletForForm = expenditure.outletId;
    _selectedPaymentMethod = expenditure.paymentMethod ?? 'cash';
    _selectedDate = expenditure.dateIncurred;
    _isRecurring = expenditure.isRecurring;
    _recurringFrequency = expenditure.recurringFrequency ?? 'monthly';

    _showAddExpenditureDialog();
  }

  Future<void> _deleteExpenditure(String expenditureId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Expenditure'),
        content: const Text(
            'Are you sure you want to delete this expenditure? This action cannot be undone.'),
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

    if (confirmed == true) {
      try {
        await _expenditureService.deleteExpenditure(expenditureId);
        _loadData();
        _showSuccessSnackBar('Expenditure deleted successfully');
      } catch (e) {
        _showErrorSnackBar('Error deleting expenditure: $e');
      }
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DashboardLayout(
      title: 'Business Expenditures',
      actions: [
        IconButton(
          icon: const Icon(Icons.sync),
          onPressed: () => Navigator.pushNamed(context, '/sync'),
          tooltip: 'Go to Sync Page',
        ),
        IconButton(
          icon: const Icon(Icons.picture_as_pdf),
          onPressed: _exportToPDF,
          tooltip: 'Export to PDF',
        ),
        IconButton(
          icon: const Icon(Icons.table_chart),
          onPressed: _exportToCSV,
          tooltip: 'Export to CSV',
        ),
      ],
      child: _isLoading
          ? const LoadingIndicator()
          : Column(
              children: [
                _buildHeader(),
                const SizedBox(height: 16),
                _buildTabBar(),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildExpendituresTab(),
                      _buildAnalyticsTab(),
                      _buildCategoriesTab(),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total Expenditures',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  _formatCurrency(
                      _filteredAnalytics['totalExpenditure'] ?? 0.0),
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: Colors.red[600],
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          CustomButton(
            text: 'Add Expenditure',
            onPressed: () => _showAddExpenditureDialog(),
            icon: Icons.add,
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        controller: _tabController,
        tabs: const [
          Tab(text: 'Expenditures', icon: Icon(Icons.receipt_long)),
          Tab(text: 'Analytics', icon: Icon(Icons.analytics)),
          Tab(text: 'Categories', icon: Icon(Icons.category)),
        ],
        labelColor: Theme.of(context).primaryColor,
        unselectedLabelColor: Colors.grey,
        indicatorColor: Theme.of(context).primaryColor,
      ),
    );
  }

  Widget _buildExpendituresTab() {
    return Column(
      children: [
        _buildFilters(),
        const SizedBox(height: 16),
        Expanded(
          child: _buildExpendituresList(),
        ),
      ],
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: DropdownButtonFormField<String>(
              value: _selectedOutlet,
              decoration: const InputDecoration(
                labelText: 'Outlet',
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: [
                const DropdownMenuItem(value: null, child: Text('All Outlets')),
                ..._outlets.map((outlet) => DropdownMenuItem(
                      value: outlet.id,
                      child: Text(outlet.name),
                    )),
              ],
              onChanged: (value) {
                setState(() => _selectedOutlet = value);
                _applyFiltersAuto();
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: DropdownButtonFormField<String>(
              value: _selectedCategory,
              decoration: const InputDecoration(
                labelText: 'Category',
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: [
                const DropdownMenuItem(
                    value: null, child: Text('All Categories')),
                ..._categories.map((category) => DropdownMenuItem(
                      value: category.name,
                      child: Text(category.name),
                    )),
              ],
              onChanged: (value) {
                setState(() => _selectedCategory = value);
                _applyFiltersAuto();
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: TextFormField(
              decoration: const InputDecoration(
                labelText: 'Start Date',
                border: OutlineInputBorder(),
                suffixIcon: Icon(Icons.calendar_today, size: 18),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              readOnly: true,
              controller: TextEditingController(
                text: _startDate != null
                    ? DateFormat('yyyy-MM-dd').format(_startDate!)
                    : '',
              ),
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _startDate ?? DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (date != null) {
                  setState(() => _startDate = date);
                  _applyFiltersAuto();
                }
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: TextFormField(
              decoration: const InputDecoration(
                labelText: 'End Date',
                border: OutlineInputBorder(),
                suffixIcon: Icon(Icons.calendar_today, size: 18),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              readOnly: true,
              controller: TextEditingController(
                text: _endDate != null
                    ? DateFormat('yyyy-MM-dd').format(_endDate!)
                    : '',
              ),
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _endDate ?? DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (date != null) {
                  setState(() => _endDate = date);
                  _applyFiltersAuto();
                }
              },
            ),
          ),
          const SizedBox(width: 12),
          CustomButton(
            text: 'Clear',
            onPressed: () {
              setState(() {
                _selectedCategory = null;
                _selectedOutlet = null;
                _startDate = null;
                _endDate = null;
              });
              _applyFiltersAuto();
            },
            variant: ButtonVariant.outlined,
          ),
        ],
      ),
    );
  }

  Widget _buildExpendituresList() {
    if (_filteredExpenditures.isEmpty) {
      return const Center(
        child: Text('No expenditures found'),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // Sticky Header
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Table(
              columnWidths: const {
                0: FlexColumnWidth(2.0), // Description
                1: FlexColumnWidth(1.0), // Category
                2: FlexColumnWidth(0.8), // Outlet
                3: FlexColumnWidth(0.8), // Amount
                4: FlexColumnWidth(0.9), // Date
                5: FlexColumnWidth(0.8), // Payment Method
                6: FlexColumnWidth(0.6), // Actions
              },
              children: [
                TableRow(
                  children: [
                    _buildTableHeader('Description'),
                    _buildTableHeader('Category'),
                    _buildTableHeader('Outlet'),
                    _buildTableHeader('Amount'),
                    _buildTableHeader('Date'),
                    _buildTableHeader('Payment Method'),
                    _buildTableHeader('Actions'),
                  ],
                ),
              ],
            ),
          ),
          // Scrollable Content
          Expanded(
            child: SingleChildScrollView(
              child: Table(
                columnWidths: const {
                  0: FlexColumnWidth(2.0), // Description
                  1: FlexColumnWidth(1.0), // Category
                  2: FlexColumnWidth(0.8), // Outlet
                  3: FlexColumnWidth(0.8), // Amount
                  4: FlexColumnWidth(0.9), // Date
                  5: FlexColumnWidth(0.8), // Payment Method
                  6: FlexColumnWidth(0.6), // Actions
                },
                children: _filteredExpenditures.map((expenditure) {
                  return _buildExpenditureTableRow(expenditure);
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpenditureCard(Expenditure expenditure) {
    final category = _categories.firstWhere(
      (cat) => cat.name == expenditure.category,
      orElse: () => ExpenditureCategory(
        id: 'unknown',
        name: expenditure.category,
        description: '',
        color: '#9E9E9E',
        createdAt: DateTime.now(),
      ),
    );

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor:
              Color(int.parse(category.color.replaceFirst('#', '0xFF'))),
          child: Icon(
            _getCategoryIcon(expenditure.category),
            color: Colors.white,
            size: 20,
          ),
        ),
        title: Text(
          expenditure.description,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${expenditure.category} • ${expenditure.outletName}'),
            Text(
              'Date: ${DateFormat('MMM dd, yyyy').format(expenditure.dateIncurred)}',
              style: TextStyle(color: Colors.grey[600]),
            ),
            if (expenditure.vendorName != null)
              Text(
                'Vendor: ${expenditure.vendorName}',
                style: TextStyle(color: Colors.grey[600]),
              ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              _formatCurrency(expenditure.amount),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.green,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                expenditure.paymentMethod?.toUpperCase() ?? 'CASH',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        onTap: () => _showExpenditureDetails(expenditure),
      ),
    );
  }

  Widget _buildAnalyticsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildAnalyticsCards(),
          const SizedBox(height: 16),
          _buildTrendChart(),
          const SizedBox(height: 16),
          _buildCategoryBreakdown(),
        ],
      ),
    );
  }

  Widget _buildAnalyticsCards() {
    return Row(
      children: [
        Expanded(
          child: _buildAnalyticsCard(
            'Total Expenditures',
            _formatCurrency(_analytics['totalExpenditure'] ?? 0.0),
            Icons.receipt_long,
            Colors.red,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildAnalyticsCard(
            'Pending Approvals',
            '${_analytics['pendingApprovals'] ?? 0}',
            Icons.pending_actions,
            Colors.orange,
          ),
        ),
      ],
    );
  }

  Widget _buildAnalyticsCard(
      String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryBreakdown() {
    final categoryData = _filteredAnalytics['categoryBreakdown']
            as List<Map<String, dynamic>>? ??
        [];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Expenditure by Category',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          ...categoryData.map((data) {
            final category = data['category'] as String;
            final total = (data['total'] as num).toDouble();
            final count = data['count'] as int;

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          category,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '$count transactions',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    _formatCurrency(total),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildTrendChart() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Expenditure Trend',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const Spacer(),
              _buildTrendPeriodFilter(),
            ],
          ),
          const SizedBox(height: 16),
          _buildTrendChartContent(),
        ],
      ),
    );
  }

  Widget _buildTrendPeriodFilter() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildTrendFilterButton('Daily', 'daily'),
          _buildTrendFilterButton('Weekly', 'weekly'),
          _buildTrendFilterButton('Monthly', 'monthly'),
          _buildTrendFilterButton('Yearly', 'yearly'),
        ],
      ),
    );
  }

  Widget _buildTrendFilterButton(String label, String period) {
    final isSelected = _trendPeriod == period;
    return GestureDetector(
      onTap: () {
        setState(() {
          _trendPeriod = period;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color:
              isSelected ? Theme.of(context).primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[700],
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildTrendChartContent() {
    final trendData = _calculateTrendData();

    if (trendData.isEmpty) {
      return Container(
        height: 200,
        child: const Center(
          child: Text('No data available for the selected period'),
        ),
      );
    }

    return Container(
      height: 200,
      child: Column(
        children: [
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: trendData.length,
              itemBuilder: (context, index) {
                final data = trendData[index];
                final maxAmount = trendData
                    .map((e) => e['amount'] as double)
                    .reduce((a, b) => a > b ? a : b);
                final height = (data['amount'] as double) / maxAmount * 150;

                return Container(
                  width: 60,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                        height: height,
                        decoration: BoxDecoration(
                          color: Theme.of(context).primaryColor,
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(4)),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        data['period'] as String,
                        style: const TextStyle(fontSize: 10),
                        textAlign: TextAlign.center,
                      ),
                      Text(
                        _formatCurrency(data['amount'] as double),
                        style: const TextStyle(
                            fontSize: 8, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
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

  List<Map<String, dynamic>> _calculateTrendData() {
    if (_filteredExpenditures.isEmpty) return [];

    final Map<String, double> periodTotals = {};
    final now = DateTime.now();

    for (final expenditure in _filteredExpenditures) {
      String periodKey;
      switch (_trendPeriod) {
        case 'daily':
          periodKey = DateFormat('MM/dd').format(expenditure.dateIncurred);
          break;
        case 'weekly':
          final weekStart = expenditure.dateIncurred
              .subtract(Duration(days: expenditure.dateIncurred.weekday - 1));
          periodKey = 'W${DateFormat('MM/dd').format(weekStart)}';
          break;
        case 'monthly':
          periodKey = DateFormat('MMM yy').format(expenditure.dateIncurred);
          break;
        case 'yearly':
          periodKey = DateFormat('yyyy').format(expenditure.dateIncurred);
          break;
        default:
          periodKey = DateFormat('MMM yy').format(expenditure.dateIncurred);
      }

      periodTotals[periodKey] =
          (periodTotals[periodKey] ?? 0) + expenditure.amount;
    }

    final sortedEntries = periodTotals.entries.toList();
    sortedEntries.sort((a, b) => a.key.compareTo(b.key));

    return sortedEntries
        .map((entry) => {
              'period': entry.key,
              'amount': entry.value,
            })
        .toList();
  }

  Widget _buildCategoriesTab() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Expenditure Categories',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const Spacer(),
              CustomButton(
                text: 'Add Category',
                onPressed: () => _showAddCategoryDialog(),
                icon: Icons.add,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                childAspectRatio: 1.5,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final category = _categories[index];
                return _buildCategoryCard(category);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryCard(ExpenditureCategory category) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color(int.parse(category.color.replaceFirst('#', '0xFF')))
            .withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Color(int.parse(category.color.replaceFirst('#', '0xFF'))),
          width: 2,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _getCategoryIcon(category.name),
            color: Color(int.parse(category.color.replaceFirst('#', '0xFF'))),
            size: 32,
          ),
          const SizedBox(height: 8),
          Text(
            category.name,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(int.parse(category.color.replaceFirst('#', '0xFF'))),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _showAddExpenditureDialog() {
    _clearForm();
    showDialog(
      context: context,
      builder: (context) => _buildExpenditureDialog(),
    );
  }

  void _showExpenditureDetails(Expenditure expenditure) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Expenditure Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Description', expenditure.description),
              _buildDetailRow('Amount', _formatCurrency(expenditure.amount)),
              _buildDetailRow('Category', expenditure.category),
              _buildDetailRow('Outlet', expenditure.outletName),
              _buildDetailRow(
                  'Payment Method', expenditure.paymentMethod ?? 'Cash'),
              _buildDetailRow('Date',
                  DateFormat('MMM dd, yyyy').format(expenditure.dateIncurred)),
              if (expenditure.vendorName != null)
                _buildDetailRow('Vendor', expenditure.vendorName ?? 'N/A'),
              if (expenditure.receiptNumber != null)
                _buildDetailRow('Receipt #', expenditure.receiptNumber!),
              if (expenditure.notes != null)
                _buildDetailRow('Notes', expenditure.notes!),
              if (expenditure.isRecurring)
                _buildDetailRow(
                    'Recurring', expenditure.recurringFrequency ?? 'monthly'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _editExpenditure(expenditure);
            },
            child: const Text('Edit'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteExpenditure(expenditure.id);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  Widget _buildExpenditureDialog({Expenditure? editingExpenditure}) {
    return AlertDialog(
      title: Text(
          editingExpenditure != null ? 'Edit Expenditure' : 'Add Expenditure'),
      content: SizedBox(
        width: 500,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CustomTextField(
                  controller: _descriptionController,
                  labelText: 'Description',
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a description';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  controller: _amountController,
                  labelText: 'Amount',
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter an amount';
                    }
                    if (double.tryParse(value) == null) {
                      return 'Please enter a valid amount';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedCategoryId.isNotEmpty
                      ? _selectedCategoryId
                      : null,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    border: OutlineInputBorder(),
                  ),
                  items: _categories
                      .map((category) => DropdownMenuItem(
                            value: category.id,
                            child: Text(category.name),
                          ))
                      .toList(),
                  onChanged: (value) {
                    setState(() => _selectedCategoryId = value ?? '');
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please select a category';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedOutletForForm,
                  decoration: const InputDecoration(
                    labelText: 'Outlet',
                    border: OutlineInputBorder(),
                  ),
                  items: _outlets
                      .map((outlet) => DropdownMenuItem(
                            value: outlet.id,
                            child: Text(outlet.name),
                          ))
                      .toList(),
                  onChanged: (value) {
                    setState(() => _selectedOutletForForm = value);
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please select an outlet';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedPaymentMethod,
                  decoration: const InputDecoration(
                    labelText: 'Payment Method',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'cash', child: Text('Cash')),
                    DropdownMenuItem(
                        value: 'bank_transfer', child: Text('Bank Transfer')),
                    DropdownMenuItem(
                        value: 'credit_card', child: Text('Credit Card')),
                    DropdownMenuItem(value: 'cheque', child: Text('Cheque')),
                    DropdownMenuItem(
                        value: 'mobile_money', child: Text('Mobile Money')),
                  ],
                  onChanged: (value) {
                    setState(() => _selectedPaymentMethod = value ?? 'cash');
                  },
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  controller: _vendorController,
                  labelText: 'Vendor Name (Optional)',
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  controller: _receiptController,
                  labelText: 'Receipt Number (Optional)',
                ),
                const SizedBox(height: 16),
                CustomDatePicker(
                  labelText: 'Date Incurred',
                  selectedDate: _selectedDate,
                  onDateSelected: (date) {
                    setState(() => _selectedDate = date);
                  },
                ),
                const SizedBox(height: 16),
                CheckboxListTile(
                  title: const Text('Recurring Expenditure'),
                  value: _isRecurring,
                  onChanged: (value) {
                    setState(() => _isRecurring = value ?? false);
                  },
                ),
                if (_isRecurring) ...[
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _recurringFrequency,
                    decoration: const InputDecoration(
                      labelText: 'Frequency',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'daily', child: Text('Daily')),
                      DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
                      DropdownMenuItem(
                          value: 'monthly', child: Text('Monthly')),
                      DropdownMenuItem(value: 'yearly', child: Text('Yearly')),
                    ],
                    onChanged: (value) {
                      setState(() => _recurringFrequency = value ?? 'monthly');
                    },
                  ),
                ],
                const SizedBox(height: 16),
                CustomTextField(
                  controller: _notesController,
                  labelText: 'Notes (Optional)',
                  maxLines: 3,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        CustomButton(
          text: 'Save',
          onPressed: _saveExpenditure,
        ),
      ],
    );
  }

  void _showAddCategoryDialog() {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    String selectedColor = '#2196F3';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add Category'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CustomTextField(
                controller: nameController,
                labelText: 'Category Name',
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: descriptionController,
                labelText: 'Description',
              ),
              const SizedBox(height: 16),
              Text('Color'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  '#2196F3',
                  '#4CAF50',
                  '#FF9800',
                  '#9C27B0',
                  '#F44336',
                  '#607D8B',
                  '#795548',
                  '#9E9E9E'
                ]
                    .map((color) => GestureDetector(
                          onTap: () => setState(() => selectedColor = color),
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Color(
                                  int.parse(color.replaceFirst('#', '0xFF'))),
                              shape: BoxShape.circle,
                              border: selectedColor == color
                                  ? Border.all(color: Colors.black, width: 3)
                                  : null,
                            ),
                          ),
                        ))
                    .toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            CustomButton(
              text: 'Save',
              onPressed: () async {
                if (nameController.text.isNotEmpty) {
                  final category = ExpenditureCategory(
                    id: 'cat_${DateTime.now().millisecondsSinceEpoch}',
                    name: nameController.text,
                    description: descriptionController.text,
                    color: selectedColor,
                    createdAt: DateTime.now(),
                  );
                  await _expenditureService.createCategory(category);
                  Navigator.pop(context);
                  _loadData();
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveExpenditure() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      final selectedCategory = _categories.firstWhere(
        (cat) => cat.id == _selectedCategoryId,
      );

      final selectedOutlet = _outlets.firstWhere(
        (outlet) => outlet.id == _selectedOutletForForm,
      );

      final expenditure = Expenditure(
        id: _editingExpenditure?.id ?? '',
        outletId: selectedOutlet.id,
        outletName: selectedOutlet.name,
        category: selectedCategory.name,
        description: _descriptionController.text,
        amount: double.parse(_amountController.text),
        paymentMethod: _selectedPaymentMethod,
        receiptNumber:
            _receiptController.text.isNotEmpty ? _receiptController.text : null,
        vendorName:
            _vendorController.text.isNotEmpty ? _vendorController.text : null,
        dateIncurred: _selectedDate,
        createdAt: _editingExpenditure?.createdAt ?? DateTime.now(),
        isRecurring: _isRecurring,
        recurringFrequency: _isRecurring ? _recurringFrequency : null,
        notes: _notesController.text.isNotEmpty ? _notesController.text : null,
      );

      if (_editingExpenditure != null) {
        await _expenditureService.updateExpenditure(expenditure);
        _showSuccessSnackBar('Expenditure updated successfully');
      } else {
        await _expenditureService.createExpenditure(expenditure);
        _showSuccessSnackBar('Expenditure added successfully');
      }

      Navigator.pop(context);
      _loadData();
    } catch (e) {
      _showErrorSnackBar('Error saving expenditure: $e');
    }
  }

  DateTime _calculateNextDueDate() {
    switch (_recurringFrequency) {
      case 'daily':
        return _selectedDate.add(const Duration(days: 1));
      case 'weekly':
        return _selectedDate.add(const Duration(days: 7));
      case 'monthly':
        return DateTime(
            _selectedDate.year, _selectedDate.month + 1, _selectedDate.day);
      case 'yearly':
        return DateTime(
            _selectedDate.year + 1, _selectedDate.month, _selectedDate.day);
      default:
        return _selectedDate.add(const Duration(days: 30));
    }
  }

  void _clearForm() {
    _descriptionController.clear();
    _amountController.clear();
    _receiptController.clear();
    _vendorController.clear();
    _notesController.clear();
    _selectedPaymentMethod = 'cash';
    _selectedDate = DateTime.now();
    _isRecurring = false;
    _recurringFrequency = 'monthly';
    _editingExpenditure = null;
    if (_categories.isNotEmpty) {
      _selectedCategoryId = _categories.first.id;
    }
    if (_outlets.isNotEmpty) {
      _selectedOutletForForm = _outlets.first.id;
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'utilities':
        return Icons.electrical_services;
      case 'rent & lease':
        return Icons.home;
      case 'maintenance':
        return Icons.build;
      case 'office supplies':
        return Icons.inventory;
      case 'transportation':
        return Icons.local_shipping;
      case 'marketing':
        return Icons.campaign;
      case 'staff expenses':
        return Icons.people;
      default:
        return Icons.receipt;
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }



  Future<void> _exportToPDF() async {
    try {
      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return [
              pw.Header(
                level: 0,
                child: pw.Text('Business Expenditures Report',
                    style: pw.TextStyle(
                        fontSize: 24, fontWeight: pw.FontWeight.bold)),
              ),
              pw.SizedBox(height: 20),
              pw.Text(
                  'Generated on: ${DateFormat('MMM dd, yyyy HH:mm').format(DateTime.now())}'),
              pw.SizedBox(height: 20),
              pw.Table.fromTextArray(
                headers: [
                  'Description',
                  'Category',
                  'Outlet',
                  'Amount',
                  'Date',
                  'Payment Method'
                ],
                data: _expenditures
                    .map((exp) => [
                          exp.description,
                          exp.category,
                          exp.outletName,
                          _formatCurrency(exp.amount),
                          DateFormat('MMM dd, yyyy').format(exp.dateIncurred),
                          exp.paymentMethod?.toUpperCase() ?? 'CASH',
                        ])
                    .toList(),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                cellAlignment: pw.Alignment.centerLeft,
              ),
              pw.SizedBox(height: 20),
              pw.Text(
                  'Total Expenditures: ${_formatCurrency(_analytics['totalExpenditure'] ?? 0.0)}',
                  style: pw.TextStyle(
                      fontSize: 16, fontWeight: pw.FontWeight.bold)),
            ];
          },
        ),
      );

      final output = await getApplicationDocumentsDirectory();
      final file = File(
          '${output.path}/expenditures_${DateTime.now().millisecondsSinceEpoch}.pdf');
      await file.writeAsBytes(await pdf.save());

      _showSuccessSnackBar('PDF exported to: ${file.path}');
    } catch (e) {
      _showErrorSnackBar('Error exporting PDF: $e');
    }
  }

  Future<void> _exportToCSV() async {
    try {
      List<List<dynamic>> csvData = [
        [
          'Description',
          'Category',
          'Outlet',
          'Amount',
          'Date',
          'Payment Method',
          'Vendor',
          'Receipt #',
          'Notes'
        ],
        ..._expenditures
            .map((exp) => [
                  exp.description,
                  exp.category,
                  exp.outletName,
                  exp.amount,
                  DateFormat('yyyy-MM-dd').format(exp.dateIncurred),
                  exp.paymentMethod ?? 'cash',
                  exp.vendorName ?? '',
                  exp.receiptNumber ?? '',
                  exp.notes ?? '',
                ])
            .toList(),
      ];

      String csv = const ListToCsvConverter().convert(csvData);

      final output = await getApplicationDocumentsDirectory();
      final file = File(
          '${output.path}/expenditures_${DateTime.now().millisecondsSinceEpoch}.csv');
      await file.writeAsString(csv);

      _showSuccessSnackBar('CSV exported to: ${file.path}');
    } catch (e) {
      _showErrorSnackBar('Error exporting CSV: $e');
    }
  }
}
