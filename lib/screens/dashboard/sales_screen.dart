import 'package:flutter/material.dart';
import 'sidebar.dart';

class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sales'),
      ),
      drawer: Sidebar(),
      body: const Center(
        child: Text('Sales Screen - Coming Soon'),
      ),
    );
  }
}