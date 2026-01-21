import 'package:flutter/material.dart';
import '../../core/services/auth_service.dart';

class Sidebar extends StatelessWidget {
  final AuthService _authService = AuthService();

  Sidebar({super.key});

  @override
  Widget build(BuildContext context) {
    // Get the screen height to ensure sidebar takes full height
    final screenHeight = MediaQuery.of(context).size.height;
    final colorScheme = Theme.of(context).colorScheme;

    return Drawer(
      elevation: 4.0,
      child: Container(
        height: screenHeight, // Ensure full height
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
        child: Column(
          children: [
            DrawerHeader(
              margin: EdgeInsets.zero,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    colorScheme.primary,
                    colorScheme.primary.withOpacity(0.8),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.admin_panel_settings,
                        size: 48,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Admin Dashboard',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                children: [
                  _buildNavItem(
                    context: context,
                    icon: Icons.dashboard,
                    title: 'Dashboard',
                    route: '/dashboard',
                    colorScheme: colorScheme,
                  ),
                  _buildNavItem(
                    context: context,
                    icon: Icons.people,
                    title: 'Reps',
                    route: '/reps',
                    colorScheme: colorScheme,
                  ),
                  _buildNavItem(
                    context: context,
                    icon: Icons.campaign,
                    title: 'Marketers',
                    route: '/marketers',
                    colorScheme: colorScheme,
                  ),
                  _buildNavItem(
                    context: context,
                    icon: Icons.store,
                    title: 'Outlets',
                    route: '/outlets',
                    colorScheme: colorScheme,
                  ),
                  _buildNavItem(
                    context: context,
                    icon: Icons.inventory,
                    title: 'Products',
                    route: '/products',
                    colorScheme: colorScheme,
                  ),
                  _buildNavItem(
                    context: context,
                    icon: Icons.point_of_sale,
                    title: 'Sales',
                    route: '/sales',
                    colorScheme: colorScheme,
                  ),
                  _buildNavItem(
                    context: context,
                    icon: Icons.assessment,
                    title: 'Outlets Stock Balance',
                    route: '/stock',
                    colorScheme: colorScheme,
                  ),
                  _buildNavItem(
                    context: context,
                    icon: Icons.inventory_2,
                    title: 'Stock Intake',
                    route: '/stock-intake',
                    colorScheme: colorScheme,
                  ),
                  _buildNavItem(
                    context: context,
                    icon: Icons.fact_check,
                    title: 'Stock Count',
                    route: '/stock-count',
                    colorScheme: colorScheme,
                  ),
                  _buildNavItem(
                    context: context,
                    icon: Icons.receipt_long,
                    title: 'Expenditures',
                    route: '/expenditures',
                    colorScheme: colorScheme,
                  ),
                  _buildNavItem(
                    context: context,
                    icon: Icons.group,
                    title: 'Customers',
                    route: '/customers',
                    colorScheme: colorScheme,
                  ),
                  _buildNavItem(
                    context: context,
                    icon: Icons.sync,
                    title: 'Sync',
                    route: '/sync',
                    colorScheme: colorScheme,
                  )
                ],
              ),
            ),
            Divider(height: 1, color: Colors.grey.shade300),
            _buildNavItem(
              context: context,
              icon: Icons.logout,
              title: 'Logout',
              colorScheme: colorScheme,
              onTap: () async {
                try {
                  // Add 5-second timeout to prevent indefinite hang
                  await _authService.signOut().timeout(
                    const Duration(seconds: 5),
                    onTimeout: () {
                      debugPrint('Logout timeout - forcing logout');
                      return;
                    },
                  );
                } catch (e) {
                  debugPrint('Logout error: $e');
                  // Continue to logout screen even on error
                } finally {
                  // Always navigate to login, regardless of signOut result
                  if (context.mounted) {
                    Navigator.of(context).pushNamedAndRemoveUntil(
                      '/login',
                      (route) => false, // Clear the entire navigation stack
                    );
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    String? route,
    required ColorScheme colorScheme,
    VoidCallback? onTap,
  }) {
    final currentRoute = ModalRoute.of(context)?.settings.name;
    final isSelected = route != null && currentRoute == route;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        leading: Icon(
          icon,
          color: isSelected ? colorScheme.primary : Colors.grey[700],
          size: 22,
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? colorScheme.primary : Colors.grey[800],
            fontSize: 15,
          ),
        ),
        tileColor: isSelected ? colorScheme.primary.withOpacity(0.1) : null,
        onTap: onTap ?? () => Navigator.pushNamed(context, route!),
      ),
    );
  }
}
