import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/models/customer_model.dart';
import '../../core/models/outlet_model.dart';
import '../../core/services/customer_service.dart';
import '../../core/services/sync_service.dart';
import '../../widgets/dashboard_layout.dart';
import 'add_customer_dialog.dart';
import 'customer_details_dialog.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  late CustomerService _customerService;
  late SyncService _syncService;
  List<Customer> _customers = [];
  List<Outlet> _outlets = [];
  String _searchQuery = '';
  String? _selectedOutlet;
  bool _showOnlyWithBalance = false;
  double _totalOutstanding = 0.0;

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _customerService = CustomerService();
    _syncService = SyncService();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    try {
      // Only sync if online, otherwise use existing local data
      if (await _syncService.isOnline()) {
        await _syncService.syncCustomersToLocalDb();
      }
      await _loadCustomers();
      await _loadOutlets();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error initializing services: $e')),
        );
      }
    }
  }

  Future<void> _loadOutlets() async {
    try {
      final outlets = await _syncService.getAllLocalOutlets();
      if (mounted) {
        setState(() {
          _outlets = outlets;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading outlets: $e')));
      }
    }
  }

  Future<void> _loadCustomers() async {
    try {
      List<Customer> customers;
      if (_showOnlyWithBalance) {
        customers = await _customerService.getCustomersWithOutstandingBalance();
      } else {
        customers = await _customerService.getCustomers(
          outletId: _selectedOutlet,
        );
      }

      if (_searchQuery.isNotEmpty) {
        customers = customers
            .where(
              (customer) =>
                  customer.fullName.toLowerCase().contains(
                    _searchQuery.toLowerCase(),
                  ) ||
                  (customer.phone?.toLowerCase().contains(
                        _searchQuery.toLowerCase(),
                      ) ??
                      false),
            )
            .toList();
      }

      final total = await _customerService.getTotalOutstandingBalance();

      setState(() {
        _customers = customers;
        _totalOutstanding = total;
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading customers: $e')));
    }
  }

  void _showAddCustomerDialog() {
    showDialog(
      context: context,
      builder: (context) => AddCustomerDialog(
        onCustomerAdded: (customer) {
          setState(() {
            _customers.add(customer);
          });
          _loadCustomers(); // Refresh the list
        },
      ),
    );
  }

  void _showCustomerDetails(Customer customer) {
    showDialog(
      context: context,
      builder: (context) => CustomerDetailsDialog(customer: customer),
    );
  }

  Widget _buildMetricCard(
    String title,
    String value,
    IconData icon,
    Color startColor,
    Color endColor,
  ) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(20.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [startColor, endColor],
          ),
        ),
        child: Column(
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
                  child: Icon(icon, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: colorScheme.primary, size: 24),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DashboardLayout(
      title: 'Customers',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Overview', Icons.dashboard),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    'Total Outstanding',
                    '₦${NumberFormat('#,##0.00').format(_totalOutstanding)}',
                    Icons.account_balance_wallet,
                    Colors.purple.shade400,
                    Colors.purple.shade700,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildMetricCard(
                    'Total Customers',
                    _customers.length.toString(),
                    Icons.people,
                    Colors.blue.shade400,
                    Colors.blue.shade700,
                  ),
                ),
              ],
            ),
          ),
          _buildSectionTitle('Filters & Search', Icons.filter_list),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search customers...',
                          prefixIcon: Icon(
                            Icons.search,
                            color: colorScheme.primary,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: colorScheme.primary.withOpacity(0.2),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: colorScheme.primary.withOpacity(0.2),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: colorScheme.primary),
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                        ),
                        onChanged: (value) {
                          setState(() {
                            _searchQuery = value;
                          });
                          _loadCustomers();
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: colorScheme.primary.withOpacity(0.2),
                        ),
                        color: Colors.grey.shade50,
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedOutlet,
                          hint: Text(
                            'All Outlets',
                            style: TextStyle(color: colorScheme.primary),
                          ),
                          icon: Icon(
                            Icons.arrow_drop_down,
                            color: colorScheme.primary,
                          ),
                          items: [
                            DropdownMenuItem(
                              value: null,
                              child: Text(
                                'All Outlets',
                                style: TextStyle(color: colorScheme.primary),
                              ),
                            ),
                            ..._outlets.map(
                              (outlet) => DropdownMenuItem(
                                value: outlet.id,
                                child: Text(outlet.name),
                              ),
                            ),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _selectedOutlet = value;
                            });
                            _loadCustomers();
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    FilterChip(
                      label: const Text('With Balance'),
                      selected: _showOnlyWithBalance,
                      selectedColor: colorScheme.primary.withOpacity(0.2),
                      checkmarkColor: colorScheme.primary,
                      labelStyle: TextStyle(
                        color: _showOnlyWithBalance
                            ? colorScheme.primary
                            : Colors.black87,
                        fontWeight: _showOnlyWithBalance
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                      onSelected: (selected) {
                        setState(() {
                          _showOnlyWithBalance = selected;
                        });
                        _loadCustomers();
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          _buildSectionTitle('Customer List', Icons.list),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: colorScheme.primary,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(12),
                          topRight: Radius.circular(12),
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        children: const [
                          SizedBox(width: 24),
                          Expanded(
                            flex: 2,
                            child: Text(
                              'Name',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              'Phone',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              'Outlet',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              'Outstanding Balance',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              'Created At',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          SizedBox(width: 24),
                        ],
                      ),
                    ),
                    Expanded(
                      child: _customers.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.people_outline,
                                    size: 48,
                                    color: Colors.grey.shade400,
                                  ),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'No customers found',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontStyle: FontStyle.italic,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              itemCount: _customers.length,
                              itemBuilder: (context, index) {
                                final customer = _customers[index];
                                return InkWell(
                                  onTap: () => _showCustomerDetails(customer),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      border: Border(
                                        bottom: BorderSide(
                                          color: Colors.grey.shade200,
                                        ),
                                      ),
                                      color: index % 2 == 0
                                          ? Colors.grey.shade50
                                          : Colors.white,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    child: Row(
                                      children: [
                                        const SizedBox(width: 24),
                                        Expanded(
                                          flex: 2,
                                          child: Text(
                                            customer.fullName,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 2,
                                          child: Text(customer.phone ?? '-'),
                                        ),
                                        Expanded(
                                          flex: 2,
                                          child: FutureBuilder<String>(
                                            future: _syncService.getOutletName(
                                              customer.outletId ?? '',
                                            ),
                                            builder: (context, snapshot) {
                                              return Text(snapshot.data ?? '-');
                                            },
                                          ),
                                        ),
                                        Expanded(
                                          flex: 2,
                                          child: Text(
                                            '₦${NumberFormat('#,##0.00').format(customer.totalOutstanding)}',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color:
                                                  customer.totalOutstanding > 0
                                                  ? Colors.red.shade700
                                                  : Colors.green.shade700,
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 2,
                                          child: Text(
                                            DateFormat(
                                              'yyyy-MM-dd',
                                            ).format(customer.createdAt),
                                          ),
                                        ),
                                        const SizedBox(width: 24),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddCustomerDialog,
        backgroundColor: colorScheme.primary,
        child: const Icon(Icons.add),
      ),
    );
  }
}
