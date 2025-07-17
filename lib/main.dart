import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/sqflite.dart' show databaseFactory;
import 'core/services/auth_service.dart';
import 'core/database/database_helper.dart';
import 'screens/auth/login_screen.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'screens/dashboard/reps_screen.dart';
import 'screens/dashboard/outlets_screen.dart';
import 'screens/dashboard/products_screen.dart';
import 'screens/dashboard/sync_screen.dart';
import 'screens/dashboard/sales_screen.dart';
import 'screens/dashboard/customers_screen.dart';
import 'screens/dashboard/stock_screen.dart';
import 'screens/dashboard/settings_screen.dart';
import 'screens/stock_intake_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize SQLite for Windows
  if (Platform.isWindows || Platform.isLinux) {
    // Initialize FFI
    sqfliteFfiInit();
    // Change the default factory for windows
    databaseFactory = databaseFactoryFfi;
  }

  // Initialize DatabaseHelper
  final dbHelper = DatabaseHelper();
  await dbHelper.database;

  // Load environment variables
  await dotenv.load(fileName: '.env');

  // Initialize Supabase
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL'] ?? '',
    anonKey: dotenv.env['SUPABASE_ANON_KEY'] ?? '',
  );

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _authService = AuthService();
  bool _isLoading = true;
  bool _isAuthenticated = false;

  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    final currentUser = await _authService.getCurrentUser();
    if (currentUser != null) {
      final profile = await _authService.getUserProfile(currentUser.id);
      if (profile != null && profile.role == 'admin') {
        setState(() {
          _isAuthenticated = true;
        });
      }
    }
    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hadraniel Admin',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _isAuthenticated
          ? const DashboardScreen()
          : const LoginScreen(),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/dashboard': (context) => const DashboardScreen(),
        '/reps': (context) => const RepsScreen(),
        '/outlets': (context) => const OutletsScreen(),
        '/products': (context) => const ProductsScreen(),
        '/sync': (context) => const SyncScreen(),
        '/sales': (context) => const SalesScreen(),
        '/stock': (context) => const StockScreen(),
        '/stock-intake': (context) => const StockIntakeScreen(),
        '/customers': (context) => const CustomersScreen(),
        '/settings': (context) => const SettingsScreen(),
      },
      debugShowCheckedModeBanner: false,
    );
  }
}
