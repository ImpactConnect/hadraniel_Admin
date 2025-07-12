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
    final isDesktop = MediaQuery.of(context).size.width >= 768;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      appBar: AppBar(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        // Remove the hamburger menu for desktop view
        automaticallyImplyLeading: !isDesktop,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {},
            tooltip: 'Notifications',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Permanent sidebar for larger screens
          if (isDesktop)
            Container(
              width: 256, // Fixed width for the sidebar
              height:
                  MediaQuery.of(context).size.height -
                  AppBar().preferredSize.height -
                  MediaQuery.of(context).padding.top,
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Sidebar(),
            ),
          // Main content area
          Expanded(
            child: Container(
              height: double.infinity,
              color: Colors.grey[50], // Light background for content area
              child: child,
            ),
          ),
        ],
      ),
      // Drawer for mobile screens
      drawer: !isDesktop ? Sidebar() : null,
      // Add floating action button if provided
      floatingActionButton: floatingActionButton,
    );
  }
}
