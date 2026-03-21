import 'dart:convert';
import 'dart:typed_data';
import 'package:shared_preferences/shared_preferences.dart';
import '../../utils/constants.dart';

/// Provider quản lý avatar của người dùng
class AvatarProvider {
  static final AvatarProvider _instance = AvatarProvider._internal();

  factory AvatarProvider() => _instance;

  AvatarProvider._internal();

  Uint8List? _avatarBytes;

  Uint8List? get avatarBytes => _avatarBytes;

  /// Tải avatar từ SharedPreferences
  Future<void> loadAvatar() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final avatarString = prefs.getString(AppConstants.userAvatarKey);
      if (avatarString != null) {
        _avatarBytes = base64Decode(avatarString);
      }
    } catch (e) {
      print('Error loading avatar: $e');
    }
  }

  /// Lưu avatar vào SharedPreferences
  Future<void> saveAvatar(Uint8List bytes) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final avatarString = base64Encode(bytes);
      await prefs.setString(AppConstants.userAvatarKey, avatarString);
      _avatarBytes = bytes;
    } catch (e) {
      print('Error saving avatar: $e');
    }
  }

  /// Xóa avatar
  Future<void> clearAvatar() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(AppConstants.userAvatarKey);
      _avatarBytes = null;
    } catch (e) {
      print('Error clearing avatar: $e');
    }
  }
}
