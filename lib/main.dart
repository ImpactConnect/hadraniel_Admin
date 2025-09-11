import 'dart:io' show Platform, File;
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
import 'screens/dashboard/expenditures_screen.dart';
import 'screens/stock_intake_screen.dart';
import 'screens/dashboard/stock_count_screen.dart';

Future<void> _initializeSupabaseWithRetry({
  required String url,
  required String anonKey,
  int maxRetries = 3,
}) async {
  // Check if Supabase is already initialized
  try {
    final client = Supabase.instance.client;
    if (client.auth.currentUser != null || client.supabaseUrl.isNotEmpty) {
      print('Supabase is already initialized, skipping initialization');
      return;
    }
  } catch (e) {
    // Supabase not initialized yet, proceed with initialization
    print('Supabase not yet initialized, proceeding with initialization');
  }

  for (int attempt = 1; attempt <= maxRetries; attempt++) {
    try {
      print(
          'Attempting Supabase initialization (attempt $attempt/$maxRetries)');

      // Clean up any existing lock files before initialization
      await _cleanupLockFiles();

      await Supabase.initialize(
        url: url,
        anonKey: anonKey,
      );

      print('Supabase initialized successfully');
      return;
    } catch (e) {
      // Check if the error is due to already being initialized
      if (e.toString().contains('This instance is already initialized')) {
        print(
            'Supabase is already initialized by another instance, continuing...');
        return;
      }

      print('Supabase initialization attempt $attempt failed: $e');

      if (attempt < maxRetries) {
        // Wait before retrying
        await Future.delayed(Duration(seconds: attempt * 2));

        // Clean up lock files before retry
        await _cleanupLockFiles();
      } else {
        print('All Supabase initialization attempts failed');
        rethrow;
      }
    }
  }
}

Future<void> _cleanupLockFiles() async {
  try {
    final lockPaths = [
      'C:\\Users\\HP\\Documents\\auth\\supabase_authentication.lock',
      'C:\\Users\\HP\\AppData\\Local\\supabase\\auth\\supabase_authentication.lock',
    ];

    for (final lockPath in lockPaths) {
      final lockFile = File(lockPath);
      if (await lockFile.exists()) {
        try {
          await lockFile.delete();
          print('Removed lock file: $lockPath');
        } catch (e) {
          print('Failed to remove lock file $lockPath: $e');
        }
      }
    }
  } catch (e) {
    print('Error during lock file cleanup: $e');
  }
}

void main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();

    // Initialize SQLite for Windows
    if (Platform.isWindows || Platform.isLinux) {
      // Initialize FFI
      sqfliteFfiInit();
      // Change the default factory for windows
      databaseFactory = databaseFactoryFfi;
    }

    // Initialize DatabaseHelper after setting up the database factory
    final dbHelper = DatabaseHelper();
    await dbHelper.database;

    // Load environment variables
    await dotenv.load(fileName: '.env');

    // Debug: Print environment variables
    print('SUPABASE_URL: ${dotenv.env['SUPABASE_URL']}');
    print(
        'SUPABASE_ANON_KEY: ${dotenv.env['SUPABASE_ANON_KEY']?.substring(0, 20)}...');

    // Initialize Supabase with retry mechanism
    await _initializeSupabaseWithRetry(
      url: dotenv.env['SUPABASE_URL'] ?? '',
      anonKey: dotenv.env['SUPABASE_ANON_KEY'] ?? '',
    );

    print('App initialization completed successfully');
    runApp(const MyApp());
  } catch (e, stackTrace) {
    print('Error during app initialization: $e');
    print('Stack trace: $stackTrace');

    // Provide user-friendly error message for Supabase initialization conflicts
    String errorMessage = 'Error: $e';
    if (e.toString().contains('This instance is already initialized')) {
      errorMessage =
          'Another instance of the app is already running. Please close other instances and try again.';
    }

    // Run a minimal app to show the error
    runApp(MaterialApp(
      home: Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text('App Initialization Error',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32.0),
                child: Text(errorMessage, textAlign: TextAlign.center),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  // Restart the app
                  main();
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    ));
  }
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
    try {
      print('Checking user session...');
      final currentUser = await _authService.getCurrentUser();
      print('Current user: ${currentUser?.id}');

      if (currentUser != null) {
        final profile = await _authService.getUserProfile(currentUser.id);
        print('User profile: ${profile?.role}');
        if (profile != null && profile.role == 'admin') {
          setState(() {
            _isAuthenticated = true;
          });
        }
      }
    } catch (e) {
      print('Error checking session: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hadraniel Admin',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        platform: TargetPlatform.android, // Force Material design
      ),
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
        '/stock-count': (context) => const StockCountScreen(),
        '/expenditures': (context) => const ExpendituresScreen(),
        '/customers': (context) => const CustomersScreen(),
        '/settings': (context) => const SettingsScreen(),
      },
      debugShowCheckedModeBanner: false,
    );
  }
}
