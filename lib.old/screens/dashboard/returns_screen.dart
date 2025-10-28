import 'package:flutter/material.dart';
import '../../widgets/dashboard_layout.dart';

class ReturnsScreen extends StatefulWidget {
  const ReturnsScreen({super.key});

  @override
  State<ReturnsScreen> createState() => _ReturnsScreenState();
}

class _ReturnsScreenState extends State<ReturnsScreen> {
  @override
  Widget build(BuildContext context) {
    return const DashboardLayout(
      title: 'Returns',
      child: Center(child: Text('Returns Screen - Coming Soon')),
    );
  }
}
