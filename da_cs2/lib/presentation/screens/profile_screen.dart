import 'package:flutter/material.dart';
import '../../logic/services/auth_service.dart';
import '../../logic/providers/profile_provider.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _authService = AuthService();
  final _profileProvider = ProfileProvider();

  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  /// Tải thông tin profile từ Supabase
  Future<void> _loadProfile() async {
    final userId = _authService.getCurrentUser()?.id;
    if (userId == null) {
      setState(() {
        _loading = false;
        _error = 'Chưa đăng nhập';
      });
      return;
    }

    try {
      final res = await _profileProvider.loadProfile(userId);
      if (res != null && mounted) {
        _usernameController.text = (res['username'] ?? '').toString().trim();
        _emailController.text = (res['email'] ?? '').toString().trim();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Lỗi tải dữ liệu: $e');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Lưu thông tin profile
  Future<void> _saveProfile() async {
    final userId = _authService.getCurrentUser()?.id;
    if (userId == null) return;

    final username = _usernameController.text.trim();
    final email = _emailController.text.trim();

    if (username.isEmpty) {
      _showSnackBar('Vui lòng nhập tên hiển thị', Colors.orange);
      return;
    }
    if (email.isEmpty) {
      _showSnackBar('Vui lòng nhập email', Colors.orange);
      return;
    }

    setState(() => _saving = true);

    try {
      await _profileProvider.updateUsername(userId, username);
      await _profileProvider.updateEmail(userId, email);
      if (mounted) {
        _showSnackBar('Đã cập nhật thông tin', Colors.green);
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Lỗi: $e', Colors.red);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tài khoản'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text(_error!, textAlign: TextAlign.center))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Thông tin cá nhân',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _usernameController,
                    decoration: const InputDecoration(
                      labelText: 'Tên hiển thị',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: _saving ? null : _saveProfile,
                    icon: _saving
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save),
                    label: Text(_saving ? 'Đang lưu...' : 'Lưu thay đổi'),
                  ),
                  const SizedBox(height: 40),
                  const Divider(),
                  const SizedBox(height: 20),
                  const Text(
                    'Trợ giúp & Hỗ trợ',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  _buildHelpTile(
                    'Liên hệ hỗ trợ',
                    'Gửi feedback hoặc báo cáo lỗi',
                    Icons.help_outline,
                  ),
                  _buildHelpTile(
                    'Chính sách bảo mật',
                    'Tìm hiểu cách chúng tôi bảo vệ dữ liệu',
                    Icons.shield_outlined,
                  ),
                  _buildHelpTile(
                    'Điều khoản sử dụng',
                    'Đọc các điều khoản của ứng dụng',
                    Icons.description_outlined,
                  ),
                ],
              ),
            ),
    );
  }

  /// Build help tile
  Widget _buildHelpTile(String title, String subtitle, IconData icon) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: () {
        _showSnackBar('Chức năng sắp có', Colors.blue);
      },
    );
  }
}
