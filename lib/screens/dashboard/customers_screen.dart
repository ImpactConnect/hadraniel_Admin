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

  @override
  Widget build(BuildContext context) {
    return DashboardLayout(
      title: 'Customers',
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
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
                            'Total Outstanding',
                            style: TextStyle(fontSize: 16),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '₦${NumberFormat('#,##0.00').format(_totalOutstanding)}',
                            style: const TextStyle(
                              fontSize: 24,
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
                            'Total Customers',
                            style: TextStyle(fontSize: 16),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _customers.length.toString(),
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search customers...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
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
                DropdownButton<String>(
                  value: _selectedOutlet,
                  hint: const Text('All Outlets'),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('All Outlets'),
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
                const SizedBox(width: 16),
                FilterChip(
                  label: const Text('With Balance'),
                  selected: _showOnlyWithBalance,
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
          const SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Name')),
                  DataColumn(label: Text('Phone')),
                  DataColumn(label: Text('Outlet')),
                  DataColumn(label: Text('Outstanding Balance')),
                  DataColumn(label: Text('Created At')),
                ],
                rows: _customers.map((customer) {
                  return DataRow(
                    cells: [
                      DataCell(
                        Text(customer.fullName),
                        onTap: () => _showCustomerDetails(customer),
                      ),
                      DataCell(Text(customer.phone ?? '-')),
                      DataCell(
                        FutureBuilder<String>(
                          future: _syncService.getOutletName(
                            customer.outletId ?? '',
                          ),
                          builder: (context, snapshot) {
                            return Text(snapshot.data ?? '-');
                          },
                        ),
                      ),
                      DataCell(
                        Text(
                          '₦${NumberFormat('#,##0.00').format(customer.totalOutstanding)}',
                        ),
                      ),
                      DataCell(
                        Text(
                          DateFormat('yyyy-MM-dd').format(customer.createdAt),
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
        onPressed: _showAddCustomerDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}
