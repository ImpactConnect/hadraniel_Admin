import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'screens/auth/login_screen.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'screens/dashboard/reps_screen.dart';
import 'screens/dashboard/outlets_screen.dart';
import 'screens/dashboard/products_screen.dart';
import 'screens/dashboard/sync_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize SQLite for Windows
  sqfliteFfiInit();

  // Load environment variables
  await dotenv.load(fileName: '.env');

  // Initialize Supabase
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL'] ?? '',
    anonKey: dotenv.env['SUPABASE_ANON_KEY'] ?? '',
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hadraniel Admin',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      initialRoute: '/login',
      routes: {
        '/login': (context) => const LoginScreen(),
        '/dashboard': (context) => const DashboardScreen(),
        '/reps': (context) => const RepsScreen(),
        '/outlets': (context) => const OutletsScreen(),
        '/products': (context) => const ProductsScreen(),
        '/sync': (context) => const SyncScreen(),
        // TODO: Add routes for Sales, Stock Balance, Customers, and Settings screens
      },
      debugShowCheckedModeBanner: false,
    );
  }
}
