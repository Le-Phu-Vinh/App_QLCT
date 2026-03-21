import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Màn hình xem, sửa thông tin người dùng và trung tâm hỗ trợ.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _supabase = Supabase.instance.client;
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

  Future<void> _loadProfile() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      setState(() {
        _loading = false;
        _error = 'Chưa đăng nhập';
      });
      return;
    }

    try {
      final res = await _supabase
          .from('profiles')
          .select('username, email')
          .eq('id', userId)
          .maybeSingle();

      if (res != null) {
        _usernameController.text = (res['username'] ?? '').toString().trim();
        _emailController.text = (res['email'] ?? '').toString().trim();
      }
    } catch (e) {
      setState(() => _error = 'Lỗi tải dữ liệu: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveProfile() async {
    final userId = _supabase.auth.currentUser?.id;
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
      await _supabase.from('profiles').update({
        'username': username,
        'email': email,
      }).eq('id', userId);

      if (mounted) _showSnackBar('Đã cập nhật thông tin', Colors.green);
    } catch (e) {
      if (mounted) {
        _showSnackBar('Lỗi: $e', Colors.red);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color),
    );
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
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
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
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.save),
                        label: Text(_saving ? 'Đang lưu...' : 'Lưu thay đổi'),
                      ),
                      const SizedBox(height: 32),
                      const Divider(),
                      const SizedBox(height: 8),
                      const Text(
                        'Trung tâm hỗ trợ',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _SupportTile(
                        icon: Icons.help_outline,
                        title: 'Câu hỏi thường gặp',
                        onTap: () {
                          _showSnackBar(
                            'Chức năng đang phát triển',
                            Colors.blue,
                          );
                        },
                      ),
                      _SupportTile(
                        icon: Icons.email_outlined,
                        title: 'Liên hệ hỗ trợ',
                        subtitle: 'support@example.com',
                        onTap: () {
                          _showSnackBar(
                            'Liên hệ: support@example.com',
                            Colors.blue,
                          );
                        },
                      ),
                      _SupportTile(
                        icon: Icons.info_outline,
                        title: 'Phiên bản ứng dụng',
                        subtitle: '1.0.0',
                      ),
                    ],
                  ),
                ),
    );
  }
}

class _SupportTile extends StatelessWidget {
  const _SupportTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: subtitle != null ? Text(subtitle!) : null,
        trailing: onTap != null ? const Icon(Icons.chevron_right) : null,
        onTap: onTap,
      ),
    );
  }
}
