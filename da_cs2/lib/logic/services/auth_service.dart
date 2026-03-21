import 'package:supabase_flutter/supabase_flutter.dart';

/// Service quản lý authentication
class AuthService {
  static final AuthService _instance = AuthService._internal();

  factory AuthService() => _instance;

  AuthService._internal();

  final _supabase = Supabase.instance.client;

  /// Lấy user hiện tại
  User? getCurrentUser() {
    return _supabase.auth.currentUser;
  }

  /// Đăng nhập
  Future<AuthResponse> signInWithPassword({
    required String email,
    required String password,
  }) async {
    try {
      return await _supabase.auth.signInWithPassword(
        email: email.trim(),
        password: password.trim(),
      );
    } catch (e) {
      print('Error signing in: $e');
      rethrow;
    }
  }

  /// Đăng ký tài khoản mới
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String username,
  }) async {
    try {
      final response = await _supabase.auth.signUp(
        email: email.trim(),
        password: password.trim(),
      );

      final userId = response.user?.id;
      if (userId != null) {
        // Lưu thông tin profile
        await _supabase.from('profiles').insert({
          'id': userId,
          'username': username.trim(),
          'email': email.trim(),
          'balance': 0,
        });
      }

      return response;
    } catch (e) {
      print('Error signing up: $e');
      rethrow;
    }
  }

  /// Đăng xuất
  Future<void> signOut() async {
    try {
      await _supabase.auth.signOut();
    } catch (e) {
      print('Error signing out: $e');
      rethrow;
    }
  }

  /// Cập nhật user
  Future<void> updateUser(UserAttributes attributes) async {
    try {
      await _supabase.auth.updateUser(attributes);
    } catch (e) {
      print('Error updating user: $e');
      rethrow;
    }
  }
}
