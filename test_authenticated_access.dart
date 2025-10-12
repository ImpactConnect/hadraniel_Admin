import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

Future<void> _loadEnvWithFallback() async {
  // Try root .env first, then fallback to lib/env/.env
  try {
    await dotenv.load(fileName: '.env');
    print('✅ Loaded env from .env');
    return;
  } catch (_) {}

  try {
    await dotenv.load(fileName: 'lib/env/.env');
    print('✅ Loaded env from lib/env/.env');
    return;
  } catch (e) {
    print('❌ Failed to load env file: $e');
    rethrow;
  }
}

Future<void> main() async {
  try {
    // Load environment variables with fallback
    await _loadEnvWithFallback();

    // Initialize Supabase
    await Supabase.initialize(
      url: dotenv.env['SUPABASE_URL']!,
      anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
    );

    final supabase = Supabase.instance.client;

    print('🔍 Testing authenticated table access...\n');

    // First, let's check if we're already authenticated
    var user = supabase.auth.currentUser;
    if (user == null) {
      print('❌ No authenticated user found.');
      print('Please sign in through the app first, then run this test.');
      return;
    }

    print('✅ Authenticated user: ${user.email}');
    print('🆔 User ID: ${user.id}');

    // Test 1: Check user profile and role
    print('\n1. Testing user profile access and admin role:');
    try {
      final profileResponse = await supabase
          .from('profiles')
          .select('id, full_name, role, outlet_id')
          .eq('id', user.id)
          .single();
      print('   ✅ User profile retrieved: ${profileResponse}');

      final userRole = profileResponse['role'];
      print('   👤 User role: $userRole');

      if (userRole != 'admin') {
        print(
            '   ⚠️  Warning: User is not an admin. This may affect table access.');
      } else {
        print('   🛡️  User has admin role; should see all outlets data.');
      }
    } catch (e) {
      print('   ❌ Failed to get user profile: $e');
      return;
    }

    print('');

    // Test 2: Products table access with detailed error info
    print('2. Testing products table SELECT access:');
    try {
      final productsResponse = await supabase
          .from('products')
          .select('id, product_name, outlet_id, created_at')
          .limit(5);
      print(
          '   ✅ Products SELECT successful - Found ${productsResponse.length} records');
      if (productsResponse.isNotEmpty) {
        print('   📋 Sample product: ${productsResponse.first}');
      } else {
        print('   ℹ️  No products found in database');
      }
    } catch (e) {
      print('   ❌ Products SELECT failed: $e');
      print('   🔍 Error type: ${e.runtimeType}');
    }

    print('');

    // Test 3: Try to insert a test product (admin should be able to do this)
    print('3. Testing products table INSERT access:');
    try {
      final testProduct = {
        'id': 'test-product-${DateTime.now().millisecondsSinceEpoch}',
        'product_name': 'Test Product for RLS',
        'outlet_id': 'test-outlet-id',
        'quantity': 10,
        'cost_per_unit': 5.0,
        'selling_price': 10.0,
        'created_at': DateTime.now().toIso8601String(),
      };

      final insertResponse =
          await supabase.from('products').insert(testProduct).select().single();

      print('   ✅ Products INSERT successful: ${insertResponse['id']}');

      // Clean up - delete the test product
      await supabase.from('products').delete().eq('id', insertResponse['id']);
      print('   🧹 Test product cleaned up');
    } catch (e) {
      print('   ❌ Products INSERT failed: $e');
      print('   🔍 Error type: ${e.runtimeType}');
    }

    print('');

    // Test 4: Stock balances table access
    print('4. Testing stock_balances table SELECT access:');
    try {
      final stockResponse = await supabase
          .from('stock_balances')
          .select('id, outlet_id, product_id, given_quantity, balance_quantity')
          .limit(5);
      print(
          '   ✅ Stock balances SELECT successful - Found ${stockResponse.length} records');
      if (stockResponse.isNotEmpty) {
        print('   📋 Sample stock balance: ${stockResponse.first}');
      } else {
        print('   ℹ️  No stock balances found in database');
      }
    } catch (e) {
      print('   ❌ Stock balances SELECT failed: $e');
      print('   🔍 Error type: ${e.runtimeType}');
    }

    print('');

    // Test 5: Check RLS policies
    print('5. Checking RLS policy status:');
    try {
      final rlsQuery = '''
        SELECT schemaname, tablename, rowsecurity 
        FROM pg_tables 
        WHERE schemaname = 'public' 
        AND tablename IN ('products', 'stock_balances')
      ''';

      final rlsResponse =
          await supabase.rpc('exec_sql', params: {'sql': rlsQuery});
      print('   📊 RLS Status: $rlsResponse');
    } catch (e) {
      print('   ⚠️  Could not check RLS status: $e');
    }

    print('\n🏁 Authenticated table access test completed!');
  } catch (e) {
    print('❌ Test failed with error: $e');
    print('🔍 Error type: ${e.runtimeType}');
  }
}
