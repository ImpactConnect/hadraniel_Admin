import 'package:flutter/material.dart';
import '../../widgets/dashboard_layout.dart';

class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  @override
  Widget build(BuildContext context) {
    return const DashboardLayout(
      title: 'Sales',
      child: Center(child: Text('Sales Screen - Coming Soon')),
    );
  }
}
