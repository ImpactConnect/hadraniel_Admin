import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  try {
    print('Testing .env file loading...');

    // Load environment variables
    await dotenv.load(fileName: '.env');

    print('Environment variables loaded successfully!');
    print('SUPABASE_URL: ${dotenv.env['SUPABASE_URL']}');
    print(
        'SUPABASE_ANON_KEY: ${dotenv.env['SUPABASE_ANON_KEY']?.substring(0, 20)}...');

    if (dotenv.env['SUPABASE_URL'] == null ||
        dotenv.env['SUPABASE_URL']!.isEmpty) {
      print('ERROR: SUPABASE_URL is missing or empty!');
    }

    if (dotenv.env['SUPABASE_ANON_KEY'] == null ||
        dotenv.env['SUPABASE_ANON_KEY']!.isEmpty) {
      print('ERROR: SUPABASE_ANON_KEY is missing or empty!');
    }

    print('.env file test completed successfully!');
  } catch (e, stackTrace) {
    print('.env file loading failed:');
    print('Error: $e');
    print('Stack trace: $stackTrace');
  }
}
