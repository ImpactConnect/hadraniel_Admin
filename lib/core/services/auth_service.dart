import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'sync_service.dart';
import '../models/profile_model.dart';

class AuthService {
  final supabase = Supabase.instance.client;
  final storage = const FlutterSecureStorage();
  final SyncService _syncService = SyncService();

  Future<User?> getCurrentUser() async {
    return supabase.auth.currentUser;
  }

  Future<AuthResponse> signIn(String email, String password) async {
    try {
      final response = await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user != null) {
        // Store credentials for offline login
        await storage.write(key: 'email', value: email);
        await storage.write(key: 'password', value: password);

        // Sync user profile to local DB
        await _syncService.syncProfilesToLocalDb();
      }

      return response;
    } catch (e) {
      print('Error signing in: $e');
      throw e;
    }
  }

  Future<void> signOut() async {
    await supabase.auth.signOut();
    await storage.deleteAll(); // Clear stored credentials
  }

  Future<bool> offlineLogin(String email, String password) async {
    try {
      final storedEmail = await storage.read(key: 'email');
      final storedPassword = await storage.read(key: 'password');

      if (email == storedEmail && password == storedPassword) {
        // Verify user exists in local DB and has admin role
        final user = await _syncService.getLocalUserProfile(email);
        return user != null && user.role == 'admin';
      }
      return false;
    } catch (e) {
      print('Error during offline login: $e');
      return false;
    }
  }

  Future<Profile?> getUserProfile(String userId) async {
    try {
      // Try to get profile from local DB first
      Profile? profile = await _syncService.getLocalUserProfile(userId);

      // If online and profile not found locally, try to fetch from Supabase
      if (profile == null && supabase.auth.currentSession != null) {
        final response =
            await supabase.from('profiles').select().eq('id', userId).single();

        if (response != null) {
          profile = Profile.fromMap(response);
          // Save to local DB
          await _syncService.syncProfilesToLocalDb();
        }
      }

      return profile;
    } catch (e) {
      print('Error getting user profile: $e');
      return null;
    }
  }
}
