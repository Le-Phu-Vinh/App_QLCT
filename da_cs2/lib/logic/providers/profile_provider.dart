import 'package:supabase_flutter/supabase_flutter.dart';
import '../../utils/constants.dart';

/// Provider quản lý dữ liệu profile người dùng
class ProfileProvider {
  static final ProfileProvider _instance = ProfileProvider._internal();

  factory ProfileProvider() => _instance;

  ProfileProvider._internal();

  final _supabase = Supabase.instance.client;

  /// Lấy stream dữ liệu profile người dùng
  Stream<List<Map<String, dynamic>>> getProfileStream(String? userId) {
    if (userId == null) {
      return Stream.value([]);
    }

    return _supabase
        .from(AppConstants.profilesTable)
        .stream(primaryKey: ['id'])
        .eq('id', userId)
        .limit(1);
  }

  /// Cập nhật dữ liệu profile
  Future<void> updateProfile({
    required String userId,
    required num balance,
    required num expense,
    required num income,
  }) async {
    try {
      await _supabase
          .from(AppConstants.profilesTable)
          .update({'balance': balance, 'expense': expense, 'income': income})
          .eq('id', userId);
    } catch (e) {
      print('Error updating profile: $e');
      rethrow;
    }
  }

  /// Tải thông tin profile từ Supabase
  Future<Map<String, dynamic>?> loadProfile(String userId) async {
    try {
      final res = await _supabase
          .from(AppConstants.profilesTable)
          .select('username, email')
          .eq('id', userId)
          .maybeSingle();
      return res;
    } catch (e) {
      print('Error loading profile: $e');
      return null;
    }
  }

  /// Cập nhật tên người dùng
  Future<void> updateUsername(String userId, String newUsername) async {
    try {
      await _supabase
          .from(AppConstants.profilesTable)
          .update({'username': newUsername})
          .eq('id', userId);
    } catch (e) {
      print('Error updating username: $e');
      rethrow;
    }
  }

  /// Cập nhật email
  Future<void> updateEmail(String userId, String newEmail) async {
    try {
      await _supabase.auth.updateUser(UserAttributes(email: newEmail));
    } catch (e) {
      print('Error updating email: $e');
      rethrow;
    }
  }
}
