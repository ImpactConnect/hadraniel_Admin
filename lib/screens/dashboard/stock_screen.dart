import 'package:flutter/material.dart';
import '../../widgets/dashboard_layout.dart';

class StockScreen extends StatefulWidget {
  const StockScreen({super.key});

  @override
  State<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends State<StockScreen> {
  @override
  Widget build(BuildContext context) {
    return const DashboardLayout(
      title: 'Stock Balance',
      child: Center(child: Text('Stock Balance Screen - Coming Soon')),
    );
  }
}
