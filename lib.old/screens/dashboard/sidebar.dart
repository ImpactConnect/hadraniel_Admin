import 'package:flutter/material.dart';
import '../../core/services/auth_service.dart';

class Sidebar extends StatelessWidget {
  final AuthService _authService = AuthService();

  Sidebar({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(color: Colors.blue),
            child: Text(
              'Admin Dashboard',
              style: TextStyle(color: Colors.white, fontSize: 24),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.dashboard),
            title: const Text('Dashboard'),
            onTap: () => Navigator.pushNamed(context, '/dashboard'),
          ),
          ListTile(
            leading: const Icon(Icons.people),
            title: const Text('Reps'),
            onTap: () => Navigator.pushNamed(context, '/reps'),
          ),
          ListTile(
            leading: const Icon(Icons.store),
            title: const Text('Outlets'),
            onTap: () => Navigator.pushNamed(context, '/outlets'),
          ),
          ListTile(
            leading: const Icon(Icons.inventory),
            title: const Text('Products'),
            onTap: () => Navigator.pushNamed(context, '/products'),
          ),
          ListTile(
            leading: const Icon(Icons.point_of_sale),
            title: const Text('Sales'),
            onTap: () => Navigator.pushNamed(context, '/sales'),
          ),
          ListTile(
            leading: const Icon(Icons.assessment),
            title: const Text('Stock Balance'),
            onTap: () => Navigator.pushNamed(context, '/stock'),
          ),
          ListTile(
            leading: const Icon(Icons.group),
            title: const Text('Customers'),
            onTap: () => Navigator.pushNamed(context, '/customers'),
          ),
          ListTile(
            leading: const Icon(Icons.sync),
            title: const Text('Sync'),
            onTap: () => Navigator.pushNamed(context, '/sync'),
          ),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Settings'),
            onTap: () => Navigator.pushNamed(context, '/settings'),
          ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Logout'),
            onTap: () async {
              await _authService.signOut();
              if (context.mounted) {
                Navigator.pushReplacementNamed(context, '/login');
              }
            },
          ),
        ],
      ),
    );
  }
}
