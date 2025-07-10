import 'package:flutter/material.dart';
import 'sidebar.dart';

class StockScreen extends StatefulWidget {
  const StockScreen({super.key});

  @override
  State<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends State<StockScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stock Balance'),
      ),
      drawer: Sidebar(),
      body: const Center(
        child: Text('Stock Balance Screen - Coming Soon'),
      ),
    );
  }
}