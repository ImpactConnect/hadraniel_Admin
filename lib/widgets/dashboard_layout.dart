import 'package:flutter/material.dart';
import '../screens/dashboard/sidebar.dart';

class DashboardLayout extends StatelessWidget {
  final Widget child;
  final String title;
  final Widget? floatingActionButton;

  const DashboardLayout({
    super.key,
    required this.child,
    required this.title,
    this.floatingActionButton,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        // Remove the hamburger menu for desktop view
        automaticallyImplyLeading: MediaQuery.of(context).size.width < 768,
      ),
      body: Row(
        children: [
          // Permanent sidebar for larger screens
          if (MediaQuery.of(context).size.width >= 768)
            SizedBox(
              width: 256, // Fixed width for the sidebar
              child: Sidebar(),
            ),
          // Vertical divider between sidebar and content
          if (MediaQuery.of(context).size.width >= 768)
            const VerticalDivider(width: 1),
          // Main content area
          Expanded(child: child),
        ],
      ),
      // Drawer for mobile screens
      drawer: MediaQuery.of(context).size.width < 768 ? Sidebar() : null,
      // Add floating action button if provided
      floatingActionButton: floatingActionButton,
    );
  }
}
